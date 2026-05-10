import os
import zipfile
import subprocess
import sys
import shutil
import asyncio
import logging
import time
import signal
import platform
import threading
import queue
import requests
from threading import Thread
from flask import Flask, jsonify
from telegram import ReplyKeyboardMarkup, KeyboardButton, Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes

# --- [ᴄᴏɴꜰɪɢᴜʀᴀᴛɪᴏɴ] ---
TOKEN = '8627312006:AAHkICMEwUCW8YobgMBB_E2abu9RBtxcVMI'

ADMIN_IDS = [5608455904
    int(os.environ.get('ADMIN_ID_1', '5608455904')),
    int(os.environ.get('ADMIN_ID_2', '5608455904')),
    int(os.environ.get('ADMIN_ID_3', '0')),
    int(os.environ.get('ADMIN_ID_4', '0')),
    int(os.environ.get('ADMIN_ID_5', '0')),
    int(os.environ.get('OWNER_ID', '0')),
]
ADMIN_IDS = [aid for aid in ADMIN_IDS if aid != 0]

PRIMARY_ADMIN_ID = ADMIN_IDS[0] if ADMIN_IDS else 5608455904
ADMIN_USERNAME = "@mfathey466"
ADMIN_DISPLAY_NAME = "💞 @mfathey466 💞"

# GitHub Configuration (تم التحديث)
GITHUB_TOKEN = "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"
GITHUB_USER = "mfathey015-design"
REPO_NAME = "mom"   # يمكن استخدامه لاحقاً كاسم افتراضي

BASE_DIR = os.path.join(os.getcwd(), "hosted_projects")
TEMP_DIR = os.path.join(os.getcwd(), "temp_uploads")
PORT = int(os.environ.get('PORT', 8080))

# logging setup
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

# --- [ɢʟᴏʙᴀʟ ᴅᴀᴛᴀ] ---
running_processes = {}
bot_locked = False
auto_restart_mode = False
user_upload_state = {}
project_owners = {}
recovery_enabled = True
live_logs_enabled = True
user_log_sessions = {}
monitor_tasks = set()

# --- [PSUTIL CHECK] ---
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    logger.warning("psutil not available, using basic info")

# --- [ᴀᴜᴛᴏ ᴘᴀᴄᴋᴀɢᴇ ɪɴꜱᴛᴀʟʟᴇʀ] ---
def auto_install_packages():
    required_packages = ['flask', 'python-telegram-bot', 'psutil', 'aiohttp', 'requests']
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
        except ImportError:
            logger.info(f"Installing {package}...")
            subprocess.check_call([sys.executable, "-m", "pip", "install", package, "--quiet"])

auto_install_packages()

# --- [ʟᴏɢ ꜱᴛʀᴇᴀᴍᴇʀ ᴄʟᴀꜱꜱ] ---
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

    def get_recent_logs(self, project_name, lines=20):
        if project_name in self.active_streams:
            return self.active_streams[project_name]["last_lines"][-lines:]
        return []

    def is_streaming(self, project_name):
        return project_name in self.active_streams and self.active_streams[project_name]["running"]

log_streamer = LogStreamer()

# --- [ʜᴇʟᴘᴇʀ ꜰᴜɴᴄᴛɪᴏɴꜱ] ---
def is_admin(user_id):
    return user_id in ADMIN_IDS

async def clean_old_temp_files(max_age_seconds=3600):
    now = time.time()
    for f in os.listdir(TEMP_DIR):
        path = os.path.join(TEMP_DIR, f)
        if os.path.isfile(path) and (now - os.path.getmtime(path)) > max_age_seconds:
            os.unlink(path)
        elif os.path.isdir(path) and (now - os.path.getmtime(path)) > max_age_seconds:
            shutil.rmtree(path, ignore_errors=True)

# --- [ɢɪᴛʜᴜʙ ʜᴇʟᴘᴇʀꜱ] ---
def create_github_repo(repo_name):
    url = "https://api.github.com/user/repos"
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json"
    }
    data = {
        "name": repo_name,
        "private": False,
        "description": f"Auto-uploaded from Lam Hosting Bot - {repo_name}",
        "auto_init": False
    }
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 201:
        return True, response.json()["html_url"]
    elif response.status_code == 422:
        return False, "already_exists"
    else:
        return False, f"GitHub API error: {response.text}"

def push_to_github(project_path, repo_name):
    if not shutil.which("git"):
        return False, "Git is not installed on the server."
    original_dir = os.getcwd()
    os.chdir(project_path)
    try:
        subprocess.run(["git", "init"], check=True, capture_output=True, text=True)
        remote_url = f"https://{GITHUB_USER}:{GITHUB_TOKEN}@github.com/{GITHUB_USER}/{repo_name}.git"
        subprocess.run(["git", "remote", "add", "origin", remote_url], check=True, capture_output=True, text=True)
        subprocess.run(["git", "add", "."], check=True, capture_output=True, text=True)
        subprocess.run(["git", "commit", "-m", "Initial commit from Lam Hosting Bot"], check=True, capture_output=True, text=True)
        subprocess.run(["git", "push", "-u", "origin", "master", "--force"], check=True, capture_output=True, text=True)
        return True, f"https://github.com/{GITHUB_USER}/{repo_name}"
    except subprocess.CalledProcessError as e:
        return False, f"Git error: {e.stderr}"
    except Exception as e:
        return False, str(e)
    finally:
        os.chdir(original_dir)
        git_dir = os.path.join(project_path, ".git")
        if os.path.exists(git_dir):
            shutil.rmtree(git_dir, ignore_errors=True)

# --- [ʟᴏᴀᴅɪɴɢ ᴀɴɪᴍᴀᴛɪᴏɴꜱ] ---
class Loading:
    @staticmethod
    def executing():
        return ["🌺 ᴇxᴇᴄᴜᴛɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","🌼 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▱▱▱▱▱▱▱▱▱] 10%","🌻 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▱▱▱▱▱▱▱▱] 20%","🌸 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▱▱▱▱▱▱▱] 30%","🌹 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▱▱▱▱▱▱] 40%","🍁 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▰▱▱▱▱▱] 50%","🌿 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 60%","🌳 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▰▰▰▱▱▱] 70%","🌲 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▰▰▰▰▱▱] 80%","🪷 ᴇxᴇᴄᴜᴛɪɴɗ: [▰▰▰▰▰▰▰▰▰▱] 90%","✅ ᴄᴏᴍᴘʟᴇᴛᴇ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def uploading():
        return ["🗳️ ᴜᴘʟᴏᴀᴅɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","🗳️ ᴜᴘʟᴏᴀᴅɪɴɗ: [▰▱▱▱▱▱▱▱▱▱] 25%","🗳️ ᴜᴘʟᴏᴀᴅɪɴɗ: [▰▰▰▱▱▱▱▱▱▱] 50%","🗳️ ᴜᴘʟᴏᴀᴅɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 75%","✅ ᴜᴘʟᴏᴀᴅ ᴄᴏᴍᴘʟᴇᴛᴇ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def installing():
        return ["📦 ɪɴꜱᴛᴀʟʟɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","📦 ɪɴꜱᴛᴀʟʟɪɴɗ: [▰▰▱▱▱▱▱▱▱▱] 20%","📦 ɪɴꜱᴛᴀʟʟɪɴɗ: [▰▰▰▰▱▱▱▱▱▱] 40%","📦 ɪɴꜱᴛᴀʟʟɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 60%","📦 ɪɴꜱᴛᴀʟʟɪɴɗ: [▰▰▰▰▰▰▰▰▱▱] 80%","✅ ɪɴꜱᴛᴀʟʟᴇᴅ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def deleting():
        return ["🗑️ ᴅᴇʟᴇᴛɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","🗑️ ᴅᴇʟᴇᴛɪɴɗ: [▰▰▰▱▱▱▱▱▱▱] 30%","🗑️ ᴅᴇʟᴇᴛɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 60%","✅ ᴅᴇʟᴇᴛᴇᴅ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def restarting():
        return ["🇮🇳 ʀᴇꜱᴛᴀʀᴛɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","🇮🇳 ʀᴇꜱᴛᴀʀᴛɪɴɗ: [▰▰▱▱▱▱▱▱▱▱] 20%","🇮🇳 ʀᴇꜱᴛᴀʀᴛɪɴɗ: [▰▰▰▰▱▱▱▱▱▱] 40%","🇮🇳 ʀᴇꜱᴛᴀʀᴛɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 60%","🇮🇳 ʀᴇꜱᴛᴀʀᴛɪɴɗ: [▰▰▰▰▰▰▰▰▱▱] 80%","✅ ʀᴇꜱᴛᴀʀᴛᴇᴅ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def recovering():
        return ["🔄 ʀᴇᴄᴏᴠᴇʀɪɴɗ: [▱▱▱▱▱▱▱▱▱▱] 0%","🔄 ʀᴇᴄᴏᴠᴇʀɪɴɗ: [▰▰▰▱▱▱▱▱▱▱] 30%","🔄 ʀᴇᴄᴏᴠᴇʀɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 60%","✅ ʀᴇᴄᴏᴠᴇʀᴇᴅ: [▰▰▰▰▰▰▰▰▰▰] 100%"]
    @staticmethod
    def logs_on():
        return ["📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▱▱▱▱▱▱▱▱▱▱] ᴏꜰꜰ","📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▱▱▱▱▱▱▱] ꜱᴛᴀʀᴛɪɴɗ...","📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▰▰▰▱▱▱▱] ᴄᴏɴɴᴇᴄᴛɪɴɗ...","✅ ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▰▰▰▰▰▰▰] ᴏɴʟɪɴᴇ"]
    @staticmethod
    def logs_off():
        return ["📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▰▰▰▰▰▰▰] ᴏɴʟɪɴᴇ","📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▰▰▰▱▱▱▱] ᴅɪꜱᴄᴏɴɴᴇᴄᴛɪɴɗ...","📺 ʟɪᴠᴇ ʟᴏɢꜱ: [▰▰▰▱▱▱▱▱▱▱] ᴄʟᴏꜱɪɴɗ...","❌ ʟɪᴠᴇ ʟᴏɢꜱ: [▱▱▱▱▱▱▱▱▱▱] ᴏꜰꜰ"]

async def animate(chat_id, message_id, context, frames, delay=0.5, final_text=None):
    msg = None
    for i, frame in enumerate(frames):
        await asyncio.sleep(delay)
        try:
            if i == 0:
                if message_id:
                    msg = await context.bot.edit_message_text(chat_id=chat_id, message_id=message_id, text=frame)
            else:
                await context.bot.edit_message_text(chat_id=chat_id, message_id=msg.message_id, text=frame)
        except Exception as e:
            break
    if final_text and msg:
        await asyncio.sleep(0.3)
        try:
            await context.bot.edit_message_text(chat_id=chat_id, message_id=msg.message_id, text=final_text, parse_mode='Markdown')
        except:
            pass
    return msg

# --- [ꜰʟᴀꜱᴋ ᴡᴇʙ ꜱᴇʀᴠᴇʀ] ---
app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({"status": "online","service": "ᴀᴘᴏɴ ᴘʀᴇᴍɪᴜᴍ ʜᴏꜱᴛɪɴɗ ᴠ1","projects": len(project_owners),"running": len([p for p in running_processes.values() if p.poll() is None]),"recovery": recovery_enabled,"live_logs": live_logs_enabled})

@app.route('/health')
def health():
    return jsonify({"status": "healthy"}), 200

def run_web():
    app.run(host='0.0.0.0', port=PORT, debug=False)

# --- [ᴋᴇʏʙᴏᴀʀᴅ ꜱᴇᴛᴜᴘ - زرين فقط لجميع المستخدمين] ---
def get_main_keyboard(user_id):
    layout = [
        [KeyboardButton("📦 رفع الملفات")],
        [KeyboardButton("📞 مراسلة المطور")]
    ]
    return ReplyKeyboardMarkup(layout, resize_keyboard=True)

# --- [ʟɪᴠᴇ ʟᴏɢꜱ ᴠɪᴇᴡᴇʀ ᴛᴀꜱᴋ] ---
async def log_viewer_task(context: ContextTypes.DEFAULT_TYPE):
    while True:
        try:
            if not live_logs_enabled:
                await asyncio.sleep(2)
                continue
            current_time = time.time()
            for user_id, session in list(user_log_sessions.items()):
                if not session["active"]:
                    continue
                if current_time - session["last_update"] < 2:
                    continue
                logs = session["buffer"][-20:]
                session["buffer"] = []
                if not logs and not session.get("has_content"):
                    continue
                log_text = "\n".join(logs) if logs else "⏳ Waiting for logs..."
                terminal_text = f"📺 **ʟɪᴠᴇ ᴄᴏɴꜱᴏʟᴇ - {session['project']}**\n━━━━━━━━━━━━━━━━━━━━━\n```\n{log_text[-3500:]}\n```\n━━━━━━━━━━━━━━━━━━━━━\n🟢 ᴏɴʟɪɴᴇ | 🔄 ᴀᴜᴛᴏ-ᴜᴘᴅᴀᴛᴇ: 2ꜱ"
                try:
                    await context.bot.edit_message_text(chat_id=session["chat_id"], message_id=session["message_id"], text=terminal_text, parse_mode='Markdown')
                    session["last_update"] = current_time
                    session["has_content"] = True
                except Exception as e:
                    if "message is not modified" not in str(e).lower():
                        if "message to edit not found" in str(e).lower():
                            session["active"] = False
            await asyncio.sleep(0.5)
        except Exception as e:
            logger.error(f"Log viewer error: {e}")
            await asyncio.sleep(2)

# --- [ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ ꜰᴜɴᴄᴛɪᴏɴ] ---
async def get_system_health():
    try:
        if PSUTIL_AVAILABLE:
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            ram = psutil.virtual_memory()
            ram_used_gb = ram.used / (1024**3)
            ram_total_gb = ram.total / (1024**3)
            ram_percent = ram.percent
            disk = psutil.disk_usage('/')
            disk_used_gb = disk.used / (1024**3)
            disk_total_gb = disk.total / (1024**3)
            disk_percent = disk.percent
            uptime = time.time() - psutil.boot_time()
            return {"status": "ok","cpu": f"{cpu_percent}%","cpu_cores": cpu_count,"ram": f"{ram_percent}%","ram_used": f"{ram_used_gb:.1f}GB","ram_total": f"{ram_total_gb:.1f}GB","disk": f"{disk_percent}%","disk_used": f"{disk_used_gb:.1f}GB","disk_total": f"{disk_total_gb:.1f}GB","uptime": f"{int(uptime//3600)}h {int((uptime%3600)//60)}m"}
        else:
            return {"status": "basic","platform": platform.system(),"machine": platform.machine(),"processor": platform.processor() or "Unknown","python_version": platform.python_version()}
    except Exception as e:
        return {"status": "error", "error": str(e)}

# --- [ᴄᴏʀᴇ ᴄᴏᴍᴍᴀɴᴅꜱ] ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if bot_locked and not is_admin(user_id):
        await update.message.reply_text("🔒 **البوت مقفل حالياً من قبل المطور**", parse_mode='Markdown')
        return
    welcome_msg = (
        "💰 **مرحبا بكم في بوت استضافة المطور محمد المصري المدفوع** 💎\n"
        "━━━━━━━━━━━━━━━━━━━━━\n"
        "🔥 **أقوى بوت استضافة في الهند** 🇮🇳\n"
        "🚀 **خدمة متميزة - دعم فوري - سيرفرات فائقة السرعة**\n"
        "━━━━━━━━━━━━━━━━━━━━━\n"
        "📦 **الزر الأول:** رفع ملفات المشروع (ZIP)\n"
        "📞 **الزر الثاني:** التواصل مع المطور\n"
        "━━━━━━━━━━━━━━━━━━━━━\n"
        f"👨‍💻 **المطور:** {ADMIN_USERNAME}\n"
        "💎 **بوت مدفوع بالكامل - استمتع بالخدمة**"
    )
    await update.message.reply_text(welcome_msg, reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text
    global bot_locked, auto_restart_mode, recovery_enabled, live_logs_enabled

    if bot_locked and not is_admin(user_id):
        await update.message.reply_text("🔒 **البوت مقفل حالياً**", parse_mode='Markdown')
        return

    # حالة انتظار اسم المشروع بعد رفع الملف
    if user_id in user_upload_state and "path" in user_upload_state[user_id]:
        p_name = text.replace(" ", "_").replace("/", "_")
        state = user_upload_state[user_id]
        extract_path = os.path.join(BASE_DIR, p_name)
        try:
            msg = await update.message.reply_text(Loading.executing()[0])
            for frame in Loading.executing()[1:]:
                await asyncio.sleep(0.4)
                await msg.edit_text(frame)

            os.makedirs(extract_path, exist_ok=True)
            with zipfile.ZipFile(state["path"], 'r') as zip_ref:
                zip_ref.extractall(extract_path)
            main_py = os.path.join(extract_path, "main.py")
            req_txt = os.path.join(extract_path, "requirements.txt")
            if not os.path.exists(main_py):
                await msg.edit_text("❌ **خطأ: main.py غير موجود في الملف المضغوط!**", parse_mode='Markdown')
                shutil.rmtree(extract_path)
                return
            if os.path.exists(req_txt):
                for frame in Loading.installing():
                    await msg.edit_text(frame)
                    await asyncio.sleep(1.0)
                try:
                    subprocess.run([sys.executable, "-m", "pip", "install", "-r", req_txt], check=True, capture_output=True, text=True, cwd=extract_path)
                except subprocess.CalledProcessError:
                    await msg.edit_text("⚠️ **تحذير: فشل تثبيت بعض المتطلبات**", parse_mode='Markdown')
                    await asyncio.sleep(1)
            
            # GitHub upload
            await msg.edit_text("📤 **جاري رفع المشروع إلى GitHub...**", parse_mode='Markdown')
            success, result = create_github_repo(p_name)
            if not success and result != "already_exists":
                await msg.edit_text(f"⚠️ **فشل إنشاء المستودع:** `{result}`\nسيتم الاستضافة محلياً فقط.", parse_mode='Markdown')
            push_ok, push_msg = push_to_github(extract_path, p_name)
            if push_ok:
                github_link = push_msg
                await msg.edit_text(f"✅ **تم رفع المشروع إلى GitHub بنجاح**\n🔗 {github_link}", parse_mode='Markdown')
            else:
                await msg.edit_text(f"❌ **فشل رفع GitHub:** `{push_msg}`\nتم الاستضافة محلياً فقط.", parse_mode='Markdown')
                github_link = None
            
            project_owners[p_name] = {"u_id": user_id,"u_name": state["u_name"],"u_username": update.effective_user.username or "ɴᴏ_ᴜꜱᴇʀɴᴀᴍᴇ","zip": state["path"],"original_name": state["original_name"],"path": extract_path, "github_url": github_link if push_ok else None}
            del user_upload_state[user_id]
            final_text = f"✅ **تم حفظ المشروع `{p_name}` بنجاح!**\n━━━━━━━━━━━━━━━━━━━━━\n🚀 **يمكنك الآن إدارته عبر الأمر /myprojects**\n"
            if github_link:
                final_text += f"🌐 **GitHub:** {github_link}"
            await msg.edit_text(final_text, parse_mode='Markdown')
        except Exception as e:
            logger.error(f"Upload error: {e}")
            await update.message.reply_text(f"❌ **خطأ:** `{str(e)}`", parse_mode='Markdown')
        return

    # زر رفع الملفات
    if text == "📦 رفع الملفات":
        await update.message.reply_text(
            "📦 **أرسل ملف ZIP يحتوي على:**\n"
            "• `main.py` (كود البوت الخاص بك)\n"
            "• `requirements.txt` (المكتبات المطلوبة)\n"
            "━━━━━━━━━━━━━━━━━━━━━\n"
            "✅ **الملف يجب أن يكون بصيغة .zip فقط**",
            parse_mode='Markdown'
        )
    # زر مراسلة المطور
    elif text == "📞 مراسلة المطور":
        keyboard = InlineKeyboardMarkup([[InlineKeyboardButton("📞 تواصل مع المطور", url=f"tg://user?id={PRIMARY_ADMIN_ID}")]])
        await update.message.reply_text(
            f"👨‍💻 **لمراسلة المطور محمد المصري:**\n{ADMIN_DISPLAY_NAME}\n\n🔘 اضغط الزر أدناه للتواصل المباشر.",
            reply_markup=keyboard,
            parse_mode='Markdown'
        )
    else:
        await update.message.reply_text("⚠️ **استخدم الأزرار المتاحة فقط.**", parse_mode='Markdown')

async def handle_docs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if bot_locked and not is_admin(user_id):
        await update.message.reply_text("🔒 **البوت مقفل حالياً**", parse_mode='Markdown')
        return
    doc = update.message.document
    if not doc.file_name.endswith('.zip'):
        await update.message.reply_text("❌ **يرجى إرسال ملف بصيغة .zip فقط!**", parse_mode='Markdown')
        return
    msg = await update.message.reply_text(Loading.uploading()[0])
    for frame in Loading.uploading()[1:]:
        await asyncio.sleep(0.8)
        await msg.edit_text(frame)
    temp_zip = os.path.join(TEMP_DIR, f"{user_id}_{int(time.time())}_{doc.file_name}")
    try:
        file = await doc.get_file()
        await file.download_to_drive(temp_zip)
        user_upload_state[user_id] = {"path": temp_zip,"u_name": update.effective_user.full_name,"original_name": doc.file_name}
        await msg.edit_text("🖋️ **أرسل اسماً لمشروعك (يمكنك استخدام مسافات):**", parse_mode='Markdown')
    except Exception as e:
        logger.error(f"Download error: {e}")
        await msg.edit_text("❌ **فشل تحميل الملف!**", parse_mode='Markdown')
        if os.path.exists(temp_zip):
            os.unlink(temp_zip)

async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data.split('_')
    action, p_name = data[0], "_".join(data[1:])
    user_id = update.effective_user.id

    if action == "run":
        if p_name in running_processes and running_processes[p_name].poll() is None:
            await query.edit_message_text(f"⚠️ **`{p_name}` يعمل بالفعل!**", parse_mode='Markdown')
            return
        folder = project_owners.get(p_name, {}).get("path")
        if not folder:
            await query.edit_message_text(f"❌ **المشروع `{p_name}` غير موجود**", parse_mode='Markdown')
            return
        main_file = os.path.join(folder, "main.py")
        if os.path.exists(main_file):
            msg = await query.edit_message_text(Loading.executing()[0])
            for frame in Loading.executing()[1:]:
                await asyncio.sleep(0.4)
                await msg.edit_text(frame)
            try:
                proc = subprocess.Popen([sys.executable, "-u", main_file], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
                running_processes[p_name] = proc
                if live_logs_enabled:
                    log_streamer.start_stream(p_name, proc)
                if auto_restart_mode and p_name not in monitor_tasks:
                    task = asyncio.create_task(monitor_process(p_name, folder))
                    monitor_tasks.add(task)
                    task.add_done_callback(lambda t: monitor_tasks.discard(t))
                keyboard = [[InlineKeyboardButton("▶️ تشغيل", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 إيقاف", callback_data=f"stop_{p_name}")],[InlineKeyboardButton("📺 سجلات حية", callback_data=f"viewlogs_{p_name}")],[InlineKeyboardButton("🗑️ حذف", callback_data=f"del_{p_name}")]]
                await msg.edit_text(f"🚀 **`{p_name}` أصبح متصلاً الآن! 💚**\n\n📺 اضغط على **سجلات حية** لمشاهدة المخرجات.", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
            except Exception as e:
                await msg.edit_text(f"❌ **فشل التشغيل:** `{str(e)}`", parse_mode='Markdown')
        else:
            await query.edit_message_text(f"❌ **main.py غير موجود!**", parse_mode='Markdown')
    elif action == "stop":
        if p_name in running_processes:
            msg = await query.edit_message_text("🛑 جاري الإيقاف...")
            log_streamer.stop_stream(p_name)
            try:
                running_processes[p_name].terminate()
                running_processes[p_name].wait(timeout=5)
            except:
                running_processes[p_name].kill()
            del running_processes[p_name]
            for uid, session in list(user_log_sessions.items()):
                if session["project"] == p_name:
                    session["active"] = False
            await msg.edit_text(f"🛑 **`{p_name}` غير متصل الآن! 💔**", parse_mode='Markdown')
        else:
            await query.edit_message_text(f"⚠️ **`{p_name}` لم يكن يعمل**", parse_mode='Markdown')
    elif action == "viewlogs":
        if not live_logs_enabled:
            await query.answer("❌ السجلات الحية معطلة حالياً!", show_alert=True)
            return
        if p_name not in running_processes or running_processes[p_name].poll() is not None:
            await query.answer("❌ هذا المشروع لا يعمل حالياً!", show_alert=True)
            return
        log_msg = await context.bot.send_message(chat_id=update.effective_chat.id, text="📺 **جاري تهيئة وحدة السجلات...**", parse_mode='Markdown')
        if log_streamer.subscribe(p_name, user_id, update.effective_chat.id, log_msg.message_id):
            await query.answer("✅ تم تشغيل السجلات الحية!", show_alert=True)
        else:
            await log_msg.edit_text("❌ **فشل بدء السجلات!**", parse_mode='Markdown')
    elif action == "del":
        msg = await query.edit_message_text(Loading.deleting()[0])
        for frame in Loading.deleting()[1:]:
            await asyncio.sleep(0.5)
            await msg.edit_text(frame)
        if p_name in running_processes:
            log_streamer.stop_stream(p_name)
            try:
                running_processes[p_name].terminate()
                running_processes[p_name].wait(timeout=5)
            except:
                running_processes[p_name].kill()
            del running_processes[p_name]
        for uid, session in list(user_log_sessions.items()):
            if session["project"] == p_name:
                session["active"] = False
        path = os.path.join(BASE_DIR, p_name)
        if os.path.exists(path):
            shutil.rmtree(path)
        if p_name in project_owners:
            del project_owners[p_name]
        await msg.edit_text(f"🗑️ **تم حذف `{p_name}`!**", parse_mode='Markdown')
    elif action == "manage":
        status = "💚 متصل" if (p_name in running_processes and running_processes[p_name].poll() is None) else "💔 غير متصل"
        keyboard = [[InlineKeyboardButton("▶️ تشغيل", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 إيقاف", callback_data=f"stop_{p_name}")],[InlineKeyboardButton("📺 سجلات حية", callback_data=f"viewlogs_{p_name}")],[InlineKeyboardButton("🗑️ حذف", callback_data=f"del_{p_name}")]]
        await query.edit_message_text(f"📦 **المشروع:** `{p_name}`\n📡 **الحالة:** {status}\n📺 **السجلات الحية:** {'متاحة' if live_logs_enabled else 'معطلة'}", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def monitor_process(p_name, folder):
    while auto_restart_mode and p_name in running_processes:
        proc = running_processes.get(p_name)
        if proc and proc.poll() is not None:
            await asyncio.sleep(2)
            main_file = os.path.join(folder, "main.py")
            if os.path.exists(main_file):
                new_proc = subprocess.Popen([sys.executable, "-u", main_file], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
                running_processes[p_name] = new_proc
                if live_logs_enabled:
                    log_streamer.stop_stream(p_name)
                    log_streamer.start_stream(p_name, new_proc)
                logger.info(f"Auto-restarted {p_name}")
        await asyncio.sleep(5)

# --- [ᴀᴜᴛᴏ ʀᴇᴄᴏᴠᴇʀʏ ꜱʏꜱᴛᴇᴍ] ---
class BotRecovery:
    def __init__(self):
        self.running = True

    async def start_recovery_monitor(self, application):
        while self.running and recovery_enabled:
            try:
                await self.recover_projects()
                await asyncio.sleep(10)
            except Exception as e:
                logger.error(f"Recovery error: {e}")
                await asyncio.sleep(5)

    async def recover_projects(self):
        for p_name, proc in list(running_processes.items()):
            if proc.poll() is not None and recovery_enabled and p_name in project_owners:
                logger.info(f"Recovering crashed project: {p_name}")
                folder = project_owners[p_name]["path"]
                main_file = os.path.join(folder, "main.py")
                if os.path.exists(main_file):
                    try:
                        log_streamer.stop_stream(p_name)
                        new_proc = subprocess.Popen([sys.executable, "-u", main_file], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
                        running_processes[p_name] = new_proc
                        if live_logs_enabled:
                            log_streamer.start_stream(p_name, new_proc)
                        logger.info(f"Project {p_name} recovered")
                    except Exception as e:
                        logger.error(f"Failed to recover {p_name}: {e}")

    def stop(self):
        self.running = False

recovery_system = BotRecovery()

def signal_handler(signum, frame):
    logger.info("Shutdown signal received, stopping recovery...")
    recovery_system.stop()
    for p_name in list(log_streamer.active_streams.keys()):
        log_streamer.stop_stream(p_name)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# --- [أوامر الأدمن الإضافية] ---
async def health_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    health_data = await get_system_health()
    if health_data["status"] == "ok":
        text = (f"🏩 **صحة النظام**\n━━━━━━━━━━━━━━━━━━━━━\n🖥️ **CPU:** {health_data['cpu']} ({health_data['cpu_cores']} نوى)\n🧠 **RAM:** {health_data['ram']} ({health_data['ram_used']}/{health_data['ram_total']})\n💾 **القرص:** {health_data['disk']} ({health_data['disk_used']}/{health_data['disk_total']})\n⏱️ **مدة التشغيل:** {health_data['uptime']}\n📦 **المشاريع:** {len(project_owners)}\n💚 **قيد التشغيل:** {len([p for p in running_processes.values() if p.poll() is None])}\n🛡️ **الاسترداد:** {'مفعل' if recovery_enabled else 'معطل'}\n📺 **السجلات الحية:** {'مفعلة' if live_logs_enabled else 'معطلة'}")
    else:
        text = f"⚠️ تعذر جلب البيانات: {health_data.get('error', 'خطأ')}"
    await update.message.reply_text(text, parse_mode='Markdown')

async def server_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    text = (f"🌎 **معلومات السيرفر**\n🚀 **المنفذ:** {PORT}\n🛡️ **المنصة:** {os.environ.get('PLATFORM', 'غير معروف')}\n🔄 **إعادة التشغيل التلقائي:** {'مفعل' if auto_restart_mode else 'معطل'}\n🛡️ **الاسترداد التلقائي:** {'مفعل' if recovery_enabled else 'معطل'}\n📺 **السجلات الحية:** {'مفعلة' if live_logs_enabled else 'معطلة'}")
    await update.message.reply_text(text, parse_mode='Markdown')

async def projects_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not is_admin(user_id):
        user_projects = [p for p, d in project_owners.items() if d["u_id"] == user_id]
        if not user_projects:
            await update.message.reply_text("📮 **ليس لديك أي مشاريع بعد.**", parse_mode='Markdown')
            return
        keyboard = []
        for p in user_projects:
            status = "💚 متصل" if (p in running_processes and running_processes[p].poll() is None) else "💔 غير متصل"
            keyboard.append([InlineKeyboardButton(f"{status} | {p}", callback_data=f"manage_{p}")])
        await update.message.reply_text("📦 **مشاريعي**", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    else:
        if not project_owners:
            await update.message.reply_text("📮 **لا توجد مشاريع بعد.**", parse_mode='Markdown')
            return
        for p_name, data in project_owners.items():
            status = "💚 متصل" if (p_name in running_processes and running_processes[p_name].poll() is None) else "💔 غير متصل"
            keyboard = [[InlineKeyboardButton("▶️ تشغيل", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 إيقاف", callback_data=f"stop_{p_name}")],[InlineKeyboardButton("📺 سجلات حية", callback_data=f"viewlogs_{p_name}")],[InlineKeyboardButton("🗑️ حذف", callback_data=f"del_{p_name}")]]
            await update.message.reply_text(f"📦 **{p_name}**\n👤 المستخدم: {data['u_name']}\n📡 الحالة: {status}", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def lock_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    global bot_locked
    bot_locked = True
    await update.message.reply_text("🔒 **تم قفل البوت.**", parse_mode='Markdown')

async def unlock_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    global bot_locked
    bot_locked = False
    await update.message.reply_text("🔓 **تم فتح البوت.**", parse_mode='Markdown')

async def autorestart_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    global auto_restart_mode
    args = context.args
    if not args or args[0].lower() not in ['on','off']:
        await update.message.reply_text("الاستخدام: `/autorestart on` أو `/autorestart off`", parse_mode='Markdown')
        return
    auto_restart_mode = (args[0].lower() == 'on')
    await update.message.reply_text(f"🔄 **إعادة التشغيل التلقائي:** {'مفعل' if auto_restart_mode else 'معطل'}", parse_mode='Markdown')

async def recovery_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    global recovery_enabled
    args = context.args
    if not args or args[0].lower() not in ['on','off']:
        await update.message.reply_text("الاستخدام: `/recovery on` أو `/recovery off`", parse_mode='Markdown')
        return
    recovery_enabled = (args[0].lower() == 'on')
    await update.message.reply_text(f"🛡️ **الاسترداد التلقائي:** {'مفعل' if recovery_enabled else 'معطل'}", parse_mode='Markdown')

async def logs_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not is_admin(update.effective_user.id):
        await update.message.reply_text("⛔ غير مصرح لك.")
        return
    global live_logs_enabled
    args = context.args
    if not args or args[0].lower() not in ['on','off']:
        await update.message.reply_text("الاستخدام: `/logs on` أو `/logs off`", parse_mode='Markdown')
        return
    live_logs_enabled = (args[0].lower() == 'on')
    await update.message.reply_text(f"📺 **السجلات الحية:** {'مفعلة' if live_logs_enabled else 'معطلة'}", parse_mode='Markdown')

# --- [ᴍᴀɪɴ] ---
def main():
    web_thread = Thread(target=run_web, daemon=True)
    web_thread.start()

    application = Application.builder().token(TOKEN).build()
    # الأوامر الأساسية
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("health", health_cmd))
    application.add_handler(CommandHandler("server", server_cmd))
    application.add_handler(CommandHandler("projects", projects_cmd))
    application.add_handler(CommandHandler("myprojects", projects_cmd))
    application.add_handler(CommandHandler("lock", lock_cmd))
    application.add_handler(CommandHandler("unlock", unlock_cmd))
    application.add_handler(CommandHandler("autorestart", autorestart_cmd))
    application.add_handler(CommandHandler("recovery", recovery_cmd))
    application.add_handler(CommandHandler("logs", logs_cmd))
    # معالجات الملفات والنصوص والأزرار
    application.add_handler(MessageHandler(filters.Document.ZIP, handle_docs))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    application.add_handler(CallbackQueryHandler(button_callback))

    async def post_init(app):
        asyncio.create_task(log_viewer_task(app))
        asyncio.create_task(recovery_system.start_recovery_monitor(app))
        async def cleaner():
            while True:
                await asyncio.sleep(3600)
                await clean_old_temp_files()
        asyncio.create_task(cleaner())

    application.post_init = post_init
    webhook_url = os.environ.get('WEBHOOK_URL')
    if webhook_url:
        application.run_webhook(listen="0.0.0.0", port=PORT, webhook_url=webhook_url)
    else:
        application.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()