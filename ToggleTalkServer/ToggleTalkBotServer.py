#!/usr/bin/env python3
"""
ToggleTalk Flask Server

A Python implementation of the ToggleTalk server using Flask that handles incoming messages
and provides appropriate responses. This server includes notification broadcasting
functionality to send messages to all connected applications.

Features:
- Handles HTTP API endpoints for communication with mobile applications
- Processes text messages with contextual responses
- Supports home automation commands for three appliances:
  * Light (GPIO 23)
  * Air Conditioner (GPIO 24)
  * Washing Machine (GPIO 25)
- Can send notifications to all connected applications
- Persists application IDs for notification broadcasting
- GPIO control for Raspberry Pi relays
- Scheduled appliance control
- Event logging to file for client notification retrieval
- Enhanced console visualization with message tracking and latency monitoring
"""

import logging
import asyncio
import re
from datetime import datetime, timedelta
import json
import os
import threading
import time
import queue
import sys
from collections import deque
from flask import Flask, request, jsonify
from flask_cors import CORS
import waitress

# GPIO imports for Raspberry Pi
try:
    import RPi.GPIO as GPIO
    GPIO_AVAILABLE = True
except ImportError:
    GPIO_AVAILABLE = False
    GPIO = None
    print("GPIO library not available. Running in simulation mode.")

# Enable logging for our application only
logging.basicConfig(
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    level=logging.INFO,
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
# Set our application logger to INFO level
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Configuration
AUTHORIZED_CHAT_ID = int(os.getenv("AUTHORIZED_CHAT_ID", "1767023771"))
SERVER_PORT = int(os.getenv("SERVER_PORT", "7850"))

# GPIO pin configuration for Raspberry Pi - ONLY the three required appliances
# Allow configuration via environment variables with defaults
GPIO_PINS = {
    'light': int(os.getenv("LIGHT_GPIO_PIN", "23")),      # Relay 1 - Light
    'ac': int(os.getenv("AC_GPIO_PIN", "24")),             # Relay 2 - AC
    'washing_machine': int(os.getenv("WASHING_MACHINE_GPIO_PIN", "25")),  # Relay 3 - Washing Machine
    'laser_module': int(os.getenv("LASER_MODULE_GPIO_PIN", "27")),  # Laser Module
    'ldr_sensor': int(os.getenv("LDR_SENSOR_GPIO_PIN", "22")),  # LDR Sensor
    'buzzer': int(os.getenv("BUZZER_GPIO_PIN", "5"))  # Buzzer
}

# File paths
CHAT_IDS_FILE = "chat_ids.json"
USER_PREFERENCES_FILE = "user_preferences.json"
SCHEDULED_TASKS_FILE = "scheduled_tasks.json"
PENDING_NOTIFICATIONS_FILE = "pending_notifications.json"
EVENTS_LOG_FILE = "events.log"



# Console interface variables
console_lines = []
last_status_line = ""
last_update_time = time.time()

# Message tracking and latency monitoring
message_history = deque(maxlen=50)  # Keep last 50 messages
start_time = datetime.now()
total_messages_processed = 0
total_processing_time = 0.0

def format_latency_visualization():
    """Create a visual representation of message processing latency"""
    if not message_history:
        return "No messages processed yet"
    
    # Calculate statistics
    latencies = [msg['processing_time'] for msg in message_history if 'processing_time' in msg]
    if not latencies:
        return "No latency data available"
    
    avg_latency = sum(latencies) / len(latencies)
    max_latency = max(latencies)
    min_latency = min(latencies)
    
    # Create a more detailed bar visualization
    bar_length = 30
    avg_bar = int((avg_latency / max_latency) * bar_length) if max_latency > 0 else 0
    visual_bar = "█" * avg_bar + "░" * (bar_length - avg_bar)
    
    return f"Latency: [{visual_bar}] {avg_latency:.3f}s (min: {min_latency:.3f}s, max: {max_latency:.3f}s)"

def format_message_flow_visualization():
    """Create a visual representation of message flow"""
    if not message_history:
        return "No message flow data"
    
    # Group messages by type
    user_messages = sum(1 for msg in message_history if msg['type'] == 'user')
    bot_responses = sum(1 for msg in message_history if msg['type'] == 'bot')
    notifications = sum(1 for msg in message_history if msg['type'] == 'notification')
    
    total = len(message_history)
    user_pct = (user_messages / total) * 100 if total > 0 else 0
    bot_pct = (bot_responses / total) * 100 if total > 0 else 0
    notif_pct = (notifications / total) * 100 if total > 0 else 0
    
    # Create a more visual bar representation
    user_bar = "█" * int(user_pct/5)  # Scale down for better fit
    bot_bar = "█" * int(bot_pct/5)
    notif_bar = "█" * int(notif_pct/5)
    
    return f"Msg Flow: 👤 User:{user_pct:.0f}% {user_bar}  🤖 Bot:{bot_pct:.0f}% {bot_bar}  🔔 Notif:{notif_pct:.0f}% {notif_bar}"

def format_ngrok_style_visualization():
    """Create an ngrok-style visualization for the server"""
    uptime = datetime.now() - start_time
    uptime_str = str(uptime).split('.')[0]  # Remove microseconds
    
    # Get current message statistics
    active_users = len(set(msg['user'] for msg in message_history if msg['type'] == 'user'))
    pending_notifications = 0  # Default value
    
    # Raspberry Pi specific system info
    import platform
    pi_model = platform.machine()
    system_info = f"RPi {pi_model}" if 'arm' in pi_model.lower() else "Dev Environment"
    
    return f"""
╔══════════════════════════════════════════════════════════════════════════════════════════════════════╗
║                                    TOGGLETALK FLASK SERVER                                           ║
╠══════════════════════════════════════════════════════════════════════════════════════════════════════╣
║  🟢 Status: ONLINE                             🕒 Uptime: {uptime_str:<35} ║
║  📨 Messages: {total_messages_processed:<38} 📊 Avg Time: {total_processing_time/max(1, total_messages_processed):.3f}s ║
║  👥 Users: {active_users:<40} 🔔 Pending: {pending_notifications:<30} ║
║  🖥️  System: {system_info:<76} ║
║                                                                                                      ║
║  {format_message_flow_visualization():<88} ║
║  {format_latency_visualization():<88} ║
║                                                                                                      ║
║  🌐 Endpoints:                                                                                       ║
║     API Server: http://localhost:{SERVER_PORT}/api                                                    ║
║                                                                                                      ║
║  📋 Commands:                                                                                        ║
║     Press Ctrl+C to stop the server                                                                  ║
╚══════════════════════════════════════════════════════════════════════════════════════════════════════╝
"""

def update_console_display():
    """Update the console display with current status, overwriting previous content"""
    global console_lines, last_status_line, last_update_time
    
    # Clear screen and move cursor to top
    os.system('cls' if os.name == 'nt' else 'clear')
    
    # Print ngrok-style header
    print(format_ngrok_style_visualization())
    
    # Print recent console lines
    print("Recent Activity:")
    print("=" * 80)
    for line in console_lines[-15:]:  # Show last 15 lines
        if line:  # Only print non-empty lines
            print(f"  {line}")
    
    # Print status line if it exists
    if last_status_line:
        print()
        print(last_status_line)

def add_console_line(line):
    """Add a line to the console display"""
    global console_lines
    # Avoid duplicate lines
    if line and (not console_lines or console_lines[-1] != line):
        console_lines.append(line)
        # Keep only the last 50 lines
        if len(console_lines) > 50:
            console_lines.pop(0)
        update_console_display()

def update_status_line(line):
    """Update the status line at the bottom of the console"""
    global last_status_line, last_update_time
    if last_status_line != line:
        last_status_line = line
        current_time = time.time()
        # Update display only if enough time has passed or status has changed
        if current_time - last_update_time > 1.0:
            update_console_display()
            last_update_time = current_time

print("ToggleTalk Flask Server Starting...")
print(f"Authorized Chat ID: {AUTHORIZED_CHAT_ID}")

# Raspberry Pi detection and info
import platform
if 'arm' in platform.machine().lower():
    print("🟢 Running on Raspberry Pi - GPIO control enabled")
else:
    print("💻 Running in development mode - GPIO simulation active")

# Initialize GPIO if available
if GPIO_AVAILABLE and GPIO is not None:
    try:
        GPIO.setmode(GPIO.BCM)
        # Setup relay pins (output)
        for device, pin in GPIO_PINS.items():
            if device in ['light', 'ac', 'washing_machine', 'laser_module', 'buzzer']:
                GPIO.setup(pin, GPIO.OUT)
                GPIO.output(pin, GPIO.LOW if device == 'laser_module' else GPIO.HIGH)  # Turn off relays/buzzer, turn off laser initially
            elif device == 'ldr_sensor':
                GPIO.setup(pin, GPIO.IN)  # LDR sensor as input
        print("GPIO initialized successfully")
    except Exception as e:
        print(f"Error initializing GPIO: {e}")
        GPIO_AVAILABLE = False
else:
    print("Running in simulation mode - GPIO not available")

# Global variables
notification_queue = queue.Queue()

class ToggleTalkFlaskServer:
    def __init__(self):
        self.user_contexts = {}  # Store user conversation contexts
        self.user_preferences = self.load_user_preferences()  # Load user preferences
        # Simplified home devices - ONLY the three required appliances
        self.home_devices = {
            'light': {'status': 'off'},
            'ac': {'status': 'off'},
            'washing_machine': {'status': 'off'}
        }
        # Home security system state
        self.security_system_active = False
        self.chat_ids = self.load_chat_ids()
        self.scheduled_tasks = self.load_scheduled_tasks()
        self.pending_notifications = self.load_pending_notifications()  # Load pending notifications
        self.scheduler_thread = None
        self.scheduler_running = False
        self.last_notification_check = datetime.now()
        self.start_scheduler()
        add_console_line("Scheduler thread started")
    
    def generate_response(self, message_text: str, user_id: int, user_name: str) -> str:
        """Generate a response to the user's message"""
        logger.info(f"Generating response for: {message_text} from {user_name} (ID: {user_id})")
        # Process home automation commands first
        home_automation_response = self.process_home_automation(message_text, user_name)
        if home_automation_response:
            logger.info(f"Home automation response: {home_automation_response}")
            # If this was a device control command, send notification to all users
            if any(keyword in message_text.lower() for keyword in ['turn on', 'turn off', 'switch on', 'switch off']):
                device_name = None
                # Determine which device
                if 'light' in message_text.lower():
                    device_name = 'light'
                elif 'ac' in message_text.lower() or 'air condition' in message_text.lower():
                    device_name = 'ac'
                elif 'washing machine' in message_text.lower():
                    device_name = 'washing_machine'
                
                if device_name:
                    device_display_name = self.get_device_user_name(device_name)
                    action = 'ON' if any(keyword in message_text.lower() for keyword in ['turn on', 'switch on']) else 'OFF'
                    # Format notification according to specification
                    current_time = datetime.now().strftime("%H:%M:%S")
                    notification_msg = f"[NOTIFICATION] 🔔 {user_name}: {device_display_name} turned {action} at {current_time}"
                    # Add to pending notifications for client retrieval
                    self.add_pending_notification(notification_msg)
            
            return home_automation_response
        
        # Handle natural language queries
        message_lower = message_text.lower()
        
        # Log Details command
        if 'log details' in message_lower:
            log_details = self.get_log_details()
            return log_details
        
        # Greeting responses
        if any(greeting in message_lower for greeting in ['hello', 'hi', 'hey', 'greetings']):
            return f"Hello {user_name}! Welcome to ToggleTalk Server!"
        
        # Help responses
        if any(help_word in message_lower for help_word in ['help', 'what can you do', 'commands']):
            return f"Hello {user_name}! I can help you control your home appliances and security system! Try commands like 'Turn on the light', 'Turn off the AC', 'Initialize security system', or 'Terminate security system'."
        
        # Status queries
        if any(status_word in message_lower for status_word in ['status', 'state', 'how is']):
            status_message = f"🏠 {user_name}, Current Device Status:\n"
            for device, info in self.home_devices.items():
                device_name = self.get_device_user_name(device)
                status_message += f"• {device_name}: {info['status'].title()}\n"
            
            # Add security system status
            security_status = "ACTIVE" if self.security_system_active else "INACTIVE"
            status_message += f"• Home Security System: {security_status}\n"
            return status_message
        
        # Default response for unrecognized commands
        return f"Sorry {user_name}, I didn't understand that command. Try saying 'Turn on the light' or 'Turn off the AC'."
    
    def log_event(self, event_type, message, user_name=None, user_id=None):
        """Log events to the events log file"""
        timestamp = datetime.now().isoformat()
        log_entry = {
            'timestamp': timestamp,
            'event_type': event_type,
            'message': message,
            'user_name': user_name,
            'user_id': user_id
        }
        
        try:
            # Append to the events log file
            with open(EVENTS_LOG_FILE, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
            logger.info(f"Event logged: {event_type} - {message}")
            # Update console with event (only for important events)
            if event_type in ["user_joined", "device_control", "scheduled_task_executed"]:
                update_status_line(f"Event: {event_type} - {message[:50]}{'...' if len(message) > 50 else ''}")
        except Exception as e:
            logger.error(f"Error logging event: {e}")
            # Also log the error to console
            update_status_line(f"Log Error: {e}")
    
    def get_log_details(self):
        """Retrieve and format log details for display"""
        try:
            log_entries = []
            if os.path.exists(EVENTS_LOG_FILE):
                with open(EVENTS_LOG_FILE, 'r') as f:
                    lines = f.readlines()
                    # Parse all log entries
                    for line in lines:
                        try:
                            entry = json.loads(line.strip())
                            log_entries.append(entry)
                        except json.JSONDecodeError:
                            # Skip invalid lines
                            continue
            
            # Sort by timestamp (newest first)
            log_entries.sort(key=lambda x: x['timestamp'], reverse=True)
            
            # Format the log details
            if not log_entries:
                return "No log entries found."
            
            # Create a formatted log display
            log_lines = ["=" * 60]
            log_lines.append("DETAILED SERVER LOGS")
            log_lines.append("=" * 60)
            log_lines.append(f"Total Events: {len(log_entries)}")
            log_lines.append("")
            
            # Show last 20 events with detailed formatting
            for i, entry in enumerate(log_entries[:20]):
                timestamp = entry.get('timestamp', 'Unknown')
                event_type = entry.get('event_type', 'Unknown')
                message = entry.get('message', 'No message')
                user_name = entry.get('user_name', 'Unknown')
                user_id = entry.get('user_id', 'Unknown')
                
                # Format timestamp for better readability
                try:
                    dt = datetime.fromisoformat(timestamp)
                    formatted_time = dt.strftime("%Y-%m-%d %H:%M:%S")
                except:
                    formatted_time = timestamp
                
                log_lines.append(f"[{i+1:2d}] {formatted_time}")
                log_lines.append(f"     Type: {event_type}")
                log_lines.append(f"     User: {user_name} (ID: {user_id})")
                log_lines.append(f"     Message: {message}")
                log_lines.append("")
            
            log_lines.append("=" * 60)
            return "\n".join(log_lines)
        
        except Exception as e:
            logger.error(f"Error retrieving log details: {e}")
            return f"Error retrieving log details: {e}"
    
    def load_user_preferences(self):
        """Load user preferences from file with retry mechanism"""
        if os.path.exists(USER_PREFERENCES_FILE):
            for attempt in range(3):  # Try up to 3 times
                try:
                    with open(USER_PREFERENCES_FILE, 'r') as f:
                        return json.load(f)
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error loading user preferences (attempt {attempt + 1}): {e}")
                    # Try to recover by creating a backup and starting fresh
                    if attempt < 2:  # Don't do this on the last attempt
                        backup_file = f"{USER_PREFERENCES_FILE}.backup.{int(time.time())}"
                        try:
                            import shutil
                            shutil.copy2(USER_PREFERENCES_FILE, backup_file)
                            logger.info(f"Created backup of corrupted file: {backup_file}")
                        except Exception as backup_error:
                            logger.error(f"Failed to create backup: {backup_error}")
                        time.sleep(1)  # Wait before retry
                    else:
                        logger.error("Failed to load user preferences after 3 attempts")
                        return {}
                except Exception as e:
                    logger.error(f"Error loading user preferences (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        time.sleep(1)  # Wait before retry
                    else:
                        logger.error("Failed to load user preferences after 3 attempts")
                        return {}
        return {}
    
    def save_user_preferences(self):
        """Save user preferences to file with retry mechanism"""
        for attempt in range(3):  # Try up to 3 times
            try:
                with open(USER_PREFERENCES_FILE, 'w') as f:
                    json.dump(self.user_preferences, f, indent=2)
                return  # Success
            except Exception as e:
                logger.error(f"Error saving user preferences (attempt {attempt + 1}): {e}")
                if attempt < 2:
                    time.sleep(1)  # Wait before retry
                else:
                    logger.error("Failed to save user preferences after 3 attempts")
    
    def load_chat_ids(self):
        """Load chat IDs from file with retry mechanism"""
        if os.path.exists(CHAT_IDS_FILE):
            for attempt in range(3):  # Try up to 3 times
                try:
                    with open(CHAT_IDS_FILE, 'r') as f:
                        data = json.load(f)
                        # Ensure we return a set
                        if isinstance(data, list):
                            return set(data)
                        elif isinstance(data, set):
                            return data
                        else:
                            return set(data) if data else set()
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error loading chat IDs (attempt {attempt + 1}): {e}")
                    # Try to recover by creating a backup and starting fresh
                    if attempt < 2:
                        backup_file = f"{CHAT_IDS_FILE}.backup.{int(time.time())}"
                        try:
                            import shutil
                            shutil.copy2(CHAT_IDS_FILE, backup_file)
                            logger.info(f"Created backup of corrupted file: {backup_file}")
                        except Exception as backup_error:
                            logger.error(f"Failed to create backup: {backup_error}")
                        time.sleep(1)
                    else:
                        logger.error("Failed to load chat IDs after 3 attempts")
                        return set()
                except Exception as e:
                    logger.error(f"Error loading chat IDs (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        time.sleep(1)
                    else:
                        logger.error("Failed to load chat IDs after 3 attempts")
                        return set()
        return set()
    
    def save_chat_ids(self):
        """Save chat IDs to file with retry mechanism"""
        for attempt in range(3):  # Try up to 3 times
            try:
                with open(CHAT_IDS_FILE, 'w') as f:
                    json.dump(list(self.chat_ids), f, indent=2)
                return  # Success
            except Exception as e:
                logger.error(f"Error saving chat IDs (attempt {attempt + 1}): {e}")
                if attempt < 2:
                    time.sleep(1)
                else:
                    logger.error("Failed to save chat IDs after 3 attempts")
    
    def load_scheduled_tasks(self):
        """Load scheduled tasks from file with retry mechanism"""
        if os.path.exists(SCHEDULED_TASKS_FILE):
            for attempt in range(3):  # Try up to 3 times
                try:
                    with open(SCHEDULED_TASKS_FILE, 'r') as f:
                        tasks = json.load(f)
                        # Convert string timestamps back to datetime objects
                        validated_tasks = []
                        for task in tasks:
                            try:
                                if 'scheduled_time' in task:
                                    task['scheduled_time'] = datetime.fromisoformat(task['scheduled_time'])
                                validated_tasks.append(task)
                            except Exception as e:
                                logger.error(f"Error validating scheduled task: {e}")
                                # Skip invalid tasks
                                continue
                        return validated_tasks
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error loading scheduled tasks (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        backup_file = f"{SCHEDULED_TASKS_FILE}.backup.{int(time.time())}"
                        try:
                            import shutil
                            shutil.copy2(SCHEDULED_TASKS_FILE, backup_file)
                            logger.info(f"Created backup of corrupted file: {backup_file}")
                        except Exception as backup_error:
                            logger.error(f"Failed to create backup: {backup_error}")
                        time.sleep(1)
                    else:
                        logger.error("Failed to load scheduled tasks after 3 attempts")
                        return []
                except Exception as e:
                    logger.error(f"Error loading scheduled tasks (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        time.sleep(1)
                    else:
                        logger.error("Failed to load scheduled tasks after 3 attempts")
                        return []
        return []
    
    def save_scheduled_tasks(self):
        """Save scheduled tasks to file with retry mechanism"""
        for attempt in range(3):  # Try up to 3 times
            try:
                # Convert datetime objects to strings for JSON serialization
                tasks_to_save = []
                for task in self.scheduled_tasks:
                    task_copy = task.copy()
                    if 'scheduled_time' in task_copy and isinstance(task_copy['scheduled_time'], datetime):
                        task_copy['scheduled_time'] = task_copy['scheduled_time'].isoformat()
                    tasks_to_save.append(task_copy)
                
                with open(SCHEDULED_TASKS_FILE, 'w') as f:
                    json.dump(tasks_to_save, f, indent=2)
                return  # Success
            except Exception as e:
                logger.error(f"Error saving scheduled tasks (attempt {attempt + 1}): {e}")
                if attempt < 2:
                    time.sleep(1)
                else:
                    logger.error("Failed to save scheduled tasks after 3 attempts")
    
    def load_pending_notifications(self):
        """Load pending notifications from file with retry mechanism"""
        if os.path.exists(PENDING_NOTIFICATIONS_FILE):
            for attempt in range(3):  # Try up to 3 times
                try:
                    with open(PENDING_NOTIFICATIONS_FILE, 'r') as f:
                        data = json.load(f)
                        # Ensure we return a list
                        return data if isinstance(data, list) else []
                except json.JSONDecodeError as e:
                    logger.error(f"JSON decode error loading pending notifications (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        backup_file = f"{PENDING_NOTIFICATIONS_FILE}.backup.{int(time.time())}"
                        try:
                            import shutil
                            shutil.copy2(PENDING_NOTIFICATIONS_FILE, backup_file)
                            logger.info(f"Created backup of corrupted file: {backup_file}")
                        except Exception as backup_error:
                            logger.error(f"Failed to create backup: {backup_error}")
                        time.sleep(1)
                    else:
                        logger.error("Failed to load pending notifications after 3 attempts")
                        return []
                except Exception as e:
                    logger.error(f"Error loading pending notifications (attempt {attempt + 1}): {e}")
                    if attempt < 2:
                        time.sleep(1)
                    else:
                        logger.error("Failed to load pending notifications after 3 attempts")
                        return []
        return []
    
    def save_pending_notifications(self):
        """Save pending notifications to file with retry mechanism"""
        for attempt in range(3):  # Try up to 3 times
            try:
                with open(PENDING_NOTIFICATIONS_FILE, 'w') as f:
                    json.dump(self.pending_notifications, f, indent=2)
                return  # Success
            except Exception as e:
                logger.error(f"Error saving pending notifications (attempt {attempt + 1}): {e}")
                if attempt < 2:
                    time.sleep(1)
                else:
                    logger.error("Failed to save pending notifications after 3 attempts")
    
    def add_pending_notification(self, notification_text, timestamp=None):
        """Add a notification to the pending notifications list"""
        if timestamp is None:
            timestamp = datetime.now().isoformat()
        
        # Generate a unique ID based on timestamp and text to ensure uniqueness
        # even if notifications are cleared
        import hashlib
        notification_hash = hashlib.md5(f"{notification_text}{timestamp}".encode()).hexdigest()
        unique_id = int(notification_hash[:8], 16)  # Take first 8 hex chars and convert to int
        
        notification = {
            'text': notification_text,
            'timestamp': timestamp,
            'id': unique_id
        }
        
        self.pending_notifications.append(notification)
        
        # Limit the number of pending notifications to prevent file from growing indefinitely
        # Keep only the most recent 100 notifications
        if len(self.pending_notifications) > 100:
            self.pending_notifications = self.pending_notifications[-100:]
        
        self.save_pending_notifications()
        logger.info(f"Added pending notification: {notification_text}")
        logger.info(f"Total pending notifications: {len(self.pending_notifications)}")
    
    def get_pending_notifications(self):
        """Get all pending notifications"""
        # Reload notifications from file to ensure we have the latest
        self.pending_notifications = self.load_pending_notifications()
        return self.pending_notifications
    
    def clear_pending_notifications(self):
        """Clear all pending notifications"""
        self.pending_notifications.clear()
        self.save_pending_notifications()
        logger.info("Cleared all pending notifications")
    
    def add_chat_id(self, chat_id):
        """Add a chat ID to the list"""
        if chat_id not in self.chat_ids:
            self.chat_ids.add(chat_id)
            self.save_chat_ids()
            logger.info(f"Added chat ID: {chat_id}")
    
    def start_scheduler(self):
        """Start the scheduler thread for handling scheduled tasks"""
        if not self.scheduler_running:
            self.scheduler_running = True
            self.scheduler_thread = threading.Thread(target=self._scheduler_loop, daemon=True)
            self.scheduler_thread.start()
            logger.info("Scheduler thread started")
    
    def stop_scheduler(self):
        """Stop the scheduler thread"""
        self.scheduler_running = False
        if self.scheduler_thread and self.scheduler_thread.is_alive():
            self.scheduler_thread.join(timeout=5)  # Add timeout to prevent blocking
            logger.info("Scheduler thread stopped")
    
    def _scheduler_loop(self):
        """Main loop for the scheduler thread"""
        while self.scheduler_running:
            try:
                current_time = datetime.now()
                # Check for tasks that need to be executed
                tasks_to_remove = []
                for task in self.scheduled_tasks:
                    if task['scheduled_time'] <= current_time:
                        # Execute the scheduled task
                        self._execute_scheduled_task(task)
                        tasks_to_remove.append(task)
                
                # Remove executed tasks
                for task in tasks_to_remove:
                    if task in self.scheduled_tasks:  # Check if task still exists
                        self.scheduled_tasks.remove(task)
                
                if tasks_to_remove:
                    self.save_scheduled_tasks()
                
                # Check security system for suspicious activity if active
                if self.security_system_active:
                    self.check_security_system()
                
                # Update status with scheduler info
                if self.scheduled_tasks:
                    next_task = min(self.scheduled_tasks, key=lambda x: x['scheduled_time'])
                    time_diff = next_task['scheduled_time'] - current_time
                    update_status_line(f"Scheduler: {len(self.scheduled_tasks)} tasks, next in {time_diff.seconds//60}m {time_diff.seconds%60}s")
                elif self.security_system_active:
                    update_status_line("Scheduler: Security system active, monitoring for activity")
                else:
                    update_status_line("Scheduler: No scheduled tasks")
                
                # Sleep for a reasonable time to avoid busy waiting
                # But don't sleep too long to ensure responsiveness
                time.sleep(2)  # Increased from 1 to 2 seconds
            except Exception as e:
                logger.error(f"Error in scheduler loop: {e}")
                update_status_line(f"Scheduler error: {e}")
                time.sleep(5)  # Sleep longer on error to avoid spamming logs
    
    def _execute_scheduled_task(self, task):
        """Execute a scheduled task"""
        try:
            device_name = task['device']
            action = task['action']
            user_name = task.get('user_name', 'System')
            
            # Control the device
            success = self.control_gpio_device(device_name, action)
            
            if success:
                # Update device status
                if device_name in self.home_devices:
                    self.home_devices[device_name]['status'] = action
                
                # Create notification message
                device_display_name = self.get_device_user_name(device_name)
                action_display = "ON" if action == "on" else "OFF"
                # Format scheduled notification according to specification
                current_time = datetime.now().strftime("%H:%M:%S")
                notification_msg = f"[NOTIFICATION] 🔔 {user_name}: {device_display_name} turned {action_display} at {current_time}"
                
                # Add notification to queue to be sent by main thread
                notification_queue.put(notification_msg)
                logger.info(f"Executed scheduled task: {notification_msg}")
                update_status_line(f"Executed: {device_display_name} turned {action_display}")
                
                # Track notification in history
                notification_entry = {
                    'type': 'notification',
                    'text': notification_msg[:50] + "..." if len(notification_msg) > 50 else notification_msg,
                    'timestamp': datetime.now(),
                    'user': 'Scheduler'
                }
                message_history.append(notification_entry)
                
                # Log the event
                self.log_event("scheduled_task_executed", notification_msg, user_name)
            else:
                logger.error(f"Failed to execute scheduled task for {device_name}")
                update_status_line(f"Failed to execute task for {device_name}")
        except Exception as e:
            logger.error(f"Error executing scheduled task: {e}")
            update_status_line(f"Task execution error: {e}")
    
    def process_home_automation(self, text: str, user_name: str = "User") -> str:
        """Process home automation commands for the three appliances only"""
        text = text.lower()
        logger.info(f"Processing home automation command: {text} from {user_name}")
        
        # Check for scheduled commands
        if 'schedule' in text or 'timer' in text:
            return self._process_scheduled_command(text, user_name)
        
        # Washing Machine control (check this first to avoid conflicts with 'ac')
        if 'washing machine' in text:
            if 'turn on' in text or 'switch on' in text:
                self.home_devices['washing_machine']['status'] = 'on'
                success = self.control_gpio_device('washing_machine', 'on')
                if success:
                    # Log the event
                    self.log_event("device_control", "Washing Machine turned ON", user_name)
                    return "✅ Washing Machine turned ON."
                else:
                    return "⚠️ Error turning on Washing Machine. Please try again."
            elif 'turn off' in text or 'switch off' in text:
                self.home_devices['washing_machine']['status'] = 'off'
                success = self.control_gpio_device('washing_machine', 'off')
                if success:
                    # Log the event
                    self.log_event("device_control", "Washing Machine turned OFF", user_name)
                    return "✅ Washing Machine turned OFF."
                else:
                    return "⚠️ Error turning off Washing Machine. Please try again."
            else:
                status = self.home_devices['washing_machine']['status']
                return f"🧺 Washing Machine is currently {status}."
        
        # Air Conditioner control (be more specific to avoid conflicts)
        elif 'ac ' in text or ' air condition' in text or text.startswith('ac') or text == 'ac' or 'ac' in text.split():
            if 'turn on' in text or 'switch on' in text:
                self.home_devices['ac']['status'] = 'on'
                success = self.control_gpio_device('ac', 'on')
                if success:
                    # Log the event
                    self.log_event("device_control", "Air Conditioner turned ON", user_name)
                    return "✅ Air Conditioner turned ON."
                else:
                    return "⚠️ Error turning on Air Conditioner. Please try again."
            elif 'turn off' in text or 'switch off' in text:
                self.home_devices['ac']['status'] = 'off'
                success = self.control_gpio_device('ac', 'off')
                if success:
                    # Log the event
                    self.log_event("device_control", "Air Conditioner turned OFF", user_name)
                    return "✅ Air Conditioner turned OFF."
                else:
                    return "⚠️ Error turning off Air Conditioner. Please try again."
            else:
                status = self.home_devices['ac']['status']
                return f"❄️ Air Conditioner is currently {status}."
        
        # Light control
        elif 'light' in text:
            if 'turn on' in text or 'switch on' in text:
                self.home_devices['light']['status'] = 'on'
                success = self.control_gpio_device('light', 'on')
                if success:
                    # Log the event
                    self.log_event("device_control", "Light turned ON", user_name)
                    return "✅ Light turned ON."
                else:
                    return "⚠️ Error turning on light. Please try again."
            elif 'turn off' in text or 'switch off' in text:
                self.home_devices['light']['status'] = 'off'
                success = self.control_gpio_device('light', 'off')
                if success:
                    # Log the event
                    self.log_event("device_control", "Light turned OFF", user_name)
                    return "✅ Light turned OFF."
                else:
                    return "⚠️ Error turning off light. Please try again."
            else:
                status = self.home_devices['light']['status']
                return f"💡 Light is currently {status}."
        
        # Home Security System control
        elif 'security' in text or 'laser' in text or 'intruder' in text:
            if 'initialize' in text or 'start' in text or 'activate' in text or 'arm' in text:
                result = self.initialize_security_system(user_name)
                # Log the event
                self.log_event("security_system", "Security system initialized", user_name)
                return result
            elif 'terminate' in text or 'stop' in text or 'deactivate' in text or 'disarm' in text:
                result = self.terminate_security_system(user_name)
                # Log the event
                self.log_event("security_system", "Security system terminated", user_name)
                return result
            else:
                status = "ACTIVE" if self.security_system_active else "INACTIVE"
                return f"🛡️ Home Security System is currently {status}."
        
        return ""  # Not a home automation command
    
    def _process_scheduled_command(self, text: str, user_name: str) -> str:
        """Process scheduled home automation commands"""
        # Extract time from text (e.g., "in 5 minutes", "at 3:30 PM")
        time_match = re.search(r'in\s+(\d+)\s+(second|seconds|minute|minutes|hour|hours)', text)
        if time_match:
            amount = int(time_match.group(1))
            unit = time_match.group(2)
            
            # Calculate scheduled time
            if 'second' in unit:
                scheduled_time = datetime.now() + timedelta(seconds=amount)
            elif 'minute' in unit:
                scheduled_time = datetime.now() + timedelta(minutes=amount)
            elif 'hour' in unit:
                scheduled_time = datetime.now() + timedelta(hours=amount)
            else:
                return "⚠️ Unsupported time unit. Please use seconds, minutes or hours."
            
            # Determine device and action
            device_name = None
            action = None
            
            if 'light' in text:
                device_name = 'light'
            elif 'ac' in text or 'air condition' in text:
                device_name = 'ac'
            elif 'washing machine' in text:
                device_name = 'washing_machine'
            
            if 'turn on' in text or 'switch on' in text:
                action = 'on'
            elif 'turn off' in text or 'switch off' in text:
                action = 'off'
            
            if device_name and action:
                # Add task to scheduled tasks
                task = {
                    'device': device_name,
                    'action': action,
                    'scheduled_time': scheduled_time,
                    'user_name': user_name
                }
                self.scheduled_tasks.append(task)
                self.save_scheduled_tasks()
                
                device_display_name = self.get_device_user_name(device_name)
                action_display = "ON" if action == "on" else "OFF"
                time_display = scheduled_time.strftime("%H:%M:%S")
                
                # Log the event
                self.log_event("scheduled_task_created", f"Scheduled {device_display_name} to turn {action_display} at {time_display}", user_name)
                
                return f"⏰ Scheduled {device_display_name} to turn {action_display} at {time_display}."
            else:
                return "⚠️ Could not determine device or action for scheduling."
        
        return "⚠️ Unsupported schedule format. Try: 'Schedule light on in 30 seconds' or 'Schedule light on in 5 minutes' or 'Schedule ac off in 1 hour'"

    def get_device_user_name(self, device_name):
        """Get user-friendly name for devices"""
        device_names = {
            'light': 'Light',
            'ac': 'Air Conditioner',
            'washing_machine': 'Washing Machine'
        }
        return device_names.get(device_name, device_name.replace('_', ' ').title())
    
    def initialize_security_system(self, user_name):
        """Initialize the home security system with laser module, LDR sensor, and buzzer"""
        if not GPIO_AVAILABLE or GPIO is None:
            return "⚠️ Security system requires Raspberry Pi with GPIO support. Running in simulation mode."
        
        try:
            # Turn on the laser module
            GPIO.setup(GPIO_PINS['laser_module'], GPIO.OUT)
            GPIO.output(GPIO_PINS['laser_module'], GPIO.HIGH)  # Turn on laser
            
            # Setup LDR sensor as input
            GPIO.setup(GPIO_PINS['ldr_sensor'], GPIO.IN)
            
            # Setup buzzer as output
            GPIO.setup(GPIO_PINS['buzzer'], GPIO.OUT)
            GPIO.output(GPIO_PINS['buzzer'], GPIO.LOW)  # Turn off buzzer initially
            
            # Update security system state
            self.security_system_active = True
            
            # Log the event
            self.log_event("security_system_activated", f"Home security system activated by {user_name}", user_name)
            
            # Send notification to all users
            current_time = datetime.now().strftime("%H:%M:%S")
            notification_msg = f"[NOTIFICATION] 🛡️ {user_name}: Home Security System INITIALIZED at {current_time}"
            self.add_pending_notification(notification_msg)
            
            return "✅ Home Security System INITIALIZED. Laser module activated and monitoring for intruders."
        except Exception as e:
            error_msg = f"⚠️ Error initializing security system: {e}"
            logger.error(error_msg)
            return error_msg
    
    def terminate_security_system(self, user_name):
        """Terminate the home security system"""
        if not GPIO_AVAILABLE or GPIO is None:
            return "⚠️ Security system requires Raspberry Pi with GPIO support. Running in simulation mode."
        
        try:
            # Turn off the laser module
            if 'laser_module' in GPIO_PINS:
                GPIO.setup(GPIO_PINS['laser_module'], GPIO.OUT)
                GPIO.output(GPIO_PINS['laser_module'], GPIO.LOW)  # Turn off laser
            
            # Turn off buzzer if it's on
            if 'buzzer' in GPIO_PINS:
                GPIO.setup(GPIO_PINS['buzzer'], GPIO.OUT)
                GPIO.output(GPIO_PINS['buzzer'], GPIO.LOW)  # Turn off buzzer
            
            # Update security system state
            self.security_system_active = False
            
            # Log the event
            self.log_event("security_system_deactivated", f"Home security system deactivated by {user_name}", user_name)
            
            # Send notification to all users
            current_time = datetime.now().strftime("%H:%M:%S")
            notification_msg = f"[NOTIFICATION] 🛡️ {user_name}: Home Security System TERMINATED at {current_time}"
            self.add_pending_notification(notification_msg)
            
            return "✅ Home Security System TERMINATED. All modules deactivated."
        except Exception as e:
            error_msg = f"⚠️ Error terminating security system: {e}"
            logger.error(error_msg)
            return error_msg

    def control_gpio_device(self, device_name, action):
        """Control GPIO devices (relays) connected to Raspberry Pi with enhanced error handling"""
        logger.info(f"Attempting to control device: {device_name}, action: {action}")
        
        # Track GPIO operation in message history
        gpio_entry = {
            'type': 'notification',
            'text': f"GPIO {action} {device_name}",
            'timestamp': datetime.now(),
            'user': 'GPIO'
        }
        message_history.append(gpio_entry)
        
        if not GPIO_AVAILABLE or GPIO is None:
            # Simulation mode - just update the device status
            print(f"Simulating {action} {device_name}")
            logger.info(f"Simulating {action} {device_name} (GPIO not available)")
            update_status_line(f"Simulating: {action} {device_name}")
            add_console_line(f"🔄 Simulated: {action} {device_name}")
            return True
        
        # Validate inputs
        if device_name not in GPIO_PINS:
            error_msg = f"Device {device_name} not configured for GPIO control"
            print(error_msg)
            update_status_line(f"GPIO Error: {device_name} not configured")
            add_console_line(f"❌ GPIO Error: {device_name} not configured")
            return False
            
        if action not in ['on', 'off']:
            error_msg = f"Invalid action {action} for GPIO control"
            print(error_msg)
            update_status_line(f"GPIO Error: Invalid action {action}")
            add_console_line(f"❌ GPIO Error: Invalid action {action}")
            return False
        
        # Retry mechanism for GPIO operations
        max_retries = 3
        for attempt in range(max_retries):
            try:
                pin = GPIO_PINS[device_name]
                if action == 'on':
                    GPIO.output(pin, GPIO.LOW)  # Turn on relay (assuming active low)
                    print(f"GPIO Pin {pin} for {device_name} turned ON")
                    update_status_line(f"GPIO: Pin {pin} ({device_name}) turned ON")
                    add_console_line(f"🔌 GPIO: Pin {pin} ({device_name}) turned ON")
                    return True
                elif action == 'off':
                    GPIO.output(pin, GPIO.HIGH)  # Turn off relay (assuming active low)
                    print(f"GPIO Pin {pin} for {device_name} turned OFF")
                    update_status_line(f"GPIO: Pin {pin} ({device_name}) turned OFF")
                    add_console_line(f"🔌 GPIO: Pin {pin} ({device_name}) turned OFF")
                    return True
            except Exception as e:
                error_msg = f"Error controlling GPIO device {device_name} (attempt {attempt + 1}/{max_retries}): {e}"
                print(error_msg)
                update_status_line(f"GPIO Error: {device_name} (attempt {attempt + 1})")
                add_console_line(f"❌ GPIO Error: {device_name} - {e}")
                
                if attempt < max_retries - 1:
                    time.sleep(0.5)  # Wait before retry
                else:
                    # Final attempt failed
                    return False
        
        # This should never be reached, but just in case
        return False
    
    def check_security_system(self):
        """Check for suspicious activity from LDR sensor when security system is active"""
        if not self.security_system_active or not GPIO_AVAILABLE or GPIO is None:
            return
        
        try:
            # Check if LDR sensor detects a change (indicating possible intruder)
            # In a real implementation, this would be more sophisticated
            ldr_value = GPIO.input(GPIO_PINS['ldr_sensor'])
            
            # If LDR detects a change (logic depends on how the sensor is connected)
            # For this example, we'll assume HIGH means suspicious activity
            if ldr_value == GPIO.HIGH:
                # Activate buzzer
                GPIO.output(GPIO_PINS['buzzer'], GPIO.HIGH)
                
                # Send notification about suspicious activity
                current_time = datetime.now().strftime("%H:%M:%S")
                notification_msg = f"[ALERT] 🚨 Suspicious activity detected by Home Security System at {current_time}"
                self.add_pending_notification(notification_msg)
                
                logger.info("Suspicious activity detected by security system")
                add_console_line(f"🚨 Security Alert: Suspicious activity detected at {current_time}")
                update_status_line("Security Alert: Suspicious activity detected")
                
                # Keep buzzer on for 5 seconds
                time.sleep(5)
                GPIO.output(GPIO_PINS['buzzer'], GPIO.LOW)
        except Exception as e:
            logger.error(f"Error checking security system: {e}")

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize the ToggleTalk server
server = ToggleTalkFlaskServer()

# API Routes
@app.route('/api/send_message', methods=['POST'])
def send_message():
    """API endpoint for mobile app to send messages"""
    global total_messages_processed, total_processing_time
    
    # Record start time for latency tracking
    message_start_time = time.time()
    
    try:
        # Get JSON data from request
        data = request.get_json()
        if not data or 'message' not in data:
            return jsonify({'error': 'Message is required'}), 400
        
        message = data['message']
        user_name = data.get('user_name', 'MobileUser')
        user_id = data.get('user_id', 0)  # Add user ID for better tracking
        
        # Validate inputs
        if not isinstance(message, str) or not isinstance(user_name, str):
            return jsonify({'error': 'Invalid message or user_name format'}), 400
        
        # Limit message length
        if len(message) > 1000:
            message = message[:1000] + "..."
        
        # Track message in history for visualization
        message_entry = {
            'type': 'user',
            'text': message[:50] + "..." if len(message) > 50 else message,
            'timestamp': datetime.now(),
            'user': user_name,
            'user_id': user_id
        }
        message_history.append(message_entry)
        
        # Log that we received the message
        logger.info(f"Received message: {message} from {user_name} (ID: {user_id})")
        
        # Register the chat ID for notification broadcasting
        server.add_chat_id(user_id)
        
        # Process the message through the server
        try:
            response = server.generate_response(message, user_id, user_name)
            logger.info(f"Generated response: {response}")
        except Exception as e:
            logger.error(f"Error in generate_response: {e}")
            response = f"Sorry {user_name}, I encountered an error processing your request."
        
        # Track bot response in history
        response_entry = {
            'type': 'bot',
            'text': response[:50] + "..." if len(response) > 50 else response,
            'timestamp': datetime.now(),
            'user': user_name,
            'user_id': user_id
        }
        message_history.append(response_entry)
        
        # Update message processing statistics
        processing_time = time.time() - message_start_time
        global total_messages_processed, total_processing_time
        total_messages_processed += 1
        total_processing_time += processing_time
        
        # Add processing time to the message entries
        message_entry['processing_time'] = processing_time
        response_entry['processing_time'] = processing_time
        
        # Update console with message info
        add_console_line(f"📱 {user_name} (ID: {user_id}): {message}")
        add_console_line(f"🤖 Server to {user_name}: {response}")
        update_status_line(f"API Msg: {user_name} -> {response[:30]}{'...' if len(response) > 30 else ''}")
        
        # If this was a device control command, send notification to all users
        message_lower = message.lower()
        if any(keyword in message_lower for keyword in ['turn on', 'turn off', 'switch on', 'switch off', 'schedule']):
            device_name = None
            action = None
            
            # Determine which device and action
            if 'light' in message_lower:
                device_name = 'light'
            elif 'ac' in message_lower or 'air condition' in message_lower:
                device_name = 'ac'
            elif 'washing machine' in message_lower:
                device_name = 'washing_machine'
            
            if device_name:
                if 'schedule' in message_lower:
                    # For scheduled tasks, we don't send immediate notifications
                    # The notification will be sent when the task is executed
                    pass
                else:
                    action = 'ON' if any(keyword in message_lower for keyword in ['turn on', 'switch on']) else 'OFF'
                    device_display_name = server.get_device_user_name(device_name)
                    
                    # Format the notification message with timestamp according to specification
                    current_time = datetime.now().strftime("%H:%M:%S")
                    notification_msg = f"[NOTIFICATION] 🔔 {user_name}: {message} at {current_time}"
                    
                    try:
                        # Add to pending notifications for client retrieval
                        server.add_pending_notification(notification_msg)
                        
                        # Track notification in history
                        notification_entry = {
                            'type': 'notification',
                            'text': notification_msg[:50] + "..." if len(notification_msg) > 50 else notification_msg,
                            'timestamp': datetime.now(),
                            'user': user_name,  # Use actual user name instead of 'System'
                            'user_id': user_id
                        }
                        message_history.append(notification_entry)
                        
                        # Also send notification to all connected applications
                        # Add notification to queue to be sent by main thread
                        notification_queue.put(notification_msg)
                    except Exception as e:
                        logger.error(f"Error handling notification: {e}")
                        # Continue processing even if notification fails
        elif any(keyword in message_lower for keyword in ['initialize', 'start', 'activate', 'arm', 'terminate', 'stop', 'deactivate', 'disarm']):
            # For security system commands, also send notifications to all users
            current_time = datetime.now().strftime("%H:%M:%S")
            notification_msg = f"[NOTIFICATION] 🔔 {user_name}: {message} at {current_time}"
            
            try:
                # Add to pending notifications for client retrieval
                server.add_pending_notification(notification_msg)
                
                # Track notification in history
                notification_entry = {
                    'type': 'notification',
                    'text': notification_msg[:50] + "..." if len(notification_msg) > 50 else notification_msg,
                    'timestamp': datetime.now(),
                    'user': user_name,
                    'user_id': user_id
                }
                message_history.append(notification_entry)
                
                # Also send notification to all connected applications
                notification_queue.put(notification_msg)
            except Exception as e:
                logger.error(f"Error handling security system notification: {e}")
        
        return jsonify({
            'status': 'success',
            'response': response,
            'user_name': user_name,
            'user_id': user_id
        })
    except Exception as e:
        logger.error(f"Error processing API message: {e}")
        update_status_line(f"API Error: {e}")
        # Return a more user-friendly error message
        return jsonify({'error': 'Internal server error occurred'}), 500

@app.route('/api/get_notifications', methods=['GET'])
def get_notifications():
    """API endpoint for mobile app to get pending notifications"""
    try:
        notifications = server.get_pending_notifications()
        # DO NOT clear the notifications after sending them
        # Each client should get all pending notifications
        # The client will manage its own notification state
        return jsonify({
            'status': 'success',
            'notifications': notifications,
            'count': len(notifications)
        })
    except Exception as e:
        logger.error(f"Error getting notifications: {e}")
        return jsonify({'error': 'Failed to retrieve notifications'}), 500

@app.route('/api/get_events', methods=['GET'])
def get_events():
    """API endpoint for mobile app to get recent events"""
    try:
        events = []
        if os.path.exists(EVENTS_LOG_FILE):
            # Read the last 20 events (or fewer if there aren't that many)
            with open(EVENTS_LOG_FILE, 'r') as f:
                lines = f.readlines()
                # Get the last 20 lines (events)
                recent_lines = lines[-20:] if len(lines) > 20 else lines
                for line in recent_lines:
                    try:
                        event = json.loads(line.strip())
                        events.append(event)
                    except json.JSONDecodeError:
                        # Skip invalid lines
                        continue
        
        return jsonify({
            'status': 'success',
            'events': events,
            'count': len(events)
        })
    except Exception as e:
        logger.error(f"Error getting events: {e}")
        return jsonify({'error': 'Failed to retrieve events'}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """Enhanced health check endpoint"""
    try:
        # Check file system access
        file_system_status = "healthy"
        try:
            # Test write access to a temporary file
            test_file = "temp_health_check.txt"
            with open(test_file, 'w') as f:
                f.write("health check")
            os.remove(test_file)
        except Exception as e:
            file_system_status = f"unhealthy: {str(e)}"
        
        return jsonify({
            'status': 'healthy',
            'timestamp': datetime.now().isoformat(),
            'file_system_status': file_system_status,
            'uptime': str(datetime.now() - start_time),
            'messages_processed': total_messages_processed,
            'avg_processing_time': total_processing_time / max(1, total_messages_processed)
        })
    except Exception as e:
        logger.error(f"Error in health check: {e}")
        return jsonify({'status': 'unhealthy', 'error': str(e)}), 500

@app.errorhandler(413)
def too_large(e):
    return jsonify({'error': 'Request too large'}), 413

@app.errorhandler(Exception)
def handle_exception(e):
    logger.error(f"Unhandled exception in Flask app: {e}")
    return jsonify({'error': 'Internal server error'}), 500

def cleanup_gpio():
    """Clean up GPIO settings on exit"""
    if GPIO_AVAILABLE and GPIO is not None:
        try:
            GPIO.cleanup()
            print("GPIO cleanup completed")
        except Exception as e:
            print(f"Error during GPIO cleanup: {e}")

def main():
    """Run the Flask server"""
    # Clear console and show header
    os.system('cls' if os.name == 'nt' else 'clear')
    print("ToggleTalk Flask Server")
    print("=" * 50)
    add_console_line("Initializing ToggleTalk Flask Server...")
    logger.info("Initializing ToggleTalk Flask Server...")
    
    try:
        # Start the notification processing thread
        def process_notifications():
            notification_failures = 0
            max_notification_failures = 10
            
            while notification_failures < max_notification_failures:
                try:
                    # Check for notifications in queue
                    if not notification_queue.empty():
                        notification_msg = notification_queue.get_nowait()
                        # In a real implementation, we would send this to connected clients
                        # For now, we'll just log it
                        logger.info(f"Notification ready for broadcast: {notification_msg}")
                        notification_failures = 0  # Reset failure counter on success
                    time.sleep(1)  # Check every second
                except queue.Empty:
                    time.sleep(1)  # No notifications, sleep and check again
                except Exception as e:
                    notification_failures += 1
                    logger.error(f"Error processing notification ({notification_failures}/{max_notification_failures}): {e}")
                    update_status_line(f"Notification error: {e}")
                    time.sleep(5)  # Sleep longer on error
                    
                    # If we've had too many failures, restart the notification processor
                    if notification_failures >= max_notification_failures:
                        logger.error("Too many notification failures, restarting notification processor")
                        update_status_line("Restarting notification processor...")
                        notification_failures = 0  # Reset and continue
        
        # Start notification processing thread
        notification_thread = threading.Thread(target=process_notifications, daemon=True)
        notification_thread.start()
        
        # Start Flask server
        print(f"Starting Flask server on port {SERVER_PORT}...")
        add_console_line(f"Flask Server started on port {SERVER_PORT}")
        logger.info(f"Flask Server started on port {SERVER_PORT}")
        
        # Run the Flask server
        waitress.serve(app, host='0.0.0.0', port=SERVER_PORT, threads=4)
        
    except KeyboardInterrupt:
        msg = "Server stopped by user"
        print(f"\n{msg}")
        logger.info(msg)
        update_status_line("Status: Server stopped by user")
        server.stop_scheduler()
        cleanup_gpio()
    except Exception as e:
        logger.error(f"Error running server: {e}")
        server.stop_scheduler()
        cleanup_gpio()

if __name__ == "__main__":
    main()