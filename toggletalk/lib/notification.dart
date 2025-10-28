import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Fix the import to properly access the CircularBotIcon widget
import 'main.dart' show CircularBotIcon;

class Message {
  final int id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isAudio;

  Message({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isAudio = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      text: json['text'],
      isUser: json['isUser'],
      timestamp: DateTime.parse(json['timestamp']),
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

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with WidgetsBindingObserver {
  final List<Message> _notifications = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Add observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Remove observer when disposing
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh notifications when app resumes
      _loadNotifications();
    }
  }

  Future<void> _loadNotifications() async {
    print('Loading notifications...');
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notifications');

    if (notificationsJson != null) {
      try {
        final List<dynamic> notificationsList = json.decode(notificationsJson);
        print('Found ${notificationsList.length} notifications');
        setState(() {
          _notifications.clear();
          for (var notification in notificationsList) {
            _notifications.add(Message.fromJson(notification));
          }
        });
        _scrollToBottom();
        print('Notifications loaded successfully');
      } catch (e) {
        print('Error loading notifications: $e');
      }
    } else {
      print('No notifications found in shared preferences');
    }
  }

  Future<void> _refreshNotifications() async {
    print('Refreshing notifications...');
    await _loadNotifications();
  }

  // Add a new notification to the list
  Future<void> addNotification(String text) async {
    final timestamp = DateTime.now();
    final newNotification = Message(
      id: timestamp.millisecondsSinceEpoch,
      text: text,
      isUser: false,
      timestamp: timestamp,
    );

    setState(() {
      _notifications.add(newNotification);
    });

    // Save to shared preferences
    await _saveNotificationToStorage(newNotification);
    _scrollToBottom();
  }

  // Save notification to shared preferences
  Future<void> _saveNotificationToStorage(Message notification) async {
    final prefs = await SharedPreferences.getInstance();
    final String? notificationsJson = prefs.getString('notifications');
    final List<dynamic> notificationsList = notificationsJson != null
        ? json.decode(notificationsJson)
        : [];

    // Add the new notification
    notificationsList.add(notification.toJson());

    // Keep only the last 50 notifications
    if (notificationsList.length > 50) {
      notificationsList.removeRange(0, notificationsList.length - 50);
    }

    prefs.setString('notifications', json.encode(notificationsList));
    print(
      'Notification saved successfully. Total notifications: ${notificationsList.length}',
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.yellow[300],
        foregroundColor: Colors.black,
        // Add a refresh button
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.refresh),
          //   onPressed: _refreshNotifications,
          // ),
        ],
        // Replace the back button with the bot icon for consistency
        // We'll add the back functionality to the bot icon
        leading: IconButton(
          icon: const CircularBotIcon(
            size: 20.0,
            backgroundColor: Colors.transparent, // Use transparent background
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                // Replace the generic notification icon with the custom CircularBotIcon
                                child: const CircularBotIcon(
                                  size: 16.0,
                                  backgroundColor: Colors
                                      .transparent, // Use transparent background
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification.text,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Comfortaa',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${notification.timestamp.hour}:${notification.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                          fontFamily: 'RubikPuddles',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
