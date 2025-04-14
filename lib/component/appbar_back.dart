import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../screens/Login_page.dart';
import '../logout_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

class CustomAppBar_nologout extends StatelessWidget {
  final String userName;
  final VoidCallback onPreviousPage; // ฟังก์ชันสำหรับกลับไปยังหน้า 1

  const CustomAppBar_nologout({
    Key? key,
    required this.userName,
    required this.onPreviousPage, // รับฟังก์ชันจากหน้า HomePage
  }) : super(key: key);

String truncateString(String str) {
  int maxLength = 7;
  return str.length > maxLength
      ? str.substring(0, min(str.length, maxLength)) + '..'
      : str;
}

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("คุณแน่ใจแล้วใช่ไหมว่าจะ logout?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); 
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String? accessToken = prefs.getString('accessToken');
                print("Access Token: $accessToken");

                // แสดง CircularProgressIndicator ตอนกำลัง logout
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );

                if (accessToken != null) {
                  try {
                      String apiURL = dotenv.env['API_URL'] ?? '';
                    final response = await http.put(
                      Uri.parse('$apiURL/api/user/logout'),
                      headers: {
                        'Authorization': 'Bearer $accessToken',
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({}),
                    );
                    print("Logout response: ${response.statusCode}");

                    if (response.statusCode == 200) {
                      await _performLogout(prefs, context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logout ไม่สำเร็จ กรุณาลองใหม่')),
                      );
                    }
                  } catch (error) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ')),
                    );
                  }
                } else {
                  await _performLogout(prefs, context);
                }
              },
              child: Text("Logout"),
            ),
          ],
        );
      },
    );
  }
void forceLogout(BuildContext context, LogoutProvider logoutProvider) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? accessToken = prefs.getString('accessToken');

  // แสดง CircularProgressIndicator ตอนกำลัง logout
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return Center(
        child: CircularProgressIndicator(),
      );
    },
  );

  // เรียก API logout ก่อนเปลี่ยนหน้า
  if (accessToken != null) {
    try {
        String apiURL = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$apiURL/api/user/logout'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({}),
      );

      print("Logout response: ${response.statusCode}");
    } catch (error) {
      print("เกิดข้อผิดพลาดในการเชื่อมต่อ API logout: $error");
    }
  }

  // ล้างค่าใน SharedPreferences
  await prefs.remove('userName');
  await prefs.remove('roleName');
  await prefs.remove('accessToken');

  // ตั้งค่า shouldLogout เป็น false ก่อนเปลี่ยนหน้า
  logoutProvider.setShouldLogout(false);

  // ปิด Dialog loading
  if (context.mounted) {
    Navigator.of(context).pop();
  }

  // ไปที่หน้า Login
  if (context.mounted){
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => LoginPage()),
    (Route<dynamic> route) => false,
  );
  }


  // แสดง Dialog หลังจากไปหน้า Login แล้ว
  Future.delayed(Duration.zero, () {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("บังคับออกจากระบบ"),
          content: Text("คุณถูกบังคับให้ออกจากระบบ กรุณาเข้าสู่ระบบใหม่"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // ปิด Dialog
              },
              child: Text("ตกลง"),
            ),
          ],
        );
      },
    );
  });
}
Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
  }

  Future<void> _performLogout(SharedPreferences prefs, BuildContext context) async {
    await prefs.remove('userName');
    await prefs.remove('roleName');
    await prefs.remove('accessToken');
    await clearAllData();
    Navigator.of(context).pop();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false, // ลบทุกหน้าก่อนหน้า
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LogoutProvider>(
    builder: (context, logoutProvider, child) {
      if (logoutProvider.shouldLogout) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final logoutProvider = Provider.of<LogoutProvider>(context, listen: false);
          forceLogout(context, logoutProvider);

        });
      }
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: onPreviousPage,
      ),
      title: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 60,
                  height: 20,
                  color: Colors.white,
                  child: Text(
                    "Username",
                    style: GoogleFonts.kanit(
                      fontSize: 12,
                      color: const Color(0xFF87898D),
                    )
                  ),
                ),
                Container(
                  width: 60,
                  height: 20,
                  color: Colors.white,
                  child: Text(
                    truncateString(userName),
                    style: GoogleFonts.kanit(
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              width: 55,
              height: 55,
              color: Colors.white,
              child: Image.asset(
                'assets/images/user-icon.png',
                fit: BoxFit.cover,
              ),
            ),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.black),
              onPressed: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
    }
    );
  }
}
