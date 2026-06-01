import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Alerts'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () {
              Provider.of<AlertProvider>(context, listen: false).clearAlert();
            },
          )
        ],
      ),
      // Consumer listens to AlertProvider and rebuilds only this widget when data changes
      body: Consumer<AlertProvider>(
        builder: (context, alertProvider, child) {
          // FIX: Renamed this variable to 'alerts' (plural) to avoid the shadowing error
          final alerts = alertProvider.alerts;

          if (alerts.isEmpty) {
            return const Center(
              child: Text(
                'No alerts yet. Everything is secure.',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              // FIX: Now 'alert' grabs an individual item from the 'alerts' list
              final alert = alerts[index];
              
              // Format the time nicely (e.g., "14:30")
              final timeString = "${alert.timestamp.hour.toString().padLeft(2, '0')}:${alert.timestamp.minute.toString().padLeft(2, '0')}";

              return Card(
                color: Colors.grey.shade900,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.redAccent),
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(alert.body),
                  trailing: Text(
                    timeString,
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}