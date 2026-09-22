import os
import zipfile
import subprocess
import sys
import shutil
import asyncio
import logging
import time
import platform
import threading
import queue
from threading import Thread
from flask import Flask, jsonify
from telegram import ReplyKeyboardMarkup, KeyboardButton, Update, InlineKeyboardButton, InlineKeyboardMarkup, BotCommand
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters

# --- [ᴄᴏɴꜰɪɢᴜʀᴀᴛɪᴏɴ] ---
TOKEN = os.environ.get('BOT_TOKEN', '8627312006:AAHudxdlRmkfU81eRzIH69WLCFzoLn6FSoU')

ADMIN_IDS = [
    int(os.environ.get('ADMIN_ID_1', '5608455904')),
    int(os.environ.get('ADMIN_ID_2', '5608455904')),
]
ADMIN_IDS = [aid for aid in ADMIN_IDS if aid != 0]
PRIMARY_ADMIN_ID = ADMIN_IDS[0] if ADMIN_IDS else 5608455904
ADMIN_DISPLAY_NAME = "💞 @mfathey466 💞"

GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN', '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')
GITHUB_USER = "mfathey015-design"
REPO_NAME = "mom"

BASE_DIR = os.path.join(os.getcwd(), "hosted_projects")
TEMP_DIR = os.path.join(os.getcwd(), "temp_uploads")
PORT = int(os.environ.get('PORT', 8080))

logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

running_processes = {}
bot_locked = False
auto_restart_mode = False
user_upload_state = {}
project_owners = {}
recovery_enabled = True
live_logs_enabled = True
user_log_sessions = {}

try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False

class LogStreamer:
    def __init__(self):
        self.active_streams = {}

    def start_stream(self, project_name, process):
        if project_name in self.active_streams:
            return
        log_queue = queue.Queue()
        self.active_streams[project_name] = {
            "queue": log_queue,
            "subscribers": set(),
            "process": process,
            "last_lines": [],
            "running": True
        }
        threading.Thread(target=self._read_output, args=(project_name, process.stdout, "stdout"), daemon=True).start()
        threading.Thread(target=self._read_output, args=(project_name, process.stderr, "stderr"), daemon=True).start()

    def _read_output(self, project_name, pipe, pipe_type):
        stream_data = self.active_streams.get(project_name)
        if not stream_data:
            return
        try:
            for line in iter(pipe.readline, ''):
                if not stream_data["running"]:
                    break
                timestamp = time.strftime("%H:%M:%S")
                log_entry = f"[{timestamp}] [{pipe_type.upper()}] {line.rstrip()}"
                stream_data["queue"].put(log_entry)
                stream_data["last_lines"].append(log_entry)
                if len(stream_data["last_lines"]) > 50:
                    stream_data["last_lines"].pop(0)
                for user_id in list(stream_data["subscribers"]):
                    if user_id in user_log_sessions and user_log_sessions[user_id]["active"]:
                        user_log_sessions[user_id]["buffer"].append(log_entry)
        except Exception as e:
            logger.error(f"Log read error: {e}")
        finally:
            pipe.close()

    def subscribe(self, project_name, user_id, chat_id, message_id):
        if project_name not in self.active_streams:
            return False
        self.active_streams[project_name]["subscribers"].add(user_id)
        user_log_sessions[user_id] = {
            "project": project_name,
            "chat_id": chat_id,
            "message_id": message_id,
            "buffer": list(self.active_streams[project_name]["last_lines"]),
            "active": True,
            "last_update": time.time()
        }
        return True

    def unsubscribe(self, user_id):
        if user_id in user_log_sessions:
            p = user_log_sessions[user_id]["project"]
            if p in self.active_streams:
                self.active_streams[p]["subscribers"].discard(user_id)
            user_log_sessions[user_id]["active"] = False
            return True
        return False

    def stop_stream(self, project_name):
        if project_name in self.active_streams:
            self.active_streams[project_name]["running"] = False
            del self.active_streams[project_name]

log_streamer = LogStreamer()

def is_admin(user_id):
    return user_id in ADMIN_IDS

def init_main_repo():
    repo_path = os.getcwd()
    git_dir = os.path.join(repo_path, ".git")
    if not os.path.exists(git_dir):
        try:
            subprocess.run(["git", "init"], check=True, capture_output=True)
            subprocess.run(["git", "config", "user.name", "MF1E"], check=True, capture_output=True)
            subprocess.run(["git", "config", "user.email", "action@github.com"], check=True, capture_output=True)
            remote_url = f"https://{GITHUB_USER}:{GITHUB_TOKEN}@github.com/{GITHUB_USER}/{REPO_NAME}.git"
            subprocess.run(["git", "remote", "add", "origin", remote_url], check=True, capture_output=True)
            subprocess.run(["git", "checkout", "-b", "main"], check=True, capture_output=True)
            return True
        except Exception as e:
            logger.error(f"فشل تهيئة المستودع الرئيسي: {e}")
            return False
    return True

def push_to_github(project_path, p_name):
    if not init_main_repo():
        return False, "تعذرت تهيئة المستودع الرئيسي"
    original_dir = os.getcwd()
    try:
        rel_path = os.path.relpath(project_path, original_dir)
        subprocess.run(["git", "add", rel_path], check=True, capture_output=True)
        subprocess.run(["git", "commit", "-m", f"Update user project: {p_name}"], check=True, capture_output=True)
        subprocess.run(["git", "push", "-u", "origin", "main"], check=True, capture_output=True)
        return True, f"https://github.com/{GITHUB_USER}/{REPO_NAME}/tree/main/hosted_projects/{p_name}"
    except Exception as e:
        return False, str(e)
    finally:
        os.chdir(original_dir)

async def sync_projects_from_github():
    temp_clone = os.path.join(TEMP_DIR, "github_repo_clone")
    if os.path.exists(temp_clone):
        shutil.rmtree(temp_clone, ignore_errors=True)
    try:
        clone_url = f"https://{GITHUB_USER}:{GITHUB_TOKEN}@github.com/{GITHUB_USER}/{REPO_NAME}.git"
        subprocess.run(["git", "clone", clone_url, temp_clone], check=True, capture_output=True)
        projects_dir = os.path.join(temp_clone, "hosted_projects")
        if os.path.exists(projects_dir):
            for p_name in os.listdir(projects_dir):
                p_path = os.path.join(projects_dir, p_name)
                if os.path.isdir(p_path):
                    target_path = os.path.join(BASE_DIR, p_name)
                    if not os.path.exists(target_path):
                        shutil.copytree(p_path, target_path)
                    main_file = os.path.join(target_path, "main.py")
                    if os.path.exists(main_file) and p_name not in running_processes:
                        proc = subprocess.Popen([sys.executable, "-u", main_file], cwd=target_path, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
                        running_processes[p_name] = proc
                        log_streamer.start_stream(p_name, proc)
                        project_owners[p_name] = {"path": target_path, "u_id": PRIMARY_ADMIN_ID}
    except Exception as e:
        logger.error(f"Sync error: {e}")
    finally:
        if os.path.exists(temp_clone):
            shutil.rmtree(temp_clone, ignore_errors=True)

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"status": "online", "projects": len(project_owners), "running": len(running_processes)})

def run_web():
    app.run(host='0.0.0.0', port=PORT, debug=False, threaded=True)

def get_main_keyboard(user_id):
    layout = [
        [KeyboardButton("📦 رفع الملفات"), KeyboardButton("📁 إدارة الملفات")],
        [KeyboardButton("🗑️ حذف المشاريع"), KeyboardButton("🏩 صحة النظام")],
        [KeyboardButton("🌎 معلومات السيرفر"), KeyboardButton("📞 مراسلة المطور")],
        [KeyboardButton("📺 السجلات الحية")]
    ]
    if is_admin(user_id):
        layout.append([KeyboardButton("🔒 قفل النظام"), KeyboardButton("🔄 إعادة التشغيل التلقائي")])
    return ReplyKeyboardMarkup(layout, resize_keyboard=True)

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE if 'ContextTypes' in globals() else object):
    user_id = update.effective_user.id
    welcome_text = (
        "---\n"
        "/start\n"
        "مرحباً بك في بوت المطور محمد المصري النسخة المدفوعة 💎\n"
        "البوت يعمل بكامل مميزاته 🔥\n"
        "---"
    )
    await update.message.reply_text(welcome_text, reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')

async def handle_text(update: Update, context):
    user_id = update.effective_user.id
    text = update.message.text

    if user_id in user_upload_state and "path" in user_upload_state[user_id]:
        p_name = text.replace(" ", "_").replace("/", "_")
        state = user_upload_state[user_id]
        extract_path = os.path.join(BASE_DIR, p_name)
        try:
            msg = await update.message.reply_text("📦 جاري فك الضغط وتثبيت المشروع...")
            os.makedirs(extract_path, exist_ok=True)
            with zipfile.ZipFile(state["path"], 'r') as zip_ref:
                zip_ref.extractall(extract_path)
            
            main_py = os.path.join(extract_path, "main.py")
            if not os.path.exists(main_py):
                await msg.edit_text("❌ خطأ: ملف main.py غير موجود في ملف الـ ZIP!")
                shutil.rmtree(extract_path)
                return
            
            push_to_github(extract_path, p_name)
            project_owners[p_name] = {"u_id": user_id, "path": extract_path}
            del user_upload_state[user_id]
            await msg.edit_text(f"✅ تم حفظ وحفظ المشروع `{p_name}` بنجاح!", parse_mode='Markdown')
        except Exception as e:
            await update.message.reply_text(f"❌ حدث خطأ: {e}")
        return

    if text == "📦 رفع الملفات":
        await update.message.reply_text("📦 أرسل ملف ZIP يحتوي على `main.py` و `requirements.txt`", parse_mode='Markdown')
    elif text == "📁 إدارة الملفات":
        user_projects = [p for p, d in project_owners.items() if d["u_id"] == user_id or is_admin(user_id)]
        if not user_projects:
            await update.message.reply_text("📁 لا توجد مشاريع مرفوعة بعد.")
            return
        keyboard = [[InlineKeyboardButton(f"📁 {p}", callback_data=f"manage_{p}")] for p in user_projects]
        await update.message.reply_text("📁 **مشاريعك الحالية:**", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif text == "📞 مراسلة المطور":
        await update.message.reply_text(f"👨‍💻 للتواصل مع المطور: {ADMIN_DISPLAY_NAME}")
    else:
        await update.message.reply_text("⚠️ استخدم الأزرار المتاحة في القائمة.", parse_mode='Markdown')

async def handle_docs(update: Update, context):
    user_id = update.effective_user.id
    doc = update.message.document
    if not doc.file_name.endswith('.zip'):
        await update.message.reply_text("❌ يرجى إرسال ملف بصيغة .zip فقط.")
        return
    msg = await update.message.reply_text("📥 جاري تحميل الملف...")
    temp_zip = os.path.join(TEMP_DIR, f"{user_id}_{int(time.time())}_{doc.file_name}")
    file = await doc.get_file()
    await file.download_to_drive(temp_zip)
    user_upload_state[user_id] = {"path": temp_zip}
    await msg.edit_text("🖋️ أرسل الآن اسماً لهذا المشروع:")

async def button_callback(update: Update, context):
    query = update.callback_query
    await query.answer()
    data = query.data.split('_')
    action, p_name = data[0], "_".join(data[1:])

    if action == "manage":
        folder = project_owners.get(p_name, {}).get("path")
        if not folder:
            await query.edit_message_text("❌ المشروع غير موجود.")
            return
        keyboard = [
            [InlineKeyboardButton("▶️ تشغيل", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 إيقاف", callback_data=f"stop_{p_name}")],
            [InlineKeyboardButton("🗑️ حذف", callback_data=f"del_{p_name}")]
        ]
        await query.edit_message_text(f"📦 إدارة المشروع: `{p_name}`", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif action == "run":
        folder = project_owners.get(p_name, {}).get("path")
        main_file = os.path.join(folder, "main.py")
        proc = subprocess.Popen([sys.executable, "-u", main_file], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
        running_processes[p_name] = proc
        log_streamer.start_stream(p_name, proc)
        await query.edit_message_text(f"🚀 تم تشغيل المشروع `{p_name}` بنجاح! 💚", parse_mode='Markdown')
    elif action == "stop":
        if p_name in running_processes:
            log_streamer.stop_stream(p_name)
            running_processes[p_name].terminate()
            del running_processes[p_name]
        await query.edit_message_text(f"🛑 تم إيقاف المشروع `{p_name}`! 💔", parse_mode='Markdown')
    elif action == "del":
        if p_name in running_processes:
            running_processes[p_name].terminate()
            del running_processes[p_name]
        shutil.rmtree(os.path.join(BASE_DIR, p_name), ignore_errors=True)
        if p_name in project_owners:
            del project_owners[p_name]
        await query.edit_message_text(f"🗑️ تم حذف المشروع `{p_name}` بنجاح.", parse_mode='Markdown')

def main():
    web_thread = Thread(target=run_web, daemon=True)
    web_thread.start()

    application = Application.builder().token(TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.Document.ZIP, handle_docs))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    application.add_handler(CallbackQueryHandler(button_callback))

    async def post_init(app):
        await app.bot.set_my_commands([BotCommand("start", "🚀 تشغيل البوت والقائمة الرئيسية")])
        await sync_projects_from_github()

    application.post_init = post_init
    
    logger.info("Bot started successfully with full features.")
    application.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
