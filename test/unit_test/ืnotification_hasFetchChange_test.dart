import 'package:fixnow/notification_hasFetchChange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationHasChangeProvider', () {
    late NotificationHasChangeProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hasMaintenanceNotification': true,  // ตั้งค่าเริ่มต้นของการแจ้งเตือนเป็น true
      });

      // สร้าง instance ของ NotificationHasChangeProvider และโหลดค่าจาก SharedPreferences
      provider = NotificationHasChangeProvider();
      await provider.loadMaintenanceNotification();
    });

    test('should load initial maintenance notification status correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.hasMaintenanceNotification, true);
    });

    test('should set and get maintenance notification status correctly', () async {
      // ตั้งค่าการแจ้งเตือนเป็น false
      await provider.setMaintenanceNotification(false);

      // ตรวจสอบว่า การตั้งค่าสถานะการแจ้งเตือนเป็น false
      expect(provider.hasMaintenanceNotification, false);
    });

    test('should clear maintenance notification status correctly', () async {
      // ตั้งค่าสถานะการแจ้งเตือนเป็น false
      await provider.setMaintenanceNotification(false);

      // ลบสถานะการแจ้งเตือน
      await provider.clearMaintenanceNotification();

      // ตรวจสอบว่า สถานะการแจ้งเตือนถูกลบและมีค่าเป็น false
      expect(provider.hasMaintenanceNotification, false);
    });
  });
}
