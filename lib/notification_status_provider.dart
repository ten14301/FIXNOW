import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationStatusProvider extends ChangeNotifier {
  bool _hasStatusNotification = false;
  Map<String, bool> _statusMessages = {};

  bool get hasChatNotification => _hasStatusNotification;
  Map<String, bool> get statusMessages => _statusMessages;

  // ดึงค่าเริ่มต้นจาก SharedPreferences
  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusNotification = prefs.getBool('hasStatusNotification') ?? false;

    // ดึงค่าทั้งหมดจาก SharedPreferences ถ้ามี
    Map<String, bool> statusMessages = {};
    for (int i = 0; i < prefs.getKeys().length; i++) {
      String? key = prefs.getKeys().elementAt(i);
      if (key != null && key.startsWith('statusMessage_')) {
        statusMessages[key] = prefs.getBool(key) ?? false;
      }
    }
    _statusMessages = statusMessages;
    notifyListeners();
  }

  // บันทึกสถานะการแจ้งเตือน
  Future<void> setStatusNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusNotification = value;
    prefs.setBool('hasStatusNotification', value);
    notifyListeners();
  }

  // ลบสถานะการแจ้งเตือน
  Future<void> clearStatusNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasStatusNotification = false;
    prefs.remove('hasStatusNotification');
    notifyListeners();
  }

  // บันทึกสถานะข้อความ
  Future<void> setStatusMessage(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    _statusMessages[requestId] = true;
    prefs.setBool('statusMessage_$requestId', true);
    notifyListeners();
  }

  // ลบสถานะข้อความ
  Future<void> removeStatusMessage(String requestId) async {
    final prefs = await SharedPreferences.getInstance();
    _statusMessages[requestId] = false;
    prefs.setBool('statusMessage_$requestId', false);
    notifyListeners();
  }

  // ล้างสถานะข้อความทั้งหมด
  Future<void> clearStatusMessages() async {
    final prefs = await SharedPreferences.getInstance();
    _statusMessages.forEach((key, value) {
      prefs.remove('statusMessage_$key');
    });
    _statusMessages.clear();
    notifyListeners();
  }
}
