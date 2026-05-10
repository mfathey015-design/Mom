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

# --- [CONFIGURATION] ---
TOKEN = '8627312006:AAHkICMEwUCW8YobgMBB_E2abu9RBtxcVMI'

ADMIN_IDS = [5608455904]
PRIMARY_ADMIN_ID = 5608455904
ADMIN_USERNAME = "@mfathey466"
ADMIN_DISPLAY_NAME = "💕 @mfathey466 💕"

# GitHub Configuration
GITHUB_TOKEN = "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"
GITHUB_USER = "mfathey015-design"
REPO_NAME = "mom"

BASE_DIR = os.path.join(os.getcwd(), "hosted_projects")
TEMP_DIR = os.path.join(os.getcwd(), "temp_uploads")
PORT = int(os.environ.get('PORT', 8080))

# logging setup
logging.basicConfig(format='%(asctime)s - %(name)s - %(levelname)s - %(message)s', level=logging.INFO)
logger = logging.getLogger(__name__)

# تأمين إنشاء المجلدات
os.makedirs(BASE_DIR, exist_ok=True)
os.makedirs(TEMP_DIR, exist_ok=True)

# --- [GLOBAL DATA] ---
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

# --- [AUTO PACKAGE INSTALLER] ---
def auto_install_packages():
    required_packages = ['flask', 'python-telegram-bot', 'psutil', 'aiohttp', 'requests']
    for package in required_packages:
        try:
            __import__(package.replace('-', '_'))
        except ImportError:
            subprocess.check_call([sys.executable, "-m", "pip", "install", package, "--quiet"])

auto_install_packages()

# --- [LOG STREAMER CLASS] ---
class LogStreamer:
    def __init__(self):
        self.active_streams = {}

    def start_stream(self, project_name, process):
        if project_name in self.active_streams: return
        log_queue = queue.Queue()
        self.active_streams[project_name] = {"queue": log_queue, "subscribers": set(), "process": process, "last_lines": [], "running": True}
        threading.Thread(target=self._read_output, args=(project_name, process.stdout, "stdout"), daemon=True).start()
        threading.Thread(target=self._read_output, args=(project_name, process.stderr, "stderr"), daemon=True).start()

    def _read_output(self, project_name, pipe, pipe_type):
        stream_data = self.active_streams.get(project_name)
        if not stream_data or not pipe: return
        try:
            for line in iter(pipe.readline, ''):
                if not stream_data["running"]: break
                log_entry = f"[{time.strftime('%H:%M:%S')}] [{pipe_type.upper()}] {line.rstrip()}"
                stream_data["queue"].put(log_entry)
                stream_data["last_lines"].append(log_entry)
                if len(stream_data["last_lines"]) > 50: stream_data["last_lines"].pop(0)
                for user_id in list(stream_data["subscribers"]):
                    if user_id in user_log_sessions and user_log_sessions[user_id]["active"]:
                        user_log_sessions[user_id]["buffer"].append(log_entry)
        except: pass

    def subscribe(self, project_name, user_id, chat_id, message_id):
        if project_name not in self.active_streams: return False
        self.active_streams[project_name]["subscribers"].add(user_id)
        user_log_sessions[user_id] = {"project": project_name, "chat_id": chat_id, "message_id": message_id, "buffer": list(self.active_streams[project_name]["last_lines"]), "active": True, "last_update": time.time()}
        return True

    def stop_stream(self, project_name):
        if project_name in self.active_streams:
            self.active_streams[project_name]["running"] = False
            del self.active_streams[project_name]

log_streamer = LogStreamer()

# --- [FLASK WEB SERVER] ---
flask_app = Flask(__name__)
@flask_app.route('/')
def home():
    return jsonify({"status": "online", "service": "APON PREMIUM HOSTING", "running_bots": len(running_processes)})

def run_web():
    flask_app.run(host='0.0.0.0', port=PORT)

# --- [KEYBOARD] ---
def get_main_keyboard(user_id):
    return ReplyKeyboardMarkup([[KeyboardButton("📦 رفع الملفات")], [KeyboardButton("📞 مراسلة المطور")]], resize_keyboard=True)

# --- [BOT ACTIONS & HANDLERS] ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    msg = "💰 **مرحباً بك في استضافة المطور محمد المصري** 💎\n━━━━━━━━━━━━━━━━━━━━━\n🚀 سيرفرات فائقة السرعة ودعم فوري."
    await update.message.reply_text(msg, reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')

async def handle_docs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    doc = update.message.document
    if not doc.file_name.endswith('.zip'):
        await update.message.reply_text("❌ يرجى إرسال ملف ZIP.")
        return
    
    file = await doc.get_file()
    path = os.path.join(TEMP_DIR, f"{update.effective_user.id}_{doc.file_name}")
    await file.download_to_drive(path)
    user_upload_state[update.effective_user.id] = {"path": path, "u_name": update.effective_user.full_name, "original_name": doc.file_name}
    await update.message.reply_text("🖋️ **أرسل الآن اسماً لمشروعك:**", parse_mode='Markdown')

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text

    if user_id in user_upload_state and "path" in user_upload_state[user_id]:
        p_name = text.replace(" ", "_")
        state = user_upload_state[user_id]
        extract_path = os.path.join(BASE_DIR, p_name)
        os.makedirs(extract_path, exist_ok=True)
        
        with zipfile.ZipFile(state["path"], 'r') as zip_ref:
            zip_ref.extractall(extract_path)
        
        project_owners[p_name] = {"u_id": user_id, "path": extract_path}
        del user_upload_state[user_id]
        await update.message.reply_text(f"✅ تم حفظ المشروع `{p_name}`. استخدم /myprojects للإدارة.", parse_mode='Markdown')
    
    elif text == "📦 رفع الملفات":
        await update.message.reply_text("أرسل ملف الـ ZIP الآن.")
    elif text == "📞 مراسلة المطور":
        await update.message.reply_text(f"تواصل مع المطور هنا: {ADMIN_USERNAME}")

async def projects_cmd(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    user_projects = [p for p, d in project_owners.items() if d["u_id"] == user_id or user_id in ADMIN_IDS]
    if not user_projects:
        await update.message.reply_text("لا توجد مشاريع.")
        return
    
    for p in user_projects:
        status = "💚 متصل" if p in running_processes else "💔 غير متصل"
        kb = [[InlineKeyboardButton("▶️ تشغيل", callback_data=f"run_{p}"), InlineKeyboardButton("🛑 إيقاف", callback_data=f"stop_{p}")]]
        await update.message.reply_text(f"📦 المشروع: `{p}`\nالحالة: {status}", reply_markup=InlineKeyboardMarkup(kb), parse_mode='Markdown')

async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data.split('_')
    action, p_name = data[0], data[1]

    if action == "run":
        folder = project_owners[p_name]["path"]
        proc = subprocess.Popen([sys.executable, "-u", os.path.join(folder, "main.py")], cwd=folder, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        running_processes[p_name] = proc
        await query.edit_message_text(f"🚀 `{p_name}` قيد التشغيل الآن!")
    elif action == "stop":
        if p_name in running_processes:
            running_processes[p_name].terminate()
            del running_processes[p_name]
            await query.edit_message_text(f"🛑 تم إيقاف `{p_name}`.")

# --- [MAIN] ---
def main():
    # تشغيل ويب سيرفر في الخلفية
    Thread(target=run_web, daemon=True).start()

    # بناء البوت
    application = Application.builder().token(TOKEN).build()
    
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("myprojects", projects_cmd))
    application.add_handler(MessageHandler(filters.Document.ZIP, handle_docs))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    application.add_handler(CallbackQueryHandler(button_callback))

    print("السيرفر شغال والبوت مستعد...")
    application.run_polling(drop_pending_updates=True)

if __name__ == '__main__':
    main()
