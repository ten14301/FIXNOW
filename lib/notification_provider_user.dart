import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationUserProvider with ChangeNotifier {
  String _user = '';

  String get user => _user;

  // ดึงค่าผู้ใช้จาก SharedPreferences
  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _user = prefs.getString('user') ?? '';
    notifyListeners();
  }

  // ตั้งค่าผู้ใช้และบันทึกลงใน SharedPreferences
  Future<void> setUser(String user) async {
    final prefs = await SharedPreferences.getInstance();
    _user = user;
    prefs.setString('user', user);
    notifyListeners();
  }

  // ลบข้อมูลผู้ใช้จาก SharedPreferences
  Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    _user = '';
    prefs.remove('user');
    notifyListeners();
  }
}
