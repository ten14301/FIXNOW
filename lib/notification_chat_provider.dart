import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';


class NotificationChatProvider extends ChangeNotifier {
  bool _hasChatNotification = false;
  Map<String, bool> _chatMessages = {};

  bool get hasChatNotification => _hasChatNotification;
  Map<String, bool> get chatMessages => _chatMessages;

  // ดึงค่าสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> loadChatNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasChatNotification = prefs.getBool('hasChatNotification') ?? false;
    // โหลดข้อมูลข้อความจาก SharedPreferences
    final chatMessages = prefs.getString('chatMessages');
    if (chatMessages != null) {
      _chatMessages = Map<String, bool>.from(jsonDecode(chatMessages));
    }
    notifyListeners();
  }

  // ตั้งค่าสถานะการแจ้งเตือนและบันทึกลงใน SharedPreferences
  Future<void> setMaintenanceNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _hasChatNotification = value;
    prefs.setBool('hasChatNotification', value);
    notifyListeners();
  }

  // ลบสถานะการแจ้งเตือนจาก SharedPreferences
  Future<void> clearMaintenanceNotification() async {
    final prefs = await SharedPreferences.getInstance();
    _hasChatNotification = false;
    prefs.remove('hasChatNotification');
    notifyListeners();
  }

  // ตั้งค่าแชทข้อความและบันทึกลงใน SharedPreferences
  Future<void> setChatMessage(String requestId) async {
    _chatMessages[requestId] = true;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('chatMessages', jsonEncode(_chatMessages));
    notifyListeners();
  }

  // ลบข้อความแชทจาก SharedPreferences
  Future<void> removeChatMessage(String requestId) async {
    _chatMessages[requestId] = false;
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('chatMessages', jsonEncode(_chatMessages));
    notifyListeners();
  }

  // ลบข้อความทั้งหมดจาก SharedPreferences
  Future<void> clearChatMessages() async {
    _chatMessages.clear();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('chatMessages');
    notifyListeners();
  }
}
