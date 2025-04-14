import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationAnnounceFetch extends ChangeNotifier {
  bool _hasMaintenanceNotification = false;

  bool get hasMaintenanceNotification => _hasMaintenanceNotification;

  // ดึงค่าสถานะการแจ้งเตือนจาก SharedPreferences และรีเซ็ตเป็น false
  Future<void> loadMaintenanceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = prefs.getBool('hasMaintenanceNotification') ?? false;

    if (_hasMaintenanceNotification) {
      await clearMaintenanceNotification(); 
    } else {
      notifyListeners();
    }
  }

  Future<void> setMaintenanceNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = value;
    await prefs.setBool('hasMaintenanceNotification', value);
    notifyListeners();
    if (value) {
      Future.delayed(Duration(seconds: 5), () async {
        await clearMaintenanceNotification();
      });
    }
  }

  // ลบสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> clearMaintenanceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasMaintenanceNotification = false;
    await prefs.remove('hasMaintenanceNotification');
    notifyListeners();
  }
}
