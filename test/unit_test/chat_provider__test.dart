import 'package:fixnow/notification_chat_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationChatProvider', () {
    late NotificationChatProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hasChatNotification': true,  // ตั้งค่าเริ่มต้นของการแจ้งเตือนเป็น true
        'chatMessages': jsonEncode({'message1': true, 'message2': false}),  // ตั้งค่าเริ่มต้นของแชทข้อความ
      });

      // สร้าง instance ของ NotificationChatProvider และโหลดค่าจาก SharedPreferences
      provider = NotificationChatProvider();
      await provider.loadChatNotification();
    });

    test('should load initial chat notification status correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.hasChatNotification, true);
    });

    test('should load chat messages correctly', () async {
      // ตรวจสอบว่าแชทข้อความถูกโหลดมาอย่างถูกต้อง
      expect(provider.chatMessages, {'message1': true, 'message2': false});
    });

    test('should set and get chat notification status correctly', () async {
      // ตั้งค่าการแจ้งเตือนเป็น false
      await provider.setMaintenanceNotification(false);

      // ตรวจสอบว่า การตั้งค่าสถานะการแจ้งเตือนเป็น false
      expect(provider.hasChatNotification, false);
    });

    test('should set and remove a chat message correctly', () async {
      // ตั้งค่าแชทข้อความใหม่
      await provider.setChatMessage('message3');
      
      // ตรวจสอบว่าแชทข้อความถูกเพิ่มเข้าไปใน chatMessages
      expect(provider.chatMessages['message3'], true);

      // ลบแชทข้อความ
      await provider.removeChatMessage('message3');
      
      // ตรวจสอบว่าแชทข้อความถูกลบออก
      expect(provider.chatMessages['message3'], false);
    });

    test('should clear all chat messages correctly', () async {
      // ตั้งค่าข้อความแชท
      await provider.setChatMessage('message4');
      
      // ลบข้อความทั้งหมด
      await provider.clearChatMessages();
      
      // ตรวจสอบว่าแชทข้อความทั้งหมดถูกลบ
      expect(provider.chatMessages.isEmpty, true);
    });
  });
}
