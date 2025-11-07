import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
// Add audio recording dependencies
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'notification.dart';
import 'profile.dart'; // Add profile page
// Add local notifications
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Add speech to text
import 'package:speech_to_text/speech_to_text.dart' as stt;
// Add animation
import 'package:flutter/animation.dart';
// Add device info
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Add MethodChannel
// Add splash screen
import 'splash_screen.dart';
// Add test screen

import 'package:home_widget/home_widget.dart';
import 'home_widget_service.dart';
// Add feature discovery
import 'package:feature_discovery/feature_discovery.dart';

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Method channel for handling Android widget broadcasts
const MethodChannel platform = MethodChannel('com.example.toggletalk/widget');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showSplash = true;
  bool _initError = false;
  bool _hasShownPermissionsDialog = false; // Add this flag

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initializeNotifications();
      // Initialize home widget
      await HomeWidgetService.init();
    } catch (e) {
      print('Error during app initialization: $e');
      setState(() {
        _initError = true;
      });
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize local notifications with timeout
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('app_icon');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await flutterLocalNotificationsPlugin
          .initialize(
            initializationSettings,
            onDidReceiveNotificationResponse:
                (NotificationResponse notificationResponse) async {
                  // Handle notification tap
                },
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('Notification initialization timed out');
              return Future.value(false);
            },
          );
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  void _finishSplash() {
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        home: SplashScreen(onSplashFinished: _finishSplash),
        debugShowCheckedModeBanner: false,
      );
    }

    if (_initError) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                SizedBox(height: 16),
                Text('Failed to initialize the app'),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _initError = false;
                      _showSplash = true;
                    });
                    _initializeApp();
                  },
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const ToggleTalkApp();
  }
}

class ToggleTalkApp extends StatelessWidget {
  const ToggleTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FeatureDiscovery(
      recordStepsInSharedPreferences: false,
      child: MaterialApp(
        title: 'ToggleTalk',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.yellow, // Changed to yellow accent color
          ),
          // Use custom fonts throughout the app
          fontFamily: 'Comfortaa', // Default font for the app
        ),
        home: const ToggleTalkScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class Message {
  final int id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isAudio; // New field to identify audio messages

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isAudio = false, // Default to false for text messages
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch,
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      isAudio: json['isAudio'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'isAudio': isAudio,
    };
  }
}

// Custom circular bot icon widget
class CircularBotIcon extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const CircularBotIcon({
    super.key,
    this.size = 28.0,
    this.backgroundColor =
        Colors.transparent, // Changed to transparent to avoid covering the icon
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size,
      backgroundColor: backgroundColor,
      child: ClipOval(
        child: Image.asset(
          'assets/icons/ToggleTalk.png',
          width: size * 2,
          height: size * 2,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class ToggleTalkScreen extends StatefulWidget {
  const ToggleTalkScreen({super.key});

  @override
  State<ToggleTalkScreen> createState() => _ToggleTalkScreenState();
}

class _ToggleTalkScreenState extends State<ToggleTalkScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Add WidgetsBindingObserver
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoading = false;
  bool _isInitialized = false; // New flag to track initialization status
  bool _initError = false; // New flag to track initialization errors
  String _initErrorMessage = ''; // To store error message
  int _lastUpdateId = 0;
  static const int AUTHORIZED_CHAT_ID = int.fromEnvironment(
    'AUTHORIZED_CHAT_ID',
    defaultValue: 1767023771,
  ); // Configurable chat ID

  // Generate a unique user ID for each app instance
  final int _uniqueUserId = DateTime.now().millisecondsSinceEpoch;
  Timer? _pollingTimer; // Add this line to store the polling timer

  // User name for context injection
  String _userName = 'User';

  // Home widget appliance states
  bool _homeWidgetLightOn = false;
  bool _homeWidgetAcOn = false;
  bool _homeWidgetWashingMachineOn = false;

  // Removed notification key

  // Audio recording variables
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _isRecording = false;
  String _audioPath = '';

  // Speech to text variables
  late stt.SpeechToText _speechToText;
  bool _isListening = false;
  String _transcribedText = '';

  // Animation variables
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  // Server API endpoint - change this to your server's IP address
  static const String SERVER_API_URL = String.fromEnvironment(
    'SERVER_API_URL',
    defaultValue: 'http://192.168.244.80:7850/api',
  ); // Configurable server URL

  @override
  void initState() {
    super.initState();
    _initializeApp();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);

    // Set up MethodChannel handler for Android widget broadcasts
    platform.setMethodCallHandler(_handleMethod);
  }

  @override
  void dispose() {
    // Remove observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    // Cancel polling timer when disposing
    _pollingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _audioRecorder.closeRecorder();
    _animationController.dispose(); // Dispose animation controller
    super.dispose();
  }

  // Handle method calls from Android widget
  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'toggleAppliance':
        final String appliance = call.arguments['appliance'];
        // Get current state and toggle it
        bool currentState = false;
        switch (appliance) {
          case 'light':
            currentState = _homeWidgetLightOn;
            break;
          case 'ac':
            currentState = _homeWidgetAcOn;
            break;
          case 'washing_machine':
            currentState = _homeWidgetWashingMachineOn;
            break;
        }
        // Send command to toggle the appliance
        await _toggleApplianceFromWidget(appliance, !currentState);
        break;
      default:
        throw MissingPluginException('Method not implemented');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh username when app resumes
      _refreshUserName();
    }
  }

  Future<void> _initializeApp() async {
    try {
      print('Initializing app...');

      // Load user name with timeout
      await _loadUserName().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Loading username timed out');
          return Future.value();
        },
      );

      // Check if permissions are already granted with timeout
      final permissionsGranted = await _checkPermissions().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('Permission check timed out');
          return Future.value(false);
        },
      );

      // Always show permissions dialog on first launch
      final prefs = await SharedPreferences.getInstance();
      final hasLaunchedBefore = prefs.getBool('has_launched_before') ?? false;

      if (!hasLaunchedBefore || !permissionsGranted) {
        // Show explanation dialog and request permissions with timeout
        await _showPermissionDialog().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Permission dialog timed out');
            return Future.value();
          },
        );

        // Mark that the app has been launched before
        await prefs.setBool('has_launched_before', true);
      }

      await _loadMessages().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Loading messages timed out');
          return Future.value();
        },
      );
      print('Messages loaded');

      // Start polling for notifications with timeout
      await _startNotificationPolling().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Starting notification polling timed out');
          return Future.value();
        },
      );
      print('Notification polling started');

      _sendWelcomeMessage();
      print('Welcome message sent');

      await _initAudioRecorder().timeout(
        Duration(seconds: 15),
        onTimeout: () {
          print('Audio recorder initialization timed out');
          return Future.value();
        },
      );
      print('Audio recorder initialized');

      _speechToText = stt.SpeechToText();
      print('Speech to text initialized');

      // Initialize animation controller for pulse effect
      _animationController = AnimationController(
        duration: const Duration(milliseconds: 1000),
        vsync: this,
      )..repeat(reverse: true);

      _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );

      setState(() {
        _isInitialized = true;
      });

      // Start feature discovery walkthrough after a short delay
      if (!hasLaunchedBefore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(Duration(seconds: 2), () {
            _startFeatureDiscovery();
          });
        });
      }

      print('App initialization complete');
    } catch (e, stackTrace) {
      print('Error during app initialization: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _initError = true;
        _initErrorMessage = e.toString();
        _isInitialized = true;
      });

      // Show error to user
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App initialization failed: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  setState(() {
                    _initError = false;
                    _initErrorMessage = '';
                  });
                  _initializeApp();
                },
              ),
            ),
          );
        });
      }
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      // Initialize local notifications with timeout
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('app_icon');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();

      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsDarwin,
          );

      await flutterLocalNotificationsPlugin
          .initialize(
            initializationSettings,
            onDidReceiveNotificationResponse:
                (NotificationResponse notificationResponse) async {
                  // Handle notification tap
                },
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('Notification initialization timed out');
              return Future.value(false);
            },
          );
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
      });
      print('Loaded username: $_userName');

      // Also update the home widget with the loaded username
      await HomeWidgetService.updateUserName(_userName);
    } catch (e) {
      print('Error loading username: $e');
      // Use default username if there's an error
      setState(() {
        _userName = 'User';
      });

      // Also update the home widget with the default username
      await HomeWidgetService.updateUserName(_userName);
    }
  }

  /// Check if all necessary permissions are granted
  Future<bool> _checkPermissions() async {
    try {
      // Check microphone permission with timeout
      final micStatus = await Permission.microphone.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Microphone permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        return false;
      }

      // Check storage permission with timeout
      final storageStatus = await Permission.storage.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Storage permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (storageStatus != PermissionStatus.granted) {
        return false;
      }

      // Check notification permission for Android 13+ with timeout
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            print('Android info retrieval timed out');
            throw TimeoutException(
              'Android info timeout',
              Duration(seconds: 5),
            );
          },
        );
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13 (Tiramisu)
          final notificationStatus = await Permission.notification.status
              .timeout(
                Duration(seconds: 5),
                onTimeout: () {
                  print('Notification permission check timed out');
                  return Future.value(PermissionStatus.denied);
                },
              );
          if (notificationStatus != PermissionStatus.granted) {
            return false;
          }
        }
      }

      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// Show a dialog to explain why permissions are needed
  Future<void> _showPermissionDialog() async {
    if (!mounted) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permissions Required'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'This app requires the following permissions to work properly:',
                ),
                SizedBox(height: 10),
                Text('• Microphone: For voice messages'),
                Text('• Storage: For saving recordings'),
                Text('• Notifications: For receiving alerts'),
                SizedBox(height: 20),
                Text('Please grant these permissions in the next screen.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Continue'),
              onPressed: () {
                Navigator.of(context).pop();
                _requestAllPermissions();
              },
            ),
          ],
        );
      },
    );
  }

  /// Check and request all necessary permissions for the app
  Future<void> _requestAllPermissions() async {
    try {
      // Request microphone permission for voice messages with timeout
      final micStatus = await Permission.microphone.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Microphone permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        print('Microphone permission denied');
      }

      // Request storage permission for saving files with timeout
      final storageStatus = await Permission.storage.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Storage permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (storageStatus != PermissionStatus.granted) {
        print('Storage permission denied');
      }

      // Request notification permission for Android 13+ with timeout
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo.timeout(
          Duration(seconds: 5),
          onTimeout: () {
            print('Android info retrieval timed out');
            throw TimeoutException(
              'Android info timeout',
              Duration(seconds: 5),
            );
          },
        );
        if (androidInfo.version.sdkInt >= 33) {
          // Android 13 (Tiramisu)
          final notificationStatus = await Permission.notification
              .request()
              .timeout(
                Duration(seconds: 10),
                onTimeout: () {
                  print('Notification permission request timed out');
                  return Future.value(PermissionStatus.denied);
                },
              );
          if (notificationStatus != PermissionStatus.granted) {
            print('Notification permission denied');
          }
        }
      }
    } catch (e) {
      print('Error requesting permissions: $e');
    }
  }

  Future<void> _initAudioRecorder() async {
    try {
      // Request microphone permission first with timeout
      final micStatus = await Permission.microphone.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Microphone permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        print('Microphone permission denied');
        // Show a message to the user about permissions
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Microphone permission is required for voice messages',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  openAppSettings();
                },
              ),
            ),
          );
        }
        return; // Don't proceed with audio initialization if permission is denied
      }

      // Also check storage permission for saving recordings (if needed) with timeout
      final storageStatus = await Permission.storage.request().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          print('Storage permission request timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (storageStatus != PermissionStatus.granted) {
        print('Storage permission denied - this may limit some features');
        // This is not critical, so we continue
      }

      // Add timeout to prevent hanging
      await _audioRecorder.openRecorder().timeout(Duration(seconds: 15));
    } catch (e) {
      print('Error initializing audio recorder: $e');
      // Don't let audio initialization errors crash the app
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio recording features may not work properly'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // Start polling for notifications from the server
  Future<void> _startNotificationPolling() async {
    // Cancel any existing timer
    _pollingTimer?.cancel();

    // Start a new timer that polls every 5 seconds
    _pollingTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      try {
        print('Polling for updates...');
        await _fetchUpdates().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Fetch updates timed out');
            return Future.value();
          },
        );
      } catch (e) {
        print('Error during polling: $e');
        // Continue polling even if there's an error
      }
    });
  }

  // Fetch notifications from the server via API instead of Telegram
  Future<void> _fetchUpdates() async {
    try {
      // Fetch notifications from the server API
      final url = Uri.parse('$SERVER_API_URL/get_notifications');
      final response = await http.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success' && data['notifications'] != null) {
          final List<dynamic> notifications = data['notifications'];

          for (var notification in notifications) {
            final notificationText = notification['text'] as String;
            final timestamp = DateTime.parse(
              notification['timestamp'] as String,
            );

            print('Received notification: $notificationText');

            // Process the notification
            await _processNotificationMessage(notificationText);
          }
        }
      } else {
        print(
          'Failed to fetch notifications. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      // Continue polling even if there's an error
    } finally {
      // If we're still showing loading indicator, hide it
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Process incoming notification messages
  Future<void> _processNotificationMessage(String messageText) async {
    // Check if this is a notification message
    if (messageText.startsWith('[NOTIFICATION]')) {
      // Extract the actual notification text
      final notificationText = messageText;

      // Save the notification
      final timestamp = DateTime.now();
      await _saveNotification(notificationText, timestamp);

      // Show local notification
      await _showLocalNotification(notificationText);

      // Add notification to chat as a bot message
      setState(() {
        _messages.add(
          Message(
            id: DateTime.now().millisecondsSinceEpoch,
            text: notificationText,
            isUser: false,
            timestamp: timestamp,
          ),
        );
      });
      _scrollToBottom();
      _saveMessages();

      print('Processed notification: $notificationText');

      // Show notification received feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New notification received'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Update home widget with the notification
      await _updateHomeWidgetFromNotification(notificationText);
    } else {
      // Regular bot response
      final timestamp = DateTime.now();

      setState(() {
        _messages.add(
          Message(
            id: DateTime.now().millisecondsSinceEpoch,
            text: messageText,
            isUser: false,
            timestamp: timestamp,
          ),
        );
      });
      _scrollToBottom();
      _saveMessages();

      print('Processed bot response: $messageText');
    }
  }

  // Update home widget based on notification content
  Future<void> _updateHomeWidgetFromNotification(
    String notificationText,
  ) async {
    try {
      // Parse the notification to determine which appliance was controlled
      // Expected format: [NOTIFICATION] 🔔 {username}: {message} at {time}
      bool lightOn = false;
      bool acOn = false;
      bool washingMachineOn = false;
      bool stateChanged = false;

      if (notificationText.contains('light') &&
          notificationText.contains('turned')) {
        lightOn = notificationText.contains('turned ON');
        stateChanged = true;
      } else if (notificationText.contains('Air Conditioner') &&
          notificationText.contains('turned')) {
        acOn = notificationText.contains('turned ON');
        stateChanged = true;
      } else if (notificationText.contains('Washing Machine') &&
          notificationText.contains('turned')) {
        washingMachineOn = notificationText.contains('turned ON');
        stateChanged = true;
      }

      if (stateChanged) {
        // Get current states from widget
        final currentStates = await HomeWidgetService.getApplianceStates();

        // Update only the changed appliance
        if (notificationText.contains('light')) {
          currentStates['light'] = lightOn;
        } else if (notificationText.contains('Air Conditioner')) {
          currentStates['ac'] = acOn;
        } else if (notificationText.contains('Washing Machine')) {
          currentStates['washing_machine'] = washingMachineOn;
        }

        // Update widget UI with new states
        await HomeWidgetService.updateWidgetUI(currentStates, _userName);
      }
    } catch (e) {
      print('Error updating home widget from notification: $e');
    }
  }

  // Disable the polling mechanism to avoid conflicts with the server
  // The server will handle all Telegram API interactions
  void _startPolling() {
    // Do nothing - polling is handled by the server
    print('Polling disabled - server handles Telegram API interactions');
  }

  void _sendWelcomeMessage() {
    // Add a welcome message from the bot
    setState(() {
      _messages.add(
        Message(
          id: 0,
          text:
              'Hello! I\'m your ToggleTalk bot assistant. How can I help you today?\n\n'
              'Tip: Use /help to see available commands.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
    _saveMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      final String? messagesJson = prefs.getString('messages');

      if (messagesJson != null) {
        final List<dynamic> messagesList = json.decode(messagesJson);
        setState(() {
          _messages.clear();
          for (var message in messagesList) {
            _messages.add(
              Message(
                id: message['id'],
                text: message['text'],
                isUser: message['isUser'],
                timestamp: DateTime.parse(message['timestamp']),
                isAudio: message['isAudio'] ?? false,
              ),
            );
          }
        });
        _scrollToBottom();
        print('Loaded ${messagesList.length} messages from storage');
      } else {
        print('No saved messages found');
      }
    } catch (e) {
      print('Error loading messages: $e');
      // Continue with empty messages list if there's an error
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      final List<Map<String, dynamic>> messagesList = _messages
          .map((message) => message.toJson())
          .toList();
      await prefs
          .setString('messages', json.encode(messagesList))
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Saving messages timed out');
              throw TimeoutException(
                'Save messages timeout',
                Duration(seconds: 5),
              );
            },
          );
    } catch (e) {
      print('Error saving messages: $e');
      // Continue without saving if there's an error
    }
  }

  // Add the missing _saveNotification method
  Future<void> _saveNotification(String text, DateTime timestamp) async {
    try {
      print('Saving notification: $text');
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      final String? notificationsJson = prefs.getString('notifications');
      final List<dynamic> notificationsList = notificationsJson != null
          ? json.decode(notificationsJson)
          : [];

      // Add the new notification
      notificationsList.add({
        'id': timestamp.millisecondsSinceEpoch,
        'text': text,
        'isUser': false,
        'timestamp': timestamp.toIso8601String(),
        'isAudio': false,
      });

      // Keep only the last 50 notifications
      if (notificationsList.length > 50) {
        notificationsList.removeRange(0, notificationsList.length - 50);
      }

      await prefs
          .setString('notifications', json.encode(notificationsList))
          .timeout(
            Duration(seconds: 5),
            onTimeout: () {
              print('Saving notifications timed out');
              throw TimeoutException(
                'Save notifications timeout',
                Duration(seconds: 5),
              );
            },
          );
      print(
        'Notification saved successfully. Total notifications: ${notificationsList.length}',
      );
    } catch (e) {
      print('Error saving notification: $e');
      // Continue without saving if there's an error
    }
  }

  // Add the missing _showLocalNotification method
  Future<void> _showLocalNotification(String notificationText) async {
    try {
      print('Showing local notification: $notificationText');
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
            'toggle_talk_notification_channel', // channel id
            'ToggleTalk Notifications', // channel name
            channelDescription:
                'Notifications from ToggleTalk server', // channel description
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'Ticker',
          );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: DarwinNotificationDetails(),
      );

      await flutterLocalNotificationsPlugin
          .show(
            DateTime.now().millisecondsSinceEpoch ~/ 1000, // notification id
            'ToggleTalk Notification', // title
            notificationText, // body
            platformChannelSpecifics,
            payload: 'notification_payload',
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('Local notification timed out');
              throw TimeoutException(
                'Local notification timeout',
                Duration(seconds: 10),
              );
            },
          );
      print('Local notification shown successfully');
    } catch (e) {
      print('Error showing local notification: $e');
      // Continue without showing notification if there's an error
    }
  }

  /// Test network connectivity to our server API
  Future<bool> _testNetworkConnectivity() async {
    try {
      final url = Uri.parse('$SERVER_API_URL/health');
      final response = await http.get(url).timeout(Duration(seconds: 10));
      print('Network test response status: ${response.statusCode}');
      print('Network test response body: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Network test failed: $e');
      return false;
    }
  }

  /// Toggle appliance from home widget
  Future<void> _toggleApplianceFromWidget(
    String appliance,
    bool newValue,
  ) async {
    // Send command to server
    final success = await HomeWidgetService.sendCommand(
      appliance,
      newValue,
      _userName,
    );

    if (success) {
      // Update local widget state
      setState(() {
        switch (appliance) {
          case 'light':
            _homeWidgetLightOn = newValue;
            break;
          case 'ac':
            _homeWidgetAcOn = newValue;
            break;
          case 'washing_machine':
            _homeWidgetWashingMachineOn = newValue;
            break;
        }
      });

      // Update home widget UI
      final states = {
        'light': _homeWidgetLightOn,
        'ac': _homeWidgetAcOn,
        'washing_machine': _homeWidgetWashingMachineOn,
      };
      await HomeWidgetService.updateWidgetUI(states, _userName);
    } else {
      // Show error feedback to user
      print('Failed to toggle $appliance from widget');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Check if this is a command to show current chat ID
    if (text.trim() == '/showchatid') {
      final chatIdMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        text: "Current Chat ID: $AUTHORIZED_CHAT_ID",
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(chatIdMsg);
        _textController.clear();
      });

      _scrollToBottom();
      _saveMessages();
      return;
    }

    // Check if this is a help command
    if (text.trim() == '/help') {
      final helpMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        text:
            "Available commands:\n"
            "/showchatid - Show the current chat ID\n"
            "/testnotification - Test notification system\n"
            "/help - Show this help message\n\n"
            "Note: This app now communicates with the ToggleTalk server via API.\n"
            "Make sure your server is running and accessible.",
        isUser: false,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(helpMsg);
        _textController.clear();
      });

      _scrollToBottom();
      _saveMessages();
      return;
    }

    // Check if this is a test notification command
    if (text.trim() == '/testnotification') {
      final testNotificationText = "This is a test notification";
      final timestamp = DateTime.now();

      // Save notification to shared preferences
      _saveNotification(testNotificationText, timestamp);

      // Show local notification
      _showLocalNotification(testNotificationText);

      final confirmationMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch,
        text: "Test notification sent and saved successfully!",
        isUser: false,
        timestamp: timestamp,
      );

      setState(() {
        _messages.add(confirmationMsg);
        _textController.clear();
      });

      _scrollToBottom();
      _saveMessages();
      return;
    }

    // Generate a unique ID for the user message
    final userMessageId = DateTime.now().millisecondsSinceEpoch;

    // Add user message to UI immediately
    final userMsg = Message(
      id: userMessageId,
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _textController.clear(); // Clear the text field
      _isLoading = true;
    });

    _scrollToBottom();
    _saveMessages();

    try {
      // Send message to our server API instead of directly to Telegram
      final url = Uri.parse('$SERVER_API_URL/send_message');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': text,
              'user_name': _userName,
              'user_id': _uniqueUserId, // Use unique user ID for tracking
            }),
          )
          .timeout(Duration(seconds: 15));

      print('Send message response status: ${response.statusCode}');
      print('Send message response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success' && data['response'] != null) {
          // Add server response to chat
          setState(() {
            _messages.add(
              Message(
                id: DateTime.now().millisecondsSinceEpoch,
                text: data['response'],
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isLoading = false;
          });
          _scrollToBottom();
          _saveMessages();

          // Show success feedback
          if (mounted) {}
        } else {
          // Handle error response from server
          setState(() {
            _messages.add(
              Message(
                id: DateTime.now().millisecondsSinceEpoch,
                text: 'Server error: ${data['error'] ?? 'Unknown error'}',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            _isLoading = false;
          });
          _scrollToBottom();
          _saveMessages();
        }
      } else {
        // Handle HTTP error
        print('Failed to send message. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');

        setState(() {
          _messages.add(
            Message(
              id: DateTime.now().millisecondsSinceEpoch,
              text:
                  'Failed to connect to server. Please check your connection and make sure the server is running.',
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
        _saveMessages();
      }
    } catch (e) {
      print('Error sending message: $e');
      // Handle network error
      setState(() {
        _messages.add(
          Message(
            id: DateTime.now().millisecondsSinceEpoch,
            text: 'Network error. Please check your connection. Error: $e',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        _isLoading = false;
      });
      _scrollToBottom();
      _saveMessages();
    }
  }

  // Speech to text methods
  void _startListening() async {
    try {
      // Check microphone permission before starting speech recognition with timeout
      final micStatus = await Permission.microphone.status.timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('Microphone permission check timed out');
          return Future.value(PermissionStatus.denied);
        },
      );
      if (micStatus != PermissionStatus.granted) {
        // Request permission with timeout
        final requestedStatus = await Permission.microphone.request().timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('Microphone permission request timed out');
            return Future.value(PermissionStatus.denied);
          },
        );
        if (requestedStatus != PermissionStatus.granted) {
          // Show a message to the user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Microphone permission is required for speech recognition',
                ),
                action: SnackBarAction(
                  label: 'Settings',
                  onPressed: () {
                    openAppSettings();
                  },
                ),
              ),
            );
          }
          return;
        }
      }

      if (!_isListening) {
        bool available = await _speechToText
            .initialize(
              onStatus: (status) {
                print('Speech recognition status: $status');
                // Update UI based on status
                if (status == 'listening') {
                  setState(() {
                    _isListening = true;
                  });
                } else if (status == 'notListening' || status == 'done') {
                  // Speech recognition has stopped, update UI accordingly
                  setState(() {
                    _isListening = false;
                    _transcribedText = '';
                  });
                }
              },
              onError: (error) {
                print('Speech recognition error: $error');
                // Show error message to user
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Speech recognition Problem.'),
                    backgroundColor: Colors.red,
                  ),
                );
                setState(() {
                  _isListening = false;
                });
              },
            )
            .timeout(
              Duration(seconds: 10),
              onTimeout: () {
                print('Speech recognition initialization timed out');
                throw TimeoutException(
                  'Speech recognition timeout',
                  Duration(seconds: 10),
                );
              },
            );

        if (available) {
          setState(() => _isListening = true);
          _speechToText.listen(
            onResult: (result) {
              setState(() {
                _transcribedText = result.recognizedWords;
                // Update text field with partial results only while listening
                // But don't automatically send - user must tap send button
                _textController.text = _transcribedText;
                // Move cursor to end of text
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              });
            },
          );
        } else {
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition not available'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Stop listening when user taps mic button again
        setState(() => _isListening = false);
        await _speechToText.stop().timeout(
          Duration(seconds: 5),
          onTimeout: () {
            print('Speech recognition stop timedout');
            return Future.value();
          },
        );

        // Don't automatically send the transcribed text
        // Only clear the temporary transcribed text variable
        setState(() {
          _transcribedText = '';
          // Do NOT clear the text field - user may want to edit or send it
        });
      }
    } catch (e) {
      print('Error in speech recognition: $e');
      // Handle error gracefully
      setState(() {
        _isListening = false;
        _transcribedText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Speech recognition Problem.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildMessage(Message message) {
    final isUser = message.isUser;
    // Changed to light yellow for user and light green for bot
    final backgroundColor = isUser ? Colors.yellow[200] : Colors.green[200];
    final textColor = isUser ? Colors.black87 : Colors.black87;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) // Bot avatar with custom icon
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: const CircularBotIcon(
                    size: 16.0,
                    backgroundColor:
                        Colors.transparent, // Use transparent background
                  ),
                ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: message.isAudio
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.audio_file,
                              color: Colors.black87,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Audio Message',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontFamily:
                                    'PlaywriteUSModern', // Custom font for audio messages
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.play_arrow,
                              color: Colors.black87,
                              size: 20,
                            ),
                          ],
                        )
                      : Text(
                          message.text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontFamily: isUser
                                ? 'PlaywriteUSModern'
                                : 'Comfortaa', // Different fonts for user and bot
                          ),
                        ),
                ),
              ),
              if (isUser) // User avatar
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        Colors.yellow[300], // Changed to light yellow
                    child: Text(
                      'U',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontFamily:
                            'BungeeOutline', // Custom font for user avatar
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Timestamp with custom font
        Container(
          margin: EdgeInsets.only(
            left: isUser ? 0 : 48,
            right: isUser ? 48 : 0,
            bottom: 8,
          ),
          child: Text(
            '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontFamily: 'RubikPuddles', // Custom font for timestamps
            ),
          ),
        ),
      ],
    );
  }

  // Main app UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ToggleTalk',
          style: TextStyle(
            fontFamily: 'BungeeOutline', // Custom font for app title
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Colors.black, // Changed to black for better contrast
          ),
        ),
        backgroundColor: Colors.yellow[300], // Changed to light yellow
        foregroundColor: Colors.black,
        // Add the bot icon to the app bar for better branding
        leading: DescribedFeatureOverlay(
          featureId: 'profile_icon',
          tapTarget: const Icon(Icons.person),
          title: Text('Your Profile'),
          description: Text('Tap here to set your name '),
          child: IconButton(
            icon: const CircularBotIcon(
              size: 20.0,
              backgroundColor: Colors.transparent, // Use transparent background
            ),
            onPressed: () {
              // Navigate to profile page when tapping the bot icon
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    onNameUpdated: (newName) {
                      // Refresh the username when it's updated in the profile
                      _refreshUserName();
                    },
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // Navigate to notification screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              _saveMessages();
              _sendWelcomeMessage();
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg/background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[100]?.withOpacity(
                  0.0,
                ), // Make container transparent to show background
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessage(_messages[index]);
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Container(
                  constraints: BoxConstraints(maxWidth: 600), // Limit max width
                  child: Row(
                    children: [
                      // Speech to text button with pulse animation
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_isListening)
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          DescribedFeatureOverlay(
                            featureId: 'mic_icon',
                            tapTarget: const Icon(Icons.mic),
                            title: Text('Voice Messages'),
                            description: Text(
                              'Tap and hold to record voice messages',
                            ),
                            child: IconButton(
                              iconSize: 28,
                              icon: Icon(
                                _isListening ? Icons.mic_off : Icons.mic,
                                color: _isListening
                                    ? Colors.red
                                    : Colors.yellow[700], // Changed to yellow
                              ),
                              onPressed: _startListening,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? 'Listening...'
                                : 'Type a message...',
                            hintStyle: TextStyle(
                              fontFamily:
                                  'Comfortaa', // Custom font for hint text
                              color: _isListening ? Colors.red : null,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(30),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: TextStyle(
                            fontFamily:
                                'Comfortaa', // Custom font for input text
                          ),
                          onSubmitted: (text) {
                            if (text.trim().isNotEmpty) {
                              _sendMessage(text);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      DescribedFeatureOverlay(
                        featureId: 'send_icon',
                        tapTarget: const Icon(Icons.send),
                        title: Text('Send Messages'),
                        description: Text(
                          'Tap to send your text or voice message',
                        ),
                        child: FloatingActionButton(
                          onPressed: () {
                            final text = _textController.text;
                            if (text.trim().isNotEmpty) {
                              // If speech recognition is active, stop it first
                              if (_isListening) {
                                _speechToText.stop();
                                setState(() {
                                  _isListening = false;
                                  _transcribedText = '';
                                });
                              }
                              _sendMessage(text);
                            }
                          },
                          backgroundColor: Colors
                              .transparent, // Made transparent as requested
                          elevation: 0, // Remove shadow
                          shape: CircleBorder(), // Make it a true circle
                          child: _isLoading
                              ? SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add a method to fetch events from the server
  Future<List<Map<String, dynamic>>> _fetchEventsFromServer() async {
    try {
      print('Fetching events from server...');

      // Fetch events from the server API
      final url = Uri.parse('$SERVER_API_URL/get_events');
      final response = await http.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data['status'] == 'success' && data['events'] != null) {
          print('Events fetched from server successfully');
          return List<Map<String, dynamic>>.from(data['events']);
        } else {
          print('Failed to parse events from server response');
        }
      } else {
        print('Failed to fetch events. Status: ${response.statusCode}');
      }

      return [];
    } catch (e) {
      print('Error fetching events from server: $e');
      return [];
    }
  }

  // Add a method to refresh the username from SharedPreferences
  Future<void> _refreshUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('SharedPreferences initialization timed out');
          throw TimeoutException(
            'SharedPreferences timeout',
            Duration(seconds: 5),
          );
        },
      );
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
      });
      print('Username refreshed: $_userName');

      // Also update the home widget with the new username
      await HomeWidgetService.updateUserName(_userName);
    } catch (e) {
      print('Error refreshing username: $e');
      // Keep current username if there's an error
    }
  }

  /// Start the feature discovery walkthrough
  Future<void> _startFeatureDiscovery() async {
    try {
      // Wait a bit for the UI to settle
      await Future.delayed(Duration(milliseconds: 500));

      // Start the feature discovery walkthrough
      FeatureDiscovery.discoverFeatures(context, const [
        'mic_icon',
        'send_icon',
        'profile_icon',
      ]);

      // Wait for feature discovery to complete and then navigate to profile
      // Assuming feature discovery takes about 3 seconds per feature with some buffer
      Future.delayed(Duration(seconds: 9), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePage(
                onNameUpdated: (newName) {
                  // Refresh the username when it's updated in the profile
                  _refreshUserName();
                },
              ),
            ),
          );
        }
      });
    } catch (e) {
      print('Error starting feature discovery: $e');
    }
  }
}
