import 'package:fixnow/notification_follow_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification_FollowProvider', () {
    late Notification_FollowProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'hasFollowNotification': true,  // ตั้งค่าเริ่มต้นของการแจ้งเตือนเป็น true
      });

      // สร้าง instance ของ Notification_FollowProvider และโหลดค่าจาก SharedPreferences
      provider = Notification_FollowProvider();
      await provider.loadFollowNotification();
    });

    test('should load initial follow notification status correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.hasFollowNotification, true);
    });

    test('should set and get follow notification status correctly', () async {
      // ตั้งค่าการแจ้งเตือนเป็น false
      await provider.setFollowNotification(false);

      // ตรวจสอบว่า การตั้งค่าสถานะการแจ้งเตือนเป็น false
      expect(provider.hasFollowNotification, false);
    });

    test('should clear follow notification status correctly', () async {
      // ตั้งค่าสถานะการแจ้งเตือนเป็น false
      await provider.setFollowNotification(false);

      // ลบสถานะการแจ้งเตือน
      await provider.clearFollowNotification();

      // ตรวจสอบว่า สถานะการแจ้งเตือนถูกลบและมีค่าเป็น false
      expect(provider.hasFollowNotification, false);
    });
  });
}
