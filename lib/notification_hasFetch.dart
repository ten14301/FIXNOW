import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationHasProvider extends ChangeNotifier {
  bool _hasMaintenanceNotification = false;

  bool get hasMaintenanceNotification => _hasMaintenanceNotification;

  // ดึงค่าสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> loadMaintenanceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = prefs.getBool('hasMaintenanceNotification') ?? false;
    notifyListeners();
  }

  // ตั้งค่าสถานะการแจ้งเตือนและบันทึกลงใน SharedPreferences
  Future<void> setMaintenanceNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = value;
    prefs.setBool('hasMaintenanceNotification', value);
    notifyListeners();
  }

  // ลบสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> clearMaintenanceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = false;
    prefs.remove('hasMaintenanceNotification');
    notifyListeners();
  }
}
