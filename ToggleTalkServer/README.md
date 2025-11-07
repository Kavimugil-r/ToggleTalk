# ToggleTalk - Home Automation System

A complete home automation solution with Flask REST API and mobile app control.

## Overview

ToggleTalk is a home automation system that allows you to control appliances through:
1. Mobile app interface
2. Scheduled automation tasks

The system uses a Raspberry Pi with relay modules to control lights, air conditioners, and washing machines.

## Architecture

ToggleTalk uses a proper client-server architecture:

```
[Mobile App] ←→ [Flask Server] ←→ [Raspberry Pi GPIO]
```

### Components

1. **Flask Server** (`ToggleTalkServer/`):
   - Provides REST API for mobile app communication
   - Controls GPIO devices on Raspberry Pi
   - Manages notifications and scheduled tasks
   - **Enhanced reliability with error handling and recovery mechanisms**

2. **Mobile App** (`toggletalk/`):
   - Communicates with server via REST API
   - Receives notifications via polling

## Features

- **REST API**: Communication through HTTP endpoints
- **Mobile App**: Native mobile interface for appliance control
- **GPIO Control**: Direct control of Raspberry Pi GPIO pins
- **Notification System**: Broadcast messages to all users
- **Scheduled Tasks**: Automate appliance control with timers
- **Event Logging**: Track all system activities
- **Multi-user Support**: Handle multiple authorized users
- **Simulation Mode**: Test on non-Raspberry Pi systems
- **Enhanced Reliability**: Retry mechanisms, error handling, and recovery
- **Health Monitoring**: Server health checks and monitoring capabilities

## Prerequisites

### Server Requirements
- Python 3.8+
- Raspberry Pi (for GPIO control) or any computer (simulation mode)
- Authorized Chat ID

### Mobile App Requirements
- Flutter SDK
- Android/iOS device or emulator

## Installation

### Server Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd ToggleTalkServer
   ```

2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

3. Set environment variables:
   ```bash
   export AUTHORIZED_CHAT_ID="your_chat_id"  # Default: 1767023771
   ```

4. Run the server:
   ```bash
   python ToggleTalkBotServer.py
   ```

### Mobile App Setup

1. Navigate to the mobile app directory:
   ```bash
   cd ../toggletalk
   ```

2. Update the server IP address in `lib/main.dart`:
   ```dart
   static const String SERVER_API_URL = 'http://YOUR_SERVER_IP:7850/api';
   ```

3. Install dependencies:
   ```bash
   flutter pub get
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## Usage

### Home Automation Commands

- "Turn on/off the light"
- "Turn on/off the AC" or "Air Conditioner"
- "Turn on/off the Washing Machine"
- "Schedule light on in 30 seconds"
- "Schedule light on in 5 minutes"
- "Schedule ac off in 1 hour"

### Home Security System Commands

- "Initialize security system" or "Start security system" or "Activate security system" or "Arm security system"
- "Terminate security system" or "Stop security system" or "Deactivate security system" or "Disarm security system"
- "What's the status of the security system?" or "Is the security system active?"

### Message Format

Messages are sent with user context for personalized responses.

## How the Server Responds to Queries

### Request Processing Flow

1. **Message Reception**:
   - The server receives HTTP POST requests at `/api/send_message`
   - Requests must contain JSON data with `message`, `user_name`, and `user_id`

2. **Authorization Check**:
   - The server verifies that the `user_id` matches the authorized chat ID (1767023771)
   - Unauthorized requests are processed but may receive limited responses

3. **Message Parsing**:
   - The server analyzes the message text to determine the intent
   - Supports home automation commands, status queries, and general conversation

4. **Command Execution**:
   - For device control commands, the server activates the appropriate GPIO pin
   - For status queries, the server retrieves current device states
   - For general conversation, the server generates contextual responses

5. **Response Generation**:
   - The server creates a personalized response using the provided `user_name`
   - Responses are formatted as plain text with appropriate emojis and status indicators

6. **Notification Broadcasting**:
   - For device control commands, the server generates notifications for all users
   - Notifications are stored in a pending queue for client retrieval

7. **Response Delivery**:
   - The server immediately returns the response to the requesting client
   - Notifications are delivered to all clients via the polling mechanism

### Response Types

#### Home Automation Responses
- Device control: "✅ Light turned ON."
- Device status: "💡 Light is currently on."
- Error conditions: "⚠️ Error turning on light. Please try again."

#### Home Security System Responses
- System initialization: "✅ Home Security System INITIALIZED. Laser module activated and monitoring for intruders."
- System termination: "✅ Home Security System TERMINATED. All modules deactivated."
- System status: "🛡️ Home Security System is currently ACTIVE." or "🛡️ Home Security System is currently INACTIVE."
- Security alert: "🚨 Suspicious activity detected by Home Security System at HH:MM:SS"

#### Conversation Responses
- Greetings: "Hello John! Welcome to ToggleTalk Server!"
- Help requests: "Hello John! I can help you control your home appliances and security system! Try commands like 'Turn on the light', 'Turn off the AC', 'Initialize security system', or 'Terminate security system'."
- Status queries: "🏠 John, Current Device Status:\n• Light: On\n• Air Conditioner: Off\n• Washing Machine: Off\n• Home Security System: Active"

#### Scheduled Task Responses
- Task creation: "⏰ Scheduled Light to turn ON at 14:30."
- Execution notifications: "⏰ Scheduled: Light turned ON by John"

### Error Handling

The server implements comprehensive error handling:
- Invalid requests return appropriate HTTP status codes (400, 500)
- GPIO errors are caught and reported to users
- File operation errors use retry mechanisms
- Network errors are logged for debugging

## Deployment

### Raspberry Pi Deployment

For Raspberry Pi deployment, you can use the systemd service and management scripts:

1. **Setup the service**:
   ```bash
   # Copy the service file to systemd directory
   sudo cp toggletalk.service /etc/systemd/system/
   
   # Reload systemd daemon
   sudo systemctl daemon-reload
   
   # Enable the service to start on boot
   sudo systemctl enable toggletalk
   ```

2. **Using systemd (recommended for production)**:
   ```bash
   # Start the service
   sudo systemctl start toggletalk
   
   # Enable auto-start on boot
   sudo systemctl enable toggletalk
   
   # Check status
   sudo systemctl status toggletalk
   
   # View logs
   sudo journalctl -u toggletalk -f
   ```

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

### Cross-Platform Startup Scripts

Use the provided startup scripts:

```bash
# Make the script executable (Linux/Raspberry Pi)
chmod +x StartToggleTalkBotServer.sh

# Start the server (Windows)
StartToggleTalkBotServer.bat

# Start the server (Linux/Raspberry Pi)
./StartToggleTalkBotServer.sh
```

### Reliability Features

The server includes several reliability improvements:

1. **Enhanced Error Handling**:
   - Comprehensive error handling with proper HTTP status codes
   - User-friendly error messages
   - Graceful degradation when components fail

2. **Retry Mechanisms**:
   - File operations attempt up to 3 times before failing
   - GPIO operations include retry logic
   - Notification sending has retry mechanisms

3. **Data Validation**:
   - JSON data validation to handle corrupted files
   - Input validation for all API requests
   - Automatic backup creation for data files

4. **Health Monitoring**:
   - Enhanced health check endpoint with detailed status
   - Comprehensive logging for debugging

5. **Graceful Recovery**:
   - Automatic cleanup of resources on shutdown
   - Backup and recovery mechanisms for data files

## API Endpoints

The server provides REST API endpoints for mobile app integration:

### POST /api/send_message
Send a message to the server for processing.

Request body:
```json
{
  "message": "Your message here",
  "user_name": "Your username",
  "user_id": "Your user ID"
}
```

Response:
```json
{
  "status": "success",
  "response": "Server response text",
  "user_name": "Your username",
  "user_id": "Your user ID"
}
```

### GET /api/get_notifications
Retrieve pending notifications for the mobile app.

Response:
```json
{
  "status": "success",
  "notifications": [
    {
      "text": "Notification message",
      "timestamp": "ISO timestamp"
    }
  ],
  "count": 1
}
```

### GET /api/get_events
Retrieve recent events from the server.

Response:
```json
{
  "status": "success",
  "events": [
    {
      "timestamp": "ISO timestamp",
      "event_type": "event_type",
      "message": "Event message",
      "user_name": "User name",
      "user_id": "User ID"
    }
  ],
  "count": 1
}
```

### GET /api/health
Health check endpoint.

Response:
```json
{
  "status": "healthy",
  "timestamp": "ISO timestamp",
  "file_system_status": "healthy",
  "uptime": "0:00:00",
  "messages_processed": 0,
  "avg_processing_time": 0.0
}
```

## Troubleshooting

### Common Issues

1. **Mobile app not receiving responses**:
   - Ensure the server is running and accessible
   - Check that the SERVER_API_URL in the mobile app is correct
   - Verify network connectivity between the mobile device and server

2. **GPIO control not working**:
   - Ensure you're running on a Raspberry Pi
   - Check that the GPIO pins are correctly connected
   - Verify that the user has permission to access GPIO

### Logs

Check the server logs for debugging information or view the events log:
```bash
tail -f events.log
```

## Directory Structure

```
ToggleTalk/
├── ToggleTalkServer/          # Server code and documentation
│   ├── ToggleTalkBotServer.py         # Main server application
│   ├── requirements.txt       # Python dependencies
│   ├── requirements_windows.txt # Windows-specific dependencies
│   ├── StartToggleTalkBotServer.bat # Startup script for Windows
│   ├── StartToggleTalkBotServer.sh  # Startup script for Linux/Raspberry Pi
│   ├── chat_ids.json          # Registered user chat IDs
│   ├── user_preferences.json  # User preferences
│   ├── scheduled_tasks.json   # Scheduled appliance tasks
│   ├── events.log             # Event log for client synchronization
│   └── README.md              # Server documentation
└── toggletalk/                # Mobile app code
    ├── lib/                   # Dart source code
    ├── assets/                # App assets
    ├── pubspec.yaml           # Flutter dependencies
    └── README.md              # Mobile app documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.