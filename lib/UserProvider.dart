import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  String _userName = "";
  String _roleName = "";
  String _accessToken = "";

  String get userName => _userName;
  String get roleName => _roleName;
  String get accessToken => _accessToken;

  bool get isLoggedIn => _userName.isNotEmpty && _roleName.isNotEmpty;

  UserProvider() {
    loadUserData();
  }


  Future<void> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userName = prefs.getString('userName') ?? "";
    _roleName = prefs.getString('roleName') ?? "";
    _accessToken = prefs.getString('accessToken') ?? "";
    notifyListeners();
  }

  // เซ็ตค่าและบันทึกลง SharedPreferences
  Future<void> setUserData(String name, String role, String token) async {
    _userName = name;
    _roleName = role;
    _accessToken = token;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('roleName', role);
    await prefs.setString('accessToken', token);

    notifyListeners();
  }

  // ล้างข้อมูลและ SharedPreferences
  Future<void> clearUserData() async {
    _userName = "";
    _roleName = "";
    _accessToken = "";

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userName');
    await prefs.remove('roleName');
    await prefs.remove('accessToken');

    notifyListeners();
  }
  
}
