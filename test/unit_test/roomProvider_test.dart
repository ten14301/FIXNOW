import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fixnow/room_provider.dart';

void main() {
  test('should update roomId when setRoom is called', () {
    // สร้าง RoomProvider mock
    final roomProvider = RoomProvider();

    // ตรวจสอบค่าเริ่มต้นของ roomId
    expect(roomProvider.roomId, '');

    // เรียก setRoom เพื่อกำหนด roomId
    roomProvider.setRoom('room_1');

    // ตรวจสอบว่า roomId ถูกตั้งค่าถูกต้อง
    expect(roomProvider.roomId, 'room_1');
  });

  test('should clear roomId when clearRoom is called', () {
    // สร้าง RoomProvider mock
    final roomProvider = RoomProvider();

    // ตั้ง roomId ก่อน
    roomProvider.setRoom('room_2');
    expect(roomProvider.roomId, 'room_2');

    // เรียก clearRoom เพื่อลบ roomId
    roomProvider.clearRoom();

    // ตรวจสอบว่า roomId ถูกลบ
    expect(roomProvider.roomId, '');
  });
}
