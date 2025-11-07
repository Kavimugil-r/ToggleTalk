import 'package:home_widget/home_widget.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HomeWidgetService {
  static const String SERVER_API_URL = String.fromEnvironment(
    'SERVER_API_URL',
    defaultValue: 'http://192.168.244.80:7850/api',
  );

  static const int AUTHORIZED_CHAT_ID = int.fromEnvironment(
    'AUTHORIZED_CHAT_ID',
    defaultValue: 1767023771,
  );

  // Generate a unique user ID for each app instance
  static final int _uniqueUserId = DateTime.now().millisecondsSinceEpoch;

  /// Initialize the home widget
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId('com.toggletalk.widget');
      // Don't call _updateWidgetData here as it might not have the correct user name yet
      // The widget data will be updated when the user name is loaded
    } catch (e) {
      print('Error initializing home widget: $e');
    }
  }

  /// Update widget data with current appliance states
  static Future<void> _updateWidgetData() async {
    try {
      // Load user name
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString('user_name') ?? 'User';

      // Update widget data
      await HomeWidget.saveWidgetData<String>('user_name', userName);
      await HomeWidget.updateWidget(
        iOSName: 'ToggleTalkWidget',
        androidName: 'ToggleTalkWidget',
      );
    } catch (e) {
      print('Error updating widget data: $e');
    }
  }

  /// Update the user name in the widget
  static Future<void> updateUserName(String userName) async {
    try {
      await HomeWidget.saveWidgetData<String>('user_name', userName);
      await HomeWidget.updateWidget(
        iOSName: 'ToggleTalkWidget',
        androidName: 'ToggleTalkWidget',
      );
      print('User name updated in widget: $userName');

      // Also update the SharedPreferences to ensure consistency
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', userName);
    } catch (e) {
      print('Error updating user name in widget: $e');
    }
  }

  /// Send command to server to control an appliance
  static Future<bool> sendCommand(
    String appliance,
    bool turnOn,
    String userName,
  ) async {
    try {
      final url = Uri.parse('$SERVER_API_URL/send_message');
      final action = turnOn ? 'on' : 'off';
      final message = 'Turn $action the $appliance';

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': message,
              'user_name': userName,
              'user_id': _uniqueUserId,
            }),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Update widget to reflect the change
          await _updateApplianceState(appliance, turnOn);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error sending command: $e');
      return false;
    }
  }

  /// Update the appliance state in the widget
  static Future<void> _updateApplianceState(String appliance, bool isOn) async {
    try {
      await HomeWidget.saveWidgetData<bool>('${appliance}_is_on', isOn);
      await HomeWidget.updateWidget(
        iOSName: 'ToggleTalkWidget',
        androidName: 'ToggleTalkWidget',
      );
    } catch (e) {
      print('Error updating appliance state: $e');
    }
  }

  /// Load appliance states from the widget
  static Future<Map<String, bool>> getApplianceStates() async {
    final Map<String, bool> states = {};
    try {
      states['light'] =
          await HomeWidget.getWidgetData<bool>('light_is_on') ?? false;
      states['ac'] = await HomeWidget.getWidgetData<bool>('ac_is_on') ?? false;
      states['washing_machine'] =
          await HomeWidget.getWidgetData<bool>('washing_machine_is_on') ??
          false;
    } catch (e) {
      print('Error loading appliance states: $e');
    }
    return states;
  }

  /// Update widget UI with specific appliance states
  static Future<void> updateWidgetUI(
    Map<String, bool> states,
    String userName,
  ) async {
    try {
      // Save states to widget
      if (states.containsKey('light')) {
        await HomeWidget.saveWidgetData<bool>('light_is_on', states['light']!);
      }
      if (states.containsKey('ac')) {
        await HomeWidget.saveWidgetData<bool>('ac_is_on', states['ac']!);
      }
      if (states.containsKey('washing_machine')) {
        await HomeWidget.saveWidgetData<bool>(
          'washing_machine_is_on',
          states['washing_machine']!,
        );
      }

      // Save user name
      await HomeWidget.saveWidgetData<String>('user_name', userName);

      // Update widget
      await HomeWidget.updateWidget(
        iOSName: 'ToggleTalkWidget',
        androidName: 'ToggleTalkWidget',
      );
    } catch (e) {
      print('Error updating widget UI: $e');
    }
  }
}
