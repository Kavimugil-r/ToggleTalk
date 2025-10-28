# ToggleTalk Mobile App

A Flutter mobile application for controlling home appliances through the ToggleTalk Flask server.

## Overview

The ToggleTalk mobile app communicates with the ToggleTalk server via REST API endpoints for reliable communication.

## Architecture

The mobile app uses a client-server architecture:

1. **Mobile App**:
   - Sends messages to the server via REST API
   - Receives responses from the server
   - Polls for notifications from the server

2. **Server**:
   - Processes messages from the mobile app
   - Sends notifications to all connected clients
   - Handles all home automation logic

## API Integration

The mobile app communicates with the server using the following endpoints:

### Send Message
```dart
final url = Uri.parse('http://YOUR_SERVER_IP:7850/api/send_message');
final response = await http.post(
  url,
  headers: {'Content-Type': 'application/json'},
  body: json.encode({
    'message': text,
    'user_name': _userName,
    'user_id': AUTHORIZED_CHAT_ID,
  }),
);
```

### Get Notifications
```dart
final url = Uri.parse('http://YOUR_SERVER_IP:7850/api/get_notifications');
final response = await http.get(url);
```

## How the App Handles Server Responses

### Request-Response Cycle

1. **Sending Messages**:
   - When a user types a command and sends it, the app immediately appends it to the chat display
   - The app makes an HTTP POST request to the server's `/api/send_message` endpoint
   - The request includes the message text, user name, and user ID

2. **Receiving Responses**:
   - The app waits for the server's JSON response
   - Upon receiving a successful response, the app parses the JSON to extract the server's reply
   - The response is then displayed in the chat interface as a bot message
   - Error responses are handled gracefully with user-friendly error messages

3. **Notification Polling**:
   - The app polls the server's `/api/get_notifications` endpoint every 5 seconds
   - When notifications are received, they are displayed in both:
     - The chat interface as bot messages
     - The notification panel accessible via the bell icon
   - Notifications are also shown as push notifications on the device

4. **Real-time Updates**:
   - Device control commands trigger immediate visual feedback in the chat
   - Notifications from other users appear in real-time without requiring a page refresh
   - The app maintains message history using local storage for persistence

### Response Handling Logic

#### Successful Responses
When the server returns a successful response:
```json
{
  "status": "success",
  "response": "✅ Light turned ON.",
  "user_name": "John",
  "user_id": 1767023771
}
```
The app:
1. Parses the JSON response
2. Extracts the "response" field
3. Creates a new message object with `isUser: false`
4. Adds it to the messages list
5. Scrolls to the bottom to show the new message
6. Saves the message history locally

#### Error Responses
When the server returns an error:
```json
{
  "error": "Internal server error occurred"
}
```
The app:
1. Detects the error status code or error field
2. Displays a user-friendly error message in the chat
3. Logs the error for debugging purposes
4. Continues normal operation

#### Notification Handling
When polling returns notifications:
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
The app:
1. Parses each notification in the array
2. Adds each as a bot message to the chat
3. Displays push notifications on the device
4. Saves notifications to the notification panel
5. Clears the server's notification queue

## Setup Instructions

1. Update the server IP address in `lib/main.dart`:
   ```dart
   static const String SERVER_API_URL = 'http://YOUR_SERVER_IP:7850/api';
   ```
   Replace `YOUR_SERVER_IP` with the actual IP address of your ToggleTalk server.
   Alternatively, you can set the `SERVER_API_URL` environment variable when building the app.

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Key Features

### Multi-User Support
- Each user can set their name in the profile
- Messages are personalized with the user's name
- Notifications include the user who triggered the action

### Enhanced Message Handling
- Messages are immediately appended to the chat field
- Server responses are properly received and displayed
- Error handling with user-friendly messages

### Notification System
- Real-time notifications for appliance control
- Notification panel for viewing all alerts
- Push notifications on mobile devices

### Voice Commands
- Speech-to-text functionality for voice commands
- Audio recording capabilities
- Voice message processing

### User Profile Management
- Customizable user names
- Persistent profile settings
- Easy profile access through app bar

## Troubleshooting

### Common Issues

1. **App not connecting to server**:
   - Ensure the server is running
   - Check that the SERVER_API_URL is correct
   - Verify network connectivity between the mobile device and server

2. **Not receiving responses**:
   - Check server logs for errors
   - Ensure the server API is accessible
   - Verify that messages are being sent correctly

3. **Notifications not appearing**:
   - Check that the server is sending notifications
   - Verify that polling is working correctly
   - Check app permissions for notifications

### Debugging

To debug API communication, you can test the endpoints directly:

```bash
curl -X POST http://SERVER_IP:7850/api/send_message -H "Content-Type: application/json" -d '{"message": "Hello", "user_name": "TestUser", "user_id": YOUR_CHAT_ID}'
```

## Directory Structure

```
toggletalk/
├── lib/                   # Dart source code
│   ├── main.dart         # Main application file
│   ├── notification.dart # Notification screen
│   ├── profile.dart      # User profile management
│   ├── splash_screen.dart # App splash screen
│   └── test_screen.dart  # Testing interface
├── assets/               # Images and fonts
├── android/              # Android-specific configuration
├── ios/                  # iOS-specific configuration
├── pubspec.yaml          # Flutter dependencies
└── README.md             # Mobile app documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.