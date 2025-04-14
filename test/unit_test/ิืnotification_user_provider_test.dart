import 'package:fixnow/notification_provider_user.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationUserProvider', () {
    late NotificationUserProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'user': 'john_doe',  // ตั้งค่าผู้ใช้เป็น 'john_doe'
      });

      // สร้าง instance ของ NotificationUserProvider และโหลดค่าผู้ใช้จาก SharedPreferences
      provider = NotificationUserProvider();
      await provider.loadUser();
    });

    test('should load initial user correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.user, 'john_doe');
    });

    test('should set and get user correctly', () async {
      await provider.setUser('new_user');
      expect(provider.user, 'new_user');
    });

    test('should clear user correctly', () async {
      // ตั้งค่าผู้ใช้เป็น 'new_user'
      await provider.setUser('new_user');

      // ลบข้อมูลผู้ใช้
      await provider.clearUser();

      // ตรวจสอบว่า user ถูกลบและมีค่าเป็น ''
      expect(provider.user, '');
    });
  });
}
