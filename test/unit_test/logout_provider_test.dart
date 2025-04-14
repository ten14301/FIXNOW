import 'package:fixnow/logout_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LogoutProvider', () {
    late LogoutProvider provider;

    // ก่อนทำการทดสอบทุกครั้ง
    setUp(() async {
      // ตั้งค่า initial mock values ให้กับ SharedPreferences
      SharedPreferences.setMockInitialValues({
        'shouldLogout': false,  // ตั้งค่าเริ่มต้นว่าไม่ต้อง logout
      });

      // สร้าง instance ของ LogoutProvider และโหลดค่าจาก SharedPreferences
      provider = LogoutProvider();
      await provider.loadLogoutStatus();
    });

    test('should load initial logout status correctly', () async {
      // ตรวจสอบว่า SharedPreferences ถูกโหลดมาอย่างถูกต้อง
      expect(provider.shouldLogout, false);
    });

    test('should set and get logout status correctly', () async {
      // ตั้งค่าสถานะให้ต้อง logout เป็น true
      await provider.setShouldLogout(true);

      // ตรวจสอบว่า การตั้งค่าสถานะ logout เป็น true
      expect(provider.shouldLogout, true);
    });

    test('should persist logout status in SharedPreferences', () async {
      // ตั้งค่าสถานะให้ต้อง logout เป็น true
      await provider.setShouldLogout(true);

      // โหลดค่าจาก SharedPreferences ใหม่
      final prefs = await SharedPreferences.getInstance();
      bool? storedValue = prefs.getBool('shouldLogout');

      // ตรวจสอบว่า SharedPreferences ถูกตั้งค่าเป็น true
      expect(storedValue, true);
    });
  });
}
