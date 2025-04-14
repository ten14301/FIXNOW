import 'package:flutter/material.dart';

class RoomProvider with ChangeNotifier {
  String _roomId = ''; 

  String get roomId => _roomId;

  // ตั้งค่าห้อง
  void setRoom(String roomId) {
    _roomId = roomId;
    notifyListeners();
  }

  // ลบค่าห้อง
  void clearRoom() {
    _roomId = '';
    notifyListeners();
  }
}
