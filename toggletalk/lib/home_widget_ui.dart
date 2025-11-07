import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'home_widget_service.dart';

class ToggleTalkHomeWidget extends StatefulWidget {
  @override
  _ToggleTalkHomeWidgetState createState() => _ToggleTalkHomeWidgetState();
}

class _ToggleTalkHomeWidgetState extends State<ToggleTalkHomeWidget> {
  bool _lightOn = false;
  bool _acOn = false;
  String _userName = 'User';
  bool _washingMachineOn = false;

  @override
  void initState() {
    super.initState();
    _loadWidgetData();

    // Add a listener for widget updates
    HomeWidget.widgetClicked.listen((uri) async {
      // Reload data when widget is clicked/updated
      await _loadWidgetData();
    });
  }

  Future<void> _loadWidgetData() async {
    try {
      // Load user name
      final userName = await HomeWidget.getWidgetData<String>('user_name');
      if (userName != null) {
        setState(() {
          _userName = userName;
        });
      }

      // Load appliance states
      final lightOn =
          await HomeWidget.getWidgetData<bool>('light_is_on') ?? false;
      final acOn = await HomeWidget.getWidgetData<bool>('ac_is_on') ?? false;
      final washingMachineOn =
          await HomeWidget.getWidgetData<bool>('washing_machine_is_on') ??
          false;

      setState(() {
        _lightOn = lightOn;
        _acOn = acOn;
        _washingMachineOn = washingMachineOn;
      });

      print(
        'Widget data loaded - User: $_userName, Light: $_lightOn, AC: $_acOn, Washing Machine: $_washingMachineOn',
      );
    } catch (e) {
      print('Error loading widget data: $e');
    }
  }

  Future<void> _toggleAppliance(String appliance, bool newValue) async {
    // Send command to server first
    final success = await HomeWidgetService.sendCommand(
      appliance,
      newValue,
      _userName,
    );

    if (success) {
      // Update local state only if command was successful
      setState(() {
        switch (appliance) {
          case 'light':
            _lightOn = newValue;
            break;
          case 'ac':
            _acOn = newValue;
            break;
          case 'washing_machine':
            _washingMachineOn = newValue;
            break;
        }
      });

      // Also update the widget UI to reflect the change
      final states = {
        'light': _lightOn,
        'ac': _acOn,
        'washing_machine': _washingMachineOn,
      };
      await HomeWidgetService.updateWidgetUI(states, _userName);
    } else {
      // Show error feedback to user
      print('Failed to toggle $appliance');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300, // 2:1 ratio (300x150)
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Header with app name
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.yellow[700],
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'ToggleTalk',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Appliance controls using ON/OFF widget images
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImageToggleButton(
                'Light',
                'assets/icons/LightONWidget.png',
                'assets/icons/LightOFFWidget.png',
                _lightOn,
                () => _toggleAppliance('light', !_lightOn),
              ),
              _buildImageToggleButton(
                'AC',
                'assets/icons/ACONWidget.png',
                'assets/icons/ACOFFWidget.png',
                _acOn,
                () => _toggleAppliance('ac', !_acOn),
              ),
              _buildImageToggleButton(
                'Washing',
                'assets/icons/WashingMachineONWidget.png',
                'assets/icons/WashingMachineOFFWidget.png',
                _washingMachineOn,
                () => _toggleAppliance('washing_machine', !_washingMachineOn),
              ),
            ],
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildImageToggleButton(
    String name,
    String onImage,
    String offImage,
    bool isOn,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Image.asset(
              isOn ? onImage : offImage,
              width: 48,
              height: 48,
              fit: BoxFit.contain,
            ),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isOn ? FontWeight.bold : FontWeight.normal,
            color: isOn ? Colors.yellow[700] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
