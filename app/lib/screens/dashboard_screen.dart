import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // These variables hold the current "state" of the mirror widgets
  bool _showClock = true;
  bool _showWeather = true;
  bool _showCalendar = false;
  bool _showNews = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Active Widgets',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Toggle what appears on your Smart Mirror.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Clock Toggle
        Card(
          child: SwitchListTile(
            title: const Text('Clock'),
            subtitle: const Text('Display the current time and date.'),
            value: _showClock,
            activeColor: Colors.blueAccent,
            onChanged: (bool value) {
              setState(() {
                _showClock = value;
              });
            },
          ),
        ),

        // Weather Toggle
        Card(
          child: SwitchListTile(
            title: const Text('Weather'),
            subtitle: const Text('Show local temperature and forecast.'),
            value: _showWeather,
            activeColor: Colors.blueAccent,
            onChanged: (bool value) {
              setState(() {
                _showWeather = value;
              });
            },
          ),
        ),

        // Calendar Toggle
        Card(
          child: SwitchListTile(
            title: const Text('Calendar'),
            subtitle: const Text('Sync upcoming events and reminders.'),
            value: _showCalendar,
            activeColor: Colors.blueAccent,
            onChanged: (bool value) {
              setState(() {
                _showCalendar = value;
              });
            },
          ),
        ),
      ],
    );
  }
}