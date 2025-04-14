import 'package:fixnow/notification_status_follow_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationFollowProvider', () {
    late NotificationFollowProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hasStatusFollowNotification': false,
        'statusFollowMessage_request_1': true,
        'statusFollowMessage_request_2': false,
      });

      // สร้าง instance ของ NotificationFollowProvider และโหลดค่าเริ่มต้นจาก SharedPreferences
      provider = NotificationFollowProvider();
      await provider.loadPreferences();
    });

    test('should load initial preferences correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.hasStatusFollowNotification, false);
      expect(provider.statusFollowMessages['statusFollowMessage_request_1'], true);
      expect(provider.statusFollowMessages['statusFollowMessage_request_2'], false);
    });

    test('should set and get status follow notification correctly', () async {
      // ตั้งค่า status follow notification
      await provider.setStatusFollowNotification(true);

      // ตรวจสอบว่า status follow notification ถูกตั้งค่าแล้ว
      expect(provider.hasStatusFollowNotification, true);
    });

    test('should clear status follow notification correctly', () async {
      // ตั้งค่า status follow notification
      await provider.setStatusFollowNotification(true);
      // ลบ status follow notification
      await provider.clearStatusFollowNotification();

      // ตรวจสอบว่า status follow notification ถูกลบ
      expect(provider.hasStatusFollowNotification, false);
    });

    test('should set and remove status follow message correctly', () async {
      // ตั้งค่า status follow message สำหรับ requestId
      await provider.setStatusFollowMessage('request_1');
      expect(provider.statusFollowMessages['request_1'], true);

      // ลบ status follow message สำหรับ requestId
      await provider.removeStatusFollowMessage('request_1');
      expect(provider.statusFollowMessages['request_1'], false);
    });

    test('should clear all status follow messages correctly', () async {
      // ตั้งค่า status follow message สำหรับหลายๆ requestId
      await provider.setStatusFollowMessage('request_1');
      await provider.setStatusFollowMessage('request_2');
      expect(provider.statusFollowMessages['request_1'], true);
      expect(provider.statusFollowMessages['request_2'], true);

      // ล้างสถานะการติดตามทั้งหมด
      await provider.clearStatusFollowMessages();
      expect(provider.statusFollowMessages.isEmpty, true);
    });
  });
}
