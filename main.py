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
from threading import Thread
from flask import Flask, jsonify
from telegram import ReplyKeyboardMarkup, KeyboardButton, Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import Application, CommandHandler, CallbackQueryHandler, MessageHandler, filters, ContextTypes

# --- [ᴄᴏɴꜰɪɢᴜʀᴀᴛɪᴏɴ] ---
TOKEN = '8627312006:AAHkICMEwUCW8YobgMBB_E2abu9RBtxcVMI'

ADMIN_IDS = [
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

# 🔴 Channel Mandatory Settings
REQUIRED_CHANNEL = "https://t.me/mfathey455"
REQUIRED_CHANNEL_ID = -1002497131761

BASE_DIR = os.path.join(os.getcwd(), "hosted_projects")
TEMP_DIR = os.path.join(os.getcwd(), "temp_uploads")
PORT = int(os.environ.get('PORT', 8080))

# ʟᴏɢɢɪɴɢ ꜱᴇᴛᴜᴘ
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO
)
logger = logging.getLogger(__name__)

# ᴄʀᴇᴀᴛᴇ ᴅɪʀᴇᴄᴛᴏʀɪᴇꜱ
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
monitor_tasks = set()  # لتتبع مهام المراقبة ومنع التكرار

# --- [PSUTIL CHECK] ---
try:
    import psutil
    PSUTIL_AVAILABLE = True
except ImportError:
    PSUTIL_AVAILABLE = False
    logger.warning("psutil not available, using basic info")

# --- [ᴀᴜᴛᴏ ᴘᴀᴄᴋᴀɢᴇ ɪɴꜱᴛᴀʟʟᴇʀ] ---
def auto_install_packages():
    required_packages = ['flask', 'python-telegram-bot', 'psutil', 'aiohttp']
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
    """حذف الملفات المؤقتة الأقدم من ساعة"""
    now = time.time()
    for f in os.listdir(TEMP_DIR):
        path = os.path.join(TEMP_DIR, f)
        if os.path.isfile(path) and (now - os.path.getmtime(path)) > max_age_seconds:
            os.unlink(path)
        elif os.path.isdir(path) and (now - os.path.getmtime(path)) > max_age_seconds:
            shutil.rmtree(path, ignore_errors=True)

async def check_channel_membership(user_id: int, context: ContextTypes.DEFAULT_TYPE) -> bool:
    if is_admin(user_id):
        return True
    if not REQUIRED_CHANNEL_ID:
        return True
    try:
        member = await context.bot.get_chat_member(chat_id=REQUIRED_CHANNEL_ID, user_id=user_id)
        return member.status not in ['left', 'kicked', 'banned']
    except Exception as e:
        logger.error(f"Membership check error: {e}")
        return False

async def require_channel_join(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if await check_channel_membership(user_id, context):
        return True
    keyboard = [[InlineKeyboardButton("📢 Join Channel", url=REQUIRED_CHANNEL)],
                [InlineKeyboardButton("✅ I have joined", callback_data="check_join")]]
    text = "⚠️ **You must join our official channel to use this bot!**\n\n1. Click the button below to join.\n2. After joining, click 'I have joined'."
    if update.message:
        await update.message.reply_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif update.callback_query:
        await update.callback_query.edit_message_text(text, reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    return False

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
    """دالة تحريك عامة تعمل مع أي رسالة (من message أو callback_query)"""
    msg = None
    for i, frame in enumerate(frames):
        await asyncio.sleep(delay)
        try:
            if i == 0:
                if message_id:
                    msg = await context.bot.edit_message_text(chat_id=chat_id, message_id=message_id, text=frame)
                else:
                    # لا يوجد message_id أولي (حالة نادرة)
                    pass
            else:
                await context.bot.edit_message_text(chat_id=chat_id, message_id=msg.message_id, text=frame)
        except Exception as e:
            logger.debug(f"Animate error: {e}")
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

# --- [ᴋᴇʏʙᴏᴀʀᴅ ꜱᴇᴛᴜᴘ] ---
def get_main_keyboard(user_id):
    lock_status = "🔓 ᴜɴʟᴏᴄᴋ ꜱʏꜱᴛᴇᴍ" if bot_locked else "🔒 ʟᴏᴄᴋ ꜱʏꜱᴛᴇᴍ"
    restart_status = "🔄 ᴀᴜᴛᴏ ʀᴇꜱᴛᴀʀᴛ: ᴏꜰꜰ" if auto_restart_mode else "🔄 ᴀᴜᴛᴏ ʀᴇꜱᴛᴀʀᴛ: ᴏɴ"
    recovery_status = "🛡️ ʀᴇᴄᴏᴠᴇʀʏ: ᴏꜰꜰ" if recovery_enabled else "🛡️ ʀᴇᴄᴏᴠᴇʀʏ: ᴏɴ"
    logs_status = "📺 ʟɪᴠᴇ ʟᴏɢꜱ: ᴏꜰꜰ" if live_logs_enabled else "📺 ʟɪᴠᴇ ʟᴏɢꜱ: ᴏɴ"
    if is_admin(user_id):
        layout = [[KeyboardButton("🗳️ ᴜᴘʟᴏᴀᴅ ᴍᴀɴᴀɢᴇʀ"), KeyboardButton("📮 ꜰɪʟᴇ ᴍᴀɴᴀɢᴇʀ")],[KeyboardButton("🗑️ ᴅᴇʟᴇᴛᴇ ᴍᴀɴᴀɢᴇʀ"), KeyboardButton("🏩 ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ")],[KeyboardButton("🌎 ꜱᴇʀᴠᴇʀ ɪɴꜰᴏ"), KeyboardButton("📠 ᴄᴏɴᴛᴀᴄᴛ ᴀᴅᴍɪɴ")],[KeyboardButton(lock_status), KeyboardButton(restart_status)],[KeyboardButton(recovery_status), KeyboardButton("🎬 ᴘʀᴏᴊᴇᴄᴛ ꜰɪʟᴇ")],[KeyboardButton(logs_status)]]
    else:
        layout = [[KeyboardButton("🗳️ ᴜᴘʟᴏᴀᴅ ᴍᴀɴᴀɢᴇʀ"), KeyboardButton("📮 ꜰɪʟᴇ ᴍᴀɴᴀɢᴇʀ")],[KeyboardButton("🗑️ ᴅᴇʟᴇᴛᴇ ᴍᴀɴᴀɢᴇʀ"), KeyboardButton("🏩 ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ")],[KeyboardButton("🌎 ꜱᴇʀᴠᴇʀ ɪɴꜰᴏ"), KeyboardButton("📠 ᴄᴏɴᴛᴀᴄᴛ ᴀᴅᴍɪɴ")],[KeyboardButton(logs_status)]]
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

# --- [ᴄᴏʀᴇ ꜰᴜɴᴄᴛɪᴏɴꜱ] ---
async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not await require_channel_join(update, context):
        return
    if bot_locked and not is_admin(user_id):
        await update.message.reply_text("🔒 **ꜱʏꜱᴛᴇᴍ ɪꜱ ᴄᴜʀʀᴇɴᴛʟʏ ʟᴏᴄᴋᴇᴅ ʙʏ ᴀᴅᴍɪɴ**", parse_mode='Markdown')
        return
    msg = ("🌍 **ʟᴀᴍ ᴘʀᴇᴍɪᴜᴍ ʜᴏꜱᴛɪɴɗ ᴠ1** 🌸\n━━━━━━━━━━━━━━━━━━━━━\n💙 **ᴡᴇʟᴄᴏᴍᴇ ᴛᴏ ᴛʜᴇ ᴇʟɪᴛᴇ ᴘᴀɴᴇʟ**\n🔮 **Welcome! This is the most powerful premium server in India.**\n\n" f"🇮🇳 **ᴏᴡɴᴇʀ:** `{ADMIN_USERNAME}`\n" f"📢 **ᴄʜᴀɴɴᴇʟ:** {'Not Set' if not REQUIRED_CHANNEL else REQUIRED_CHANNEL}\n━━━━━━━━━━━━━━━━━━━━━")
    await update.message.reply_text(msg, reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    text = update.message.text
    global bot_locked, auto_restart_mode, recovery_enabled, live_logs_enabled

    if not await require_channel_join(update, context):
        return
    if bot_locked and not is_admin(user_id):
        await update.message.reply_text("🔒 **System is currently locked.**", parse_mode='Markdown')
        return

    # Live logs toggle
    if "📺 ʟɪᴠᴇ ʟᴏɢꜱ:" in text:
        if "ᴏɴ" in text:
            live_logs_enabled = True
            msg = await update.message.reply_text(Loading.logs_on()[0])
            for frame in Loading.logs_on()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("📺 **ʟɪᴠᴇ ʟᴏɢꜱ: ᴇɴᴀʙʟᴇᴅ**", parse_mode='Markdown')
        else:
            live_logs_enabled = False
            for uid in list(user_log_sessions.keys()):
                log_streamer.unsubscribe(uid)
            msg = await update.message.reply_text(Loading.logs_off()[0])
            for frame in Loading.logs_off()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("❌ **ʟɪᴠᴇ ʟᴏɢꜱ: ᴅɪꜱᴀʙʟᴇᴅ**", parse_mode='Markdown')
        await update.message.reply_text("ᴍᴇɴᴜ ᴜᴘᴅᴀᴛᴇᴅ!", reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')
        return

    # Project naming after upload
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
                await msg.edit_text("❌ **ᴇʀʀᴏʀ: ᴍᴀɪɴ.ᴘʏ ɴᴏᴛ ꜰᴏᴜɴᴅ ɪɴ ᴢɪᴘ!**", parse_mode='Markdown')
                shutil.rmtree(extract_path)
                return
            if os.path.exists(req_txt):
                for frame in Loading.installing():
                    await msg.edit_text(frame)
                    await asyncio.sleep(1.0)
                try:
                    subprocess.run([sys.executable, "-m", "pip", "install", "-r", req_txt], check=True, capture_output=True, text=True, cwd=extract_path)
                except subprocess.CalledProcessError:
                    await msg.edit_text("⚠️ **ᴡᴀʀɴɪɴɗ: ꜱᴏᴍᴇ ʀᴇǫᴜɪʀᴇᴍᴇɴᴛꜱ ꜰᴀɪʟᴇᴅ**", parse_mode='Markdown')
                    await asyncio.sleep(1)
            project_owners[p_name] = {"u_id": user_id,"u_name": state["u_name"],"u_username": update.effective_user.username or "ɴᴏ_ᴜꜱᴇʀɴᴀᴍᴇ","zip": state["path"],"original_name": state["original_name"],"path": extract_path}
            del user_upload_state[user_id]
            final_text = f"✅ **ᴘʀᴏᴊᴇᴄᴛ `{p_name}` ꜱᴀᴠᴇᴅ!**\n━━━━━━━━━━━━━━━━━━━━━\n🚀 **Now go to '📮 FILE MANAGER' and run it.**\n━━━━━━━━━━━━━━━━━━━━━"
            await msg.edit_text(final_text, parse_mode='Markdown')
        except Exception as e:
            logger.error(f"Upload error: {e}")
            await update.message.reply_text(f"❌ **ᴇʀʀᴏʀ:** `{str(e)}`", parse_mode='Markdown')
        return

    # Button handlers
    if text == "🗳️ ᴜᴘʟᴏᴀᴅ ᴍᴀɴᴀɢᴇʀ":
        await update.message.reply_text("🗳️ **ᴜᴘʟᴏᴀᴅ ᴍᴀɴᴀɢᴇʀ**\n━━━━━━━━━━━━━━━━━━━━━\n📪 **ꜱᴇɴᴅ ʏᴏᴜʀ .ᴢɪᴘ ꜰɪʟᴇ ᴄᴏɴᴛᴀɪɴɪɴɗ:**\n• `ᴍᴀɪɴ.ᴘʏ` (ʏᴏᴜʀ ʙᴏᴛ ᴄᴏᴅᴇ)\n• `ʀᴇǫᴜɪʀᴇᴍᴇɴᴛꜱ.ᴛxᴛ` (ᴅᴇᴘᴇɴᴅᴇɴᴄɪᴇꜱ)\n━━━━━━━━━━━━━━━━━━━━━", parse_mode='Markdown')
    elif text == "📮 ꜰɪʟᴇ ᴍᴀɴᴀɢᴇʀ":
        user_projects = [p for p, d in project_owners.items() if d["u_id"] == user_id]
        if not user_projects:
            await update.message.reply_text("📮 **ɴᴏ ᴘʀᴏᴊᴇᴄᴛꜱ ꜰᴏᴜɴᴅ**", parse_mode='Markdown')
            return
        keyboard = []
        for p in user_projects:
            status = "💚 ᴏɴʟɪɴᴇ" if (p in running_processes and running_processes[p].poll() is None) else "💔 ᴏꜰꜰʟɪɴᴇ"
            keyboard.append([InlineKeyboardButton(f"{status} | {p}", callback_data=f"manage_{p}")])
        await update.message.reply_text("📮 **ᴍʏ ꜰɪʟᴇ ᴍᴀɴᴀɢᴇʀ**\n━━━━━━━━━━━━━━━━━━━━━", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif text == "🗑️ ᴅᴇʟᴇᴛᴇ ᴍᴀɴᴀɢᴇʀ":
        user_projects = [p for p, d in project_owners.items() if d["u_id"] == user_id]
        if not user_projects:
            await update.message.reply_text("🗑️ **ɴᴏ ᴘʀᴏᴊᴇᴄᴛꜱ**", parse_mode='Markdown')
            return
        keyboard = [[InlineKeyboardButton(f"🗑️ {p}", callback_data=f"del_{p}")] for p in user_projects]
        await update.message.reply_text("🗑️ **ꜱᴇʟᴇᴄᴛ ᴘʀᴏᴊᴇᴄᴛ ᴛᴏ ᴅᴇʟᴇᴛᴇ:**", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
    elif "🔄 ᴀᴜᴛᴏ ʀᴇꜱᴛᴀʀᴛ:" in text and is_admin(user_id):
        if "ᴏɴ" in text:
            auto_restart_mode = True
            msg = await update.message.reply_text(Loading.restarting()[0])
            for frame in Loading.restarting()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("🔄 **ᴀᴜᴛᴏ ʀᴇꜱᴛᴀʀᴛ: ᴀᴄᴛɪᴠᴀᴛᴇᴅ**", parse_mode='Markdown')
        else:
            auto_restart_mode = False
            msg = await update.message.reply_text(Loading.restarting()[0])
            for frame in Loading.restarting()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("🔄 **ᴀᴜᴛᴏ ʀᴇꜱᴛᴀʀᴛ: ᴅᴇᴀᴄᴛɪᴠᴀᴛᴇᴅ**", parse_mode='Markdown')
        await update.message.reply_text("ᴍᴇɴᴜ ᴜᴘᴅᴀᴛᴇᴅ!", reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')
    elif text in ["🔒 ʟᴏᴄᴋ ꜱʏꜱᴛᴇᴍ", "🔓 ᴜɴʟᴏᴄᴋ ꜱʏꜱᴛᴇᴍ"] and is_admin(user_id):
        if "ʟᴏᴄᴋ" in text and "ᴜɴʟᴏᴄᴋ" not in text:
            bot_locked = True
            await update.message.reply_text("🔒 **ꜱʏꜱᴛᴇᴍ ʟᴏᴄᴋᴇᴅ**", parse_mode='Markdown')
        else:
            bot_locked = False
            await update.message.reply_text("🔓 **ꜱʏꜱᴛᴇᴍ ᴜɴʟᴏᴄᴋᴇᴅ**", parse_mode='Markdown')
        await update.message.reply_text("ᴍᴇɴᴜ ᴜᴘᴅᴀᴛᴇᴅ!", reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')
    elif "🛡️ ʀᴇᴄᴏᴠᴇʀʏ:" in text and is_admin(user_id):
        if "ᴏɴ" in text:
            recovery_enabled = True
            msg = await update.message.reply_text(Loading.recovering()[0])
            for frame in Loading.recovering()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("🛡️ **ᴀᴜᴛᴏ ʀᴇᴄᴏᴠᴇʀʏ: ᴇɴᴀʙʟᴇᴅ**", parse_mode='Markdown')
        else:
            recovery_enabled = False
            msg = await update.message.reply_text(Loading.recovering()[0])
            for frame in Loading.recovering()[1:]:
                await asyncio.sleep(0.5)
                await msg.edit_text(frame)
            await msg.edit_text("🛡️ **ᴀᴜᴛᴏ ʀᴇᴄᴏᴠᴇʀʏ: ᴅɪꜱᴀʙʟᴇᴅ**", parse_mode='Markdown')
        await update.message.reply_text("ᴍᴇɴᴜ ᴜᴘᴅᴀᴛᴇᴅ!", reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')
    elif text == "🎬 ᴘʀᴏᴊᴇᴄᴛ ꜰɪʟᴇ" and is_admin(user_id):
        total = len(project_owners)
        running = len([p for p in running_processes.values() if p.poll() is None])
        offline = total - running
        status_text = f"🎬 **ᴘʀᴏᴊᴇᴄᴛ ꜱᴛᴀᴛᴜꜱ**\n━━━━━━━━━━━━━━━━━━━━━\n📊 **ᴛᴏᴛᴀʟ ᴘʀᴏᴊᴇᴄᴛꜱ:** `{total}`\n💚 **ᴏɴʟɪɴᴇ:** `{running}`\n💔 **ᴏꜰꜰʟɪɴᴇ:** `{offline}`\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** `{'ᴏɴ' if live_logs_enabled else 'ᴏꜰꜰ'}`\n━━━━━━━━━━━━━━━━━━━━━"
        await update.message.reply_text(status_text, parse_mode='Markdown')
    elif text == "🏩 ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ":
        msg = await update.message.reply_text("🏩 **ᴄʜᴇᴄᴋɪɴɗ ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ...**")
        health_data = await get_system_health()
        if health_data["status"] == "ok":
            text_health = (f"🏩 **ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ**\n━━━━━━━━━━━━━━━━━━━━━\n🖥️ **ᴄᴘᴜ:** {health_data['cpu']} ({health_data['cpu_cores']} ᴄᴏʀᴇꜱ)\n🧠 **ʀᴀᴍ:** {health_data['ram']} ({health_data['ram_used']}/{health_data['ram_total']})\n💾 **ᴅɪꜱᴋ:** {health_data['disk']} ({health_data['disk_used']}/{health_data['disk_total']})\n⏱️ **ᴜᴘᴛɪᴍᴇ:** {health_data['uptime']}\n📮 **ᴘʀᴏᴊᴇᴄᴛꜱ:** {len(project_owners)}\n💚 **ʀᴜɴɴɪɴɗ:** {len([p for p in running_processes.values() if p.poll() is None])}\n🛡️ **ʀᴇᴄᴏᴠᴇʀʏ:** {'ᴏɴ' if recovery_enabled else 'ᴏꜰꜰ'}\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** {'ᴏɴ' if live_logs_enabled else 'ᴏꜰꜰ'}\n━━━━━━━━━━━━━━━━━━━━━\n✅ **ꜱʏꜱᴛᴇᴍ ɪꜱ ʜᴇᴀʟᴛʜʏ**")
        elif health_data["status"] == "basic":
            text_health = (f"🏩 **ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ** (ʙᴀꜱɪᴄ)\n━━━━━━━━━━━━━━━━━━━━━\n🖥️ **ᴘʟᴀᴛꜰᴏʀᴍ:** {health_data['platform']}\n⚙️ **ᴍᴀᴄʜɪɴᴇ:** {health_data['machine']}\n🔧 **ᴘʀᴏᴄᴇꜱꜱᴏʀ:** {health_data['processor']}\n🐍 **ᴘʏᴛʜᴏɴ:** {health_data['python_version']}\n📮 **ᴘʀᴏᴊᴇᴄᴛꜱ:** {len(project_owners)}\n💚 **ʀᴜɴɴɪɴɗ:** {len([p for p in running_processes.values() if p.poll() is None])}\n🛡️ **ʀᴇᴄᴏᴠᴇʀʏ:** {'ᴏɴ' if recovery_enabled else 'ᴏꜰꜰ'}\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** {'ᴏɴ' if live_logs_enabled else 'ᴏꜰꜰ'}\n━━━━━━━━━━━━━━━━━━━━━\n⚠️ **ɪɴꜱᴛᴀʟʟ `psutil` ꜰᴏʀ ᴅᴇᴛᴀɪʟᴇᴅ ꜱᴛᴀᴛꜱ**")
        else:
            text_health = (f"🏩 **ꜱʏꜱᴛᴇᴍ ʜᴇᴀʟᴛʜ**\n━━━━━━━━━━━━━━━━━━━━━\n💞 ʜɪ ᴇᴠᴇʀʏᴏɴᴇ ᴡᴇʟᴄᴏᴍᴇ ᴛᴏ🔸ᴢᴇɴᴏɴ-ᴀᴘᴏɴ ʙᴏᴛ ᴀʟʟ ꜱᴇʀᴠᴇʀ 💞\n\nꜰʀᴇᴇ ꜰɪʀᴇ\n\n📮 **ᴘʀᴏᴊᴇᴄᴛꜱ:** {len(project_owners)}\n💚 **ʀᴜɴɴɪɴɗ:** {len([p for p in running_processes.values() if p.poll() is None])}\n🛡️ **ʀᴇᴄᴏᴠᴇʀʏ:** {'ᴏɴ' if recovery_enabled else 'ᴏꜰꜰ'}\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** {'ᴏɴ' if live_logs_enabled else 'ᴏꜰꜰ'}")
        await msg.edit_text(text_health, parse_mode='Markdown')
    elif text == "🌎 ꜱᴇʀᴠᴇʀ ɪɴꜰᴏ":
        await update.message.reply_text(f"🌎 **ꜱᴇʀᴠᴇʀ ɪɴꜰᴏ**\n🚀 **ᴘᴏʀᴛ:** {PORT}\n🛡️ **ᴘʟᴀᴛꜰᴏʀᴍ:** {os.environ.get('PLATFORM', 'ᴜɴᴋɴᴏᴡɴ')}\n🔄 **ᴀᴜᴛᴏ-ʀᴇꜱᴛᴀʀᴛ:** {'ᴏɴ' if auto_restart_mode else 'ᴏꜰꜰ'}\n🛡️ **ᴀᴜᴛᴏ-ʀᴇᴄᴏᴠᴇʀʏ:** {'ᴏɴ' if recovery_enabled else 'ᴏꜰꜰ'}\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** {'ᴏɴ' if live_logs_enabled else 'ᴏꜰꜰ'}\n📢 **ʀᴇǫᴜɪʀᴇᴅ ᴄʜᴀɴɴᴇʟ:** {'Not Set' if not REQUIRED_CHANNEL else REQUIRED_CHANNEL}", parse_mode='Markdown')
    elif text == "📠 ᴄᴏɴᴛᴀᴄᴛ ᴀᴅᴍɪɴ":
        keyboard = InlineKeyboardMarkup([[InlineKeyboardButton("📠 ᴄᴏɴᴛᴀᴄᴛ ᴏᴡɴᴇʀ", url=f"tg://user?id={PRIMARY_ADMIN_ID}")]])
        await update.message.reply_text(f"{ADMIN_DISPLAY_NAME}\n📠 ᴄᴏɴᴛᴀᴄᴛ ᴏᴡɴᴇʀ", reply_markup=keyboard, parse_mode='Markdown')

async def handle_docs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    user_id = update.effective_user.id
    if not await require_channel_join(update, context):
        return
    if bot_locked and not is_admin(user_id):
        return
    doc = update.message.document
    if not doc.file_name.endswith('.zip'):
        await update.message.reply_text("❌ **ᴘʟᴇᴀꜱᴇ ꜱᴇɴᴅ ᴀ .ᴢɪᴘ ꜰɪʟᴇ ᴏɴʟʏ!**", parse_mode='Markdown')
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
        await msg.edit_text("🖋️ **ɴᴀᴍᴇ ʏᴏᴜʀ ᴘʀᴏᴊᴇᴄᴛ**\n━━━━━━━━━━━━━━━━━━━━━\n💬 **Send a name for your project (ꜱᴘᴀᴄᴇ ᴀʟʟᴏᴡᴇᴅ):**", parse_mode='Markdown')
    except Exception as e:
        logger.error(f"Download error: {e}")
        await msg.edit_text("❌ **ᴅᴏᴡɴʟᴏᴀᴅ ꜰᴀɪʟᴇᴅ!**", parse_mode='Markdown')
        os.unlink(temp_zip) if os.path.exists(temp_zip) else None

async def button_callback(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()
    data = query.data.split('_')
    action, p_name = data[0], "_".join(data[1:])
    user_id = update.effective_user.id

    if query.data == "check_join":
        if await check_channel_membership(user_id, context):
            await query.edit_message_text("✅ **Verification successful! You can now use the bot.**", parse_mode='Markdown')
            # إعادة إرسال قائمة البداية بنفس طريقة /start ولكن من callback
            if bot_locked and not is_admin(user_id):
                await query.message.reply_text("🔒 **System is locked.**", parse_mode='Markdown')
            else:
                msg = ("🌍 **ʟᴀᴍ ᴘʀᴇᴍɪᴜᴍ ʜᴏꜱᴛɪɴɗ ᴠ1** 🌸\n━━━━━━━━━━━━━━━━━━━━━\n💙 **ᴡᴇʟᴄᴏᴍᴇ ᴛᴏ ᴛʜᴇ ᴇʟɪᴛᴇ ᴘᴀɴᴇʟ**\n🔮 **Welcome! This is the most powerful premium server in India.**\n\n" f"🇮🇳 **ᴏᴡɴᴇʀ:** `{ADMIN_USERNAME}`\n" f"📢 **ᴄʜᴀɴɴᴇʟ:** {'Not Set' if not REQUIRED_CHANNEL else REQUIRED_CHANNEL}\n━━━━━━━━━━━━━━━━━━━━━")
                await query.message.reply_text(msg, reply_markup=get_main_keyboard(user_id), parse_mode='Markdown')
        else:
            await query.answer("❌ You haven't joined the channel yet!", show_alert=True)
        return

    if action == "run":
        if p_name in running_processes and running_processes[p_name].poll() is None:
            await query.edit_message_text(f"⚠️ **`{p_name}` ɪꜱ ᴀʟʀᴇᴀᴅʏ ʀᴜɴɴɪɴɗ!**", parse_mode='Markdown')
            return
        folder = project_owners.get(p_name, {}).get("path")
        if not folder:
            await query.edit_message_text(f"❌ **Project `{p_name}` not found**", parse_mode='Markdown')
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
                keyboard = [[InlineKeyboardButton("▶️ ʀᴜɴ", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 ꜱᴛᴏᴘ", callback_data=f"stop_{p_name}")],[InlineKeyboardButton("📺 ᴠɪᴇᴡ ʟɪᴠᴇ ʟᴏɢꜱ", callback_data=f"viewlogs_{p_name}")],[InlineKeyboardButton("🗑️ ᴅᴇʟᴇᴛᴇ", callback_data=f"del_{p_name}")]]
                await msg.edit_text(f"🚀 **`{p_name}` ɪꜱ ɴᴏᴡ ᴏɴʟɪɴᴇ! 💚**\n\n📺 Click **View Live Logs** to see live output.", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')
            except Exception as e:
                await msg.edit_text(f"❌ **ꜰᴀɪʟᴇᴅ ᴛᴏ ꜱᴛᴀʀᴛ:** `{str(e)}`", parse_mode='Markdown')
        else:
            await query.edit_message_text(f"❌ **ᴍᴀɪɴ.ᴘʏ ɴᴏᴛ ꜰᴏᴜɴᴅ!**", parse_mode='Markdown')
    elif action == "stop":
        if p_name in running_processes:
            msg = await query.edit_message_text("🛑 ꜱᴛᴏᴘᴘɪɴɗ: [▰▰▰▰▰▰▰▰▰▰] 100%")
            for text in ["🛑 ꜱᴛᴏᴘᴘɪɴɗ: [▰▰▰▰▰▰▰▰▱▱] 80%","🛑 ꜱᴛᴏᴘᴘɪɴɗ: [▰▰▰▰▰▰▰▱▱▱] 60%","🛑 ꜱᴛᴏᴘᴘɪɴɗ: [▰▰▰▰▰▰▱▱▱▱] 40%"]:
                await asyncio.sleep(0.3)
                await msg.edit_text(text)
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
            await msg.edit_text(f"🛑 **`{p_name}` ɪꜱ ɴᴏᴡ ᴏꜰꜰʟɪɴᴇ! 💔**", parse_mode='Markdown')
        else:
            await query.edit_message_text(f"⚠️ **`{p_name}` ᴡᴀꜱ ɴᴏᴛ ʀᴜɴɴɪɴɗ**", parse_mode='Markdown')
    elif action == "viewlogs":
        if not live_logs_enabled:
            await query.answer("❌ Live logs are currently turned off!", show_alert=True)
            return
        if p_name not in running_processes or running_processes[p_name].poll() is not None:
            await query.answer("❌ This project is not currently running!", show_alert=True)
            return
        log_msg = await context.bot.send_message(chat_id=update.effective_chat.id, text="📺 **ɪɴɪᴛɪᴀʟɪᴢɪɴɗ ʟɪᴠᴇ ᴄᴏɴꜱᴏʟᴇ...**", parse_mode='Markdown')
        if log_streamer.subscribe(p_name, user_id, update.effective_chat.id, log_msg.message_id):
            await query.answer("✅ Live logs started!", show_alert=True)
        else:
            await log_msg.edit_text("❌ **Failed to start log stream!**", parse_mode='Markdown')
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
        await msg.edit_text(f"🗑️ **`{p_name}` ᴅᴇʟᴇᴛᴇᴅ!**", parse_mode='Markdown')
    elif action == "manage":
        status = "💚 ᴏɴʟɪɴᴇ" if (p_name in running_processes and running_processes[p_name].poll() is None) else "💔 ᴏꜰꜰʟɪɴᴇ"
        keyboard = [[InlineKeyboardButton("▶️ ʀᴜɴ", callback_data=f"run_{p_name}"), InlineKeyboardButton("🛑 ꜱᴛᴏᴘ", callback_data=f"stop_{p_name}")],[InlineKeyboardButton("📺 ᴠɪᴇᴡ ʟɪᴠᴇ ʟᴏɢꜱ", callback_data=f"viewlogs_{p_name}")],[InlineKeyboardButton("🗑️ ᴅᴇʟᴇᴛᴇ", callback_data=f"del_{p_name}")]]
        await query.edit_message_text(f"📦 **ᴘʀᴏᴊᴇᴄᴛ:** `{p_name}`\n📡 **ꜱᴛᴀᴛᴜꜱ:** {status}\n📺 **ʟɪᴠᴇ ʟᴏɢꜱ:** {'ᴀᴠᴀɪʟᴀʙʟᴇ' if live_logs_enabled else 'ᴅɪꜱᴀʙʟᴇᴅ'}", reply_markup=InlineKeyboardMarkup(keyboard), parse_mode='Markdown')

async def monitor_process(p_name, folder):
    """مراقبة وإعادة تشغيل تلقائي (يتم استدعاؤها مرة واحدة لكل مشروع)"""
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

# --- [ᴍᴀɪɴ] ---
def main():
    web_thread = Thread(target=run_web, daemon=True)
    web_thread.start()

    application = Application.builder().token(TOKEN).build()
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.Document.ZIP, handle_docs))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    application.add_handler(CallbackQueryHandler(button_callback))

    async def post_init(app):
        asyncio.create_task(log_viewer_task(app))
        asyncio.create_task(recovery_system.start_recovery_monitor(app))
        # تنظيف دوري للملفات المؤقتة كل ساعة
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