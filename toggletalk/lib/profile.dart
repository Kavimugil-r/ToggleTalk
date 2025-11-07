import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'home_widget_service.dart';

class ProfilePage extends StatefulWidget {
  final Function(String)? onNameUpdated; // Add callback for name updates

  const ProfilePage({super.key, this.onNameUpdated});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final TextEditingController _nameController = TextEditingController();
  String _userName = 'User';
  bool _isNameChanged = false;
  bool _isNameSaved = false; // Track if name has been saved

  @override
  void initState() {
    super.initState();
    _loadUserName();

    // Add listener to the text controller to track changes
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    // Remove listener when disposing
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _userName = prefs.getString('user_name') ?? 'User';
        _nameController.text = _userName;
        _isNameChanged = false; // Reset change flag
        _isNameSaved =
            _userName != 'User'; // If name is not default, consider it saved
      });
    } catch (e) {
      print('Error loading username: $e');
      // Use default values if there's an error
      setState(() {
        _userName = 'User';
        _nameController.text = _userName;
        _isNameChanged = false;
        _isNameSaved = false;
      });
    }
  }

  void _onNameChanged() {
    setState(() {
      // Check if the name has actually changed from the original
      _isNameChanged =
          _nameController.text.trim() != _userName &&
          _nameController.text.trim().isNotEmpty;
    });
  }

  Future<void> _saveUserName() async {
    final trimmedName = _nameController.text.trim();

    // Validate that name is not empty
    if (trimmedName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Name cannot be empty!')));
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', trimmedName);
      setState(() {
        _userName = trimmedName;
        _isNameChanged = false; // Reset change flag after saving
        _isNameSaved = true; // Mark name as saved
      });

      // Update home widget with new user name
      print('Updating widget with new user name: $trimmedName');
      await HomeWidgetService.updateUserName(trimmedName);

      // Notify the parent widget (main app) about the name update
      widget.onNameUpdated?.call(trimmedName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Name saved successfully!')),
        );
      }
    } catch (e) {
      print('Error saving username: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving name: $e')));
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_isNameSaved) {
      // Name has been saved, allow popping
      return true;
    } else {
      // Name not saved, show confirmation dialog
      return (await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Name Not Saved'),
              content: const Text(
                'Please enter and save your name before leaving this page.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('OK'),
                ),
              ],
            ),
          )) ??
          false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.yellow[300],
          foregroundColor: Colors.black,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            // Wrap with SingleChildScrollView to prevent pixel loss
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Profile',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Name:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter your name',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isNameChanged
                      ? _saveUserName
                      : null, // Disable button when no changes
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[300],
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Save Name'),
                ),
                const SizedBox(height: 30),
                const Text(
                  'About ToggleTalk',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'ToggleTalk is a smart home automation system that allows you to control your appliances through API commands. '
                  'When any user sends a command to control an appliance, all users will receive a notification about the action.',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
