# ToggleTalk - Smart Home Automation System

ToggleTalk is a complete smart home automation solution that combines a Flutter mobile application with a Python-based Flask server. Users can control home appliances through the mobile app, with real-time notifications sent to all connected users.

## Table of Contents
- [System Architecture](#system-architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
  - [Server Setup](#server-setup)
  - [Mobile App Setup](#mobile-app-setup)
- [How It Works](#how-it-works)
- [Application Workflow](#application-workflow)
- [Home Automation Commands](#home-automation-commands)
- [Scheduled Tasks](#scheduled-tasks)
- [Notification System](#notification-system)
- [User Profile Management](#user-profile-management)
- [GPIO Pin Configuration](#gpio-pin-configuration)
- [Project Structure](#project-structure)
- [Dependencies](#dependencies)
- [Running the Application](#running-the-application)
- [Potential Issues and Solutions](#potential-issues-and-solutions)
- [Troubleshooting](#troubleshooting)

## System Architecture

ToggleTalk follows a client-server architecture:

```
┌─────────────────┐    ┌──────────────────────┐    ┌──────────────────┐
│   Mobile App    │    │    Flask Server      │    │  Home Appliances │
│   (Flutter)     │◄──►│     (Python)         │◄──►│  (Relays/GPIO)   │
└─────────────────┘    └──────────────────────┘    └──────────────────┘
```

## Features

### Mobile App (Flutter)
- Modern chat interface with real-time messaging
- Voice recording and transcription capabilities
- Notification panel for appliance status updates
- User profile management with name customization
- Custom UI with distinct user/bot message styling
- Persistent message history using shared preferences
- Cross-platform support (Android & iOS)
- **Event log retrieval for synchronization with server activities**

### Server (Python - Flask)
- REST API for client communication
- GPIO control for Raspberry Pi relays
- Scheduled appliance control (ON/OFF timers)
- Multi-user notification broadcasting
- Persistent storage for user preferences and chat IDs
- Home automation command processing
- Device status management
- **Authorized chat ID restriction (only responds to chat ID 1767023771)**
- **Event logging system for client synchronization**
- **Enhanced reliability with retry mechanisms and error handling**

### Home Automation
- Control lights, air conditioner, and washing machine
- Scheduled appliance control
- Real-time status reporting
- **Context-aware notifications with user names and timestamps**

## Prerequisites

### Hardware Requirements
- **Raspberry Pi 3 Model B+** (for GPIO control)
- **3-channel relay module**
- **Home appliances** (lights, AC, washing machine)
- **Mobile device** (Android or iOS) for the client app

### Software Requirements
- **Python 3.7+** for the server
- **Flutter SDK 3.0+** for the mobile app
- **Internet connection** for API access

## Setup Instructions

### Server Setup

1. Navigate to the server directory:
   ```bash
   cd ToggleTalkServer
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Configure environment variables:
   ```bash
   export AUTHORIZED_CHAT_ID=1767023771  # Default authorized chat ID
   ```

4. Connect GPIO pins to relays:
   - Pin 23 → Light relay
   - Pin 24 → AC relay
   - Pin 25 → Washing machine relay

### Mobile App Setup

1. Navigate to the app directory:
   ```bash
   cd toggletalk
   ```

2. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Update the server IP address in `lib/main.dart`:
   ```dart
   static const String SERVER_API_URL = 'http://localhost:7850/api'; // Change to your server IP or use environment variable
   ```

4. Build and run the app:
   ```bash
   flutter run
   ```

## How It Works

### Communication Flow

1. **User Interaction**:
   - Users control appliances via the mobile app
   - Commands are sent to the Flask server via REST API

2. **Server Processing**:
   - Server only responds to authorized chat ID (1767023771)
   - Processes home automation commands
   - Controls GPIO pins on Raspberry Pi
   - Sends notifications to all registered users with user context

3. **API Response Mechanism**:
   - When a user sends a command, the mobile app makes a POST request to `/api/send_message`
   - The server processes the command and generates an appropriate response
   - The response is immediately sent back to the requesting client
   - For device control commands, notifications are broadcast to all connected users

4. **Notification Distribution**:
   - All users receive real-time notifications about appliance status changes
   - Notifications include user name and timestamp: `🔔 username: command at HH:MM:SS`
   - Notifications appear in both the mobile app and as push notifications

### API Endpoints

The Flask server provides the following REST API endpoints:

#### POST /api/send_message
Sends a message/command to the server for processing.

**Request Format**:
```json
{
  "message": "Turn on the light",
  "user_name": "John",
  "user_id": 1767023771
}
```

**Response Format**:
```json
{
  "status": "success",
  "response": "✅ Light turned ON.",
  "user_name": "John",
  "user_id": 1767023771
}
```

#### GET /api/get_notifications
Retrieves pending notifications for the mobile app (polled every 5 seconds).

**Response Format**:
```json
{
  "status": "success",
  "notifications": [
    {
      "text": "🔔 John: Turn on Light at 14:30:25",
      "timestamp": "2025-10-21T14:30:25.123456"
    }
  ],
  "count": 1
}
```

#### GET /api/get_events
Retrieves recent system events for synchronization.

**Response Format**:
```json
{
  "status": "success",
  "events": [
    {
      "timestamp": "2025-10-21T14:30:25.123456",
      "event_type": "device_control",
      "message": "Light turned ON by John",
      "user_name": "John",
      "user_id": 1767023771
    }
  ],
  "count": 1
}
```

#### GET /api/health
Health check endpoint for monitoring server status.

**Response Format**:
```json
{
  "status": "healthy",
  "timestamp": "2025-10-21T14:30:25.123456",
  "file_system_status": "healthy",
  "uptime": "0:15:30",
  "messages_processed": 42,
  "avg_processing_time": 0.025
}
```

### Data Persistence

- **Chat IDs**: Stored in `chat_ids.json` for notification broadcasting
- **User Preferences**: Stored in `user_preferences.json`
- **Scheduled Tasks**: Stored in `scheduled_tasks.json`
- **Event Logs**: Stored in `events.log` for client synchronization
- **Mobile Messages**: Stored locally using SharedPreferences

## Application Workflow

### Initial Setup
1. User deploys Flask server on Raspberry Pi
2. User installs mobile app on their device
3. User configures server IP in mobile app

### First-Time Usage
1. User opens mobile app
2. User sets their name in the profile page by tapping the bot icon in the app bar
3. User can now control appliances through the mobile app

### Ongoing Usage
1. User sends command to control appliance via mobile app
2. Command is processed by server with user context
3. Server controls GPIO pins
4. Server sends notification to all users with user name and timestamp
5. All users receive real-time updates

## Home Automation Commands

### Immediate Control
- **Lights**: "Turn on the lights", "Turn off the lights"
- **Air Conditioner**: "Turn on the AC", "Turn off the AC"
- **Washing Machine**: "Turn on the washing machine", "Turn off the washing machine"
- **Security System**: "Initialize security system", "Terminate security system"

### Status Queries
- "What's the status of the lights?"
- "What's the status of the AC?"
- "What's the status of the washing machine?"
- "What's the status of the security system?"

### General Conversation
- "Hello", "Hi", "How are you?"
- "What time is it?"
- "What's your name?"
- "Help" or "What can you do?"

## Scheduled Tasks

Users can schedule appliances to turn ON/OFF at specific times:

### Scheduling Commands
- "Schedule light on in 30 seconds"
- "Schedule light on in 5 minutes"
- "Schedule ac off in 1 hour"
- "Schedule washing machine on in 2 hours"

### Task Management
- Scheduled tasks are stored persistently and execute automatically when their time comes.

## Notification System

### Real-Time Notifications
All users receive immediate notifications when appliances are controlled:

- **Immediate Actions**: "🔔 John: Turn off Air Conditioner at 14:30:25"
- **Scheduled Tasks**: "⏰ Scheduled: Light turned ON by John"

### Notification Types
1. **Control Notifications**: When any user controls an appliance
2. **Scheduled Notifications**: When scheduled tasks execute
3. **Status Notifications**: When appliances change state automatically

### Notification Delivery
- Mobile app notification panel
- Push notifications on mobile devices

### Event Log Synchronization
The server maintains an `events.log` file that clients can retrieve using the API endpoint. This allows new devices to synchronize with system activities.

## User Profile Management

### Setting Your Name
1. Tap the bot icon in the top-left corner of the main chat screen
2. Enter your name in the profile page
3. Click "Save Name" to save your preference

### Features
- Persistent name storage using SharedPreferences
- Name injection into all commands sent to the server
- Profile information displayed in notifications
- Save button greys out when no changes are present

## GPIO Pin Configuration

On Raspberry Pi 3 Model B+:

### Home Automation Appliances
| GPIO Pin | Appliance        | Relay Channel |
|----------|------------------|---------------|
| 23       | Light            | Relay 1       |
| 24       | Air Conditioner  | Relay 2       |
| 25       | Washing Machine  | Relay 3       |

### Home Security System
| GPIO Pin | Component        | Function              |
|----------|------------------|-----------------------|
| 27       | Laser Module     | Intruder detection    |
| 22       | LDR Sensor       | Light sensing         |
| 5        | Buzzer           | Audio alerts          |

**Note**: GPIO pins are configurable via environment variables. Defaults are shown above.
**Note**: The system includes simulation mode for testing on non-Raspberry Pi platforms.

## Project Structure

```
flow/
├── ToggleTalkServer/             # Python server implementation
│   ├── ToggleTalkBotServer.py        # Main server application
│   ├── requirements.txt      # Server dependencies
│   ├── chat_ids.json         # Registered user chat IDs
│   ├── user_preferences.json # User preferences
│   ├── scheduled_tasks.json  # Scheduled appliance tasks
│   └── events.log            # Event log for client synchronization
│
└── toggletalk/               # Flutter mobile application
    ├── lib/
    │   ├── main.dart         # Main application file
    │   ├── notification.dart # Notification screen
    │   └── profile.dart      # User profile management
    ├── assets/               # Images and fonts
    ├── android/              # Android-specific configuration
    ├── ios/                  # iOS-specific configuration
    ├── pubspec.yaml          # Flutter dependencies
    └── README.md             # Mobile app documentation
```

## Dependencies

### Server (Python)
- `flask` - Web framework for REST API
- `flask-cors` - Cross-origin resource sharing support
- `waitress` - Production WSGI server
- `RPi.GPIO` - Raspberry Pi GPIO control (simulation mode on other platforms)

### Mobile App (Flutter)
- `http` - HTTP requests to server API
- `shared_preferences` - Local data persistence
- `flutter_local_notifications` - Push notifications
- `flutter_sound` - Audio recording
- `permission_handler` - Device permission management
- `speech_to_text` - Voice-to-text conversion
- `device_info_plus` - Device information

## Running the Application

### Starting the Server
```bash
cd ToggleTalkServer
python ToggleTalkBotServer.py
```

Or use the provided startup scripts:
```bash
# Windows
start_flask_server.bat

# Linux/Raspberry Pi
./start_flask_server.sh
```

### Starting the Mobile App
```bash
cd toggletalk
flutter run
```

### Production Deployment
1. Deploy server on Raspberry Pi with GPIO connections
2. Build mobile app for distribution:
   ```bash
   flutter build apk  # For Android
   flutter build ios  # For iOS (requires macOS)
   ```

## Potential Issues and Solutions

### 1. **Server Not Responding**
- **Issue**: Client sends messages but receives no response
- **Solution**: 
  1. Verify the server is running
  2. Check that the server IP is correctly configured in the mobile app
  3. Ensure the authorized chat ID matches the user's chat ID (default: 1767023771)
  4. Check server logs for error messages

### 2. **Event Log Not Created**
- **Issue**: `events.log` file is not being created
- **Solution**:
  1. Verify the server has write permissions in the directory
  2. Check that the server is running without errors
  3. Send a test command to trigger event logging

### 3. **Notifications Not Appearing**
- **Issue**: Users don't receive notifications when appliances are controlled
- **Solution**:
  1. Verify chat IDs are properly registered in `chat_ids.json`
  2. Check notification permissions on mobile devices
  3. Ensure the server is properly broadcasting notifications

### 4. **Scheduled Tasks Not Executing**
- **Issue**: Scheduled appliance control tasks don't execute at the specified time
- **Solution**:
  1. Check server logs for scheduler errors
  2. Verify system time is correct on the Raspberry Pi
  3. Ensure the server is running continuously

### 5. **GPIO Control Issues**
- **Issue**: Appliances are not responding to control commands
- **Solution**:
  1. Verify GPIO pin connections to relays
  2. Check Raspberry Pi permissions (`sudo usermod -a -G gpio $USER`)
  3. Test in simulation mode first to verify logic works

### 6. **Client-Server Communication Problems**
- **Issue**: Client doesn't receive updates from the server
- **Solution**:
  1. Verify the polling mechanism is working in the client
  2. Check that the API endpoints are properly implemented
  3. Ensure network connectivity between client and server

## Troubleshooting

### Common Issues

1. **"Failed to connect to server"**:
   - Verify server is correctly configured and running
   - Check internet connectivity
   - Ensure server IP is correctly set in mobile app

2. **Notifications not appearing**:
   - Verify chat ID is properly set
   - Check notification permissions on mobile device
   - Ensure server is properly broadcasting

3. **GPIO control not working**:
   - Verify GPIO pin connections
   - Check Raspberry Pi permissions (`sudo usermod -a -G gpio $USER`)
   - Test in simulation mode first

4. **Scheduled tasks not executing**:
   - Check server logs for scheduler errors
   - Verify system time is correct
   - Ensure server is running continuously

5. **Event log synchronization issues**:
   - Verify the `events.log` file exists on the server
   - Check server logs for errors in the API endpoints
   - Ensure the client is properly accessing the API endpoints

### Debugging Tips

1. **Enable verbose logging**:
   - Server: Check console output for detailed logs
   - Mobile App: Use Flutter DevTools for debugging

2. **Test server API**:
   ```bash
   curl -X POST http://SERVER_IP:SERVER_PORT/api/send_message -H "Content-Type: application/json" -d '{"message": "Hello", "user_name": "TestUser", "user_id": YOUR_CHAT_ID}'
   ```

3. **Check chat ID registration**:
   - View `chat_ids.json` on server
   - Use mobile app to send a test message

### Support

For issues not covered in this documentation, please:
1. Check server logs for error messages
2. Verify all configuration files are correctly set
3. Ensure all dependencies are properly installed
4. Consult the individual README files in each directory