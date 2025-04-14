import 'package:fixnow/notification_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationStatusProvider', () {
    late NotificationStatusProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hasStatusNotification': false,
        'statusMessage_request_1': true,
        'statusMessage_request_2': false,
      });

      // สร้าง instance ของ NotificationStatusProvider และโหลดค่าเริ่มต้นจาก SharedPreferences
      provider = NotificationStatusProvider();
      await provider.loadPreferences();
    });

    test('should load initial preferences correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.hasChatNotification, false);
      expect(provider.statusMessages['statusMessage_request_1'], true);
      expect(provider.statusMessages['statusMessage_request_2'], false);
    });

    test('should set and get status notification correctly', () async {
      // ตั้งค่า status notification
      await provider.setStatusNotification(true);

      // ตรวจสอบว่า status notification ถูกตั้งค่าแล้ว
      expect(provider.hasChatNotification, true);
    });

    test('should clear status notification correctly', () async {
      // ตั้งค่า status notification
      await provider.setStatusNotification(true);
      // ลบ status notification
      await provider.clearStatusNotification();

      // ตรวจสอบว่า status notification ถูกลบ
      expect(provider.hasChatNotification, false);
    });

    test('should set and remove status message correctly', () async {
      // ตั้งค่า status message สำหรับ requestId
      await provider.setStatusMessage('request_1');
      expect(provider.statusMessages['request_1'], true);

      // ลบ status message สำหรับ requestId
      await provider.removeStatusMessage('request_1');
      expect(provider.statusMessages['request_1'], false);
    });

    test('should clear all status messages correctly', () async {
      // ตั้งค่า status message สำหรับหลายๆ requestId
      await provider.setStatusMessage('request_1');
      await provider.setStatusMessage('request_2');
      expect(provider.statusMessages['request_1'], true);
      expect(provider.statusMessages['request_2'], true);

      // ล้างสถานะข้อความทั้งหมด
      await provider.clearStatusMessages();
      expect(provider.statusMessages.isEmpty, true);
    });
  });
}
