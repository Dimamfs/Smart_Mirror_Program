import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

class AlertProvider with ChangeNotifier {
  List<Alert> _alert = [];

  List<Alert> get alerts => _alert;

  // The constructor automatically loads alerts from the hard drive when the app starts
  AlertProvider() {
    loadAlerts();
  }

  // Reads from SharedPreferences
  Future<void> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAlerts = prefs.getStringList('alerts') ?? [];

    _alert = savedAlerts.map((alertStr) {
      final data = jsonDecode(alertStr);
      return Alert(
        id: data['id'],
        title: data['title'],
        body: data['body'],
        timestamp: DateTime.parse(data['timestamp']),
      );
    }).toList();

    // Tell the AlertScreen to redraw with the loaded data
    notifyListeners();
  }

  // Adds a new alert and saves the updated list to SharedPreferences
  Future<void> addAlert(String title, String body) async {
    final newAlert = Alert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    
    // Add to the TOP of the list (index 0) so newest is first
    _alert.insert(0, newAlert);
    notifyListeners();
    
    // Save to hard drive
    await _saveToStorage();
  }

  // Clears the UI list and wipes the SharedPreferences data
  Future<void> clearAlert() async {
    _alert.clear();
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('alerts');
  }

  // Helper method to convert the list of Alerts back into JSON strings for storage
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = _alert.map((a) => jsonEncode({
      'id': a.id,
      'title': a.title,
      'body': a.body,
      'timestamp': a.timestamp.toIso8601String(),
    })).toList();
    
    await prefs.setStringList('alerts', encodedList);
  }
}