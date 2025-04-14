import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogoutProvider extends ChangeNotifier {
  bool _shouldLogout = false;

  bool get shouldLogout => _shouldLogout;

  // โหลดสถานะ logout จาก SharedPreferences
  Future<void> loadLogoutStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _shouldLogout = prefs.getBool('shouldLogout') ?? false;
    notifyListeners();
  }

  // ตั้งค่าให้ต้อง logout
  Future<void> setShouldLogout(bool value) async {
    _shouldLogout = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('shouldLogout', value);
    notifyListeners();
  }
}
