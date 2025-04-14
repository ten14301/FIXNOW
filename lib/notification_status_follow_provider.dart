import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationFollowProvider extends ChangeNotifier {
  bool _hasStatusFollowNotification = false;
  Map<String, bool> _statusFollowMessages = {};

  bool get hasStatusFollowNotification => _hasStatusFollowNotification;
  Map<String, bool> get statusFollowMessages => _statusFollowMessages;

  // ดึงค่าเริ่มต้นจาก SharedPreferences
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusFollowNotification = prefs.getBool('hasStatusFollowNotification') ?? false;

    // ดึงค่าทั้งหมดจาก SharedPreferences ถ้ามี
    Map<String, bool> statusMessages = {};
    for (int i = 0; i < prefs.getKeys().length; i++) {
      String? key = prefs.getKeys().elementAt(i);
      if (key != null && key.startsWith('statusFollowMessage_')) {
        statusMessages[key] = prefs.getBool(key) ?? false;
      }
    }
    _statusFollowMessages = statusMessages;
    notifyListeners();
  }

  // บันทึกสถานะการแจ้งเตือน
  Future<void> setStatusFollowNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusFollowNotification = value;
    prefs.setBool('hasStatusFollowNotification', value);
    notifyListeners();
  }

  // ลบสถานะการแจ้งเตือน
  Future<void> clearStatusFollowNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusFollowNotification = false;
    prefs.remove('hasStatusFollowNotification');
    notifyListeners();
  }

  // บันทึกสถานะการติดตามสำหรับข้อความ
  Future<void> setStatusFollowMessage(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    _statusFollowMessages[requestId] = true;
    prefs.setBool('statusFollowMessage_$requestId', true);
    notifyListeners();
  }

  // ลบสถานะการติดตามสำหรับข้อความ
  Future<void> removeStatusFollowMessage(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    _statusFollowMessages[requestId] = false;
    prefs.setBool('statusFollowMessage_$requestId', false);
    notifyListeners();
  }

  // ล้างสถานะการติดตามทั้งหมด
  Future<void> clearStatusFollowMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _statusFollowMessages.forEach((key, value) {
      prefs.remove('statusFollowMessage_$key');
    });
    _statusFollowMessages.clear();
    notifyListeners();
  }
}
