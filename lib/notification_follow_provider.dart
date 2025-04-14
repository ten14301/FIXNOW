import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Notification_FollowProvider extends ChangeNotifier {
  bool _hasFollowNotification = false;

  bool get hasFollowNotification => _hasFollowNotification;

  // ดึงค่าสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> loadFollowNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasFollowNotification = prefs.getBool('hasFollowNotification') ?? false;
    notifyListeners();
  }

  // ตั้งค่าสถานะการแจ้งเตือนและบันทึกลงใน SharedPreferences
  Future<void> setFollowNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasFollowNotification = value;
    prefs.setBool('hasFollowNotification', value);
    notifyListeners();
  }

  // ลบสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> clearFollowNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasFollowNotification = false;
    prefs.remove('hasFollowNotification');
    notifyListeners();
  }
}
