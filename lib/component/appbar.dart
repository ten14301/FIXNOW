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
class CustomAppBar extends StatelessWidget {
  final String userName;

  const CustomAppBar({
    Key? key,
    required this.userName,
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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text("Logout"),
          content: Text("คุณแน่ใจแล้วใช่ไหมว่าจะ logout?"),
          actions: [
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String? accessToken = prefs.getString('accessToken');

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }

                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(child: CircularProgressIndicator()),
                  );
                }

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
                    
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                    
                    if (response.statusCode == 200) {
                      await _performLogout(prefs, context);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Logout ไม่สำเร็จ กรุณาลองใหม่')),
                        );
                      }
                    }
                  } catch (error) {
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ')),
                      );
                    }
                  }
                } else {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
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
Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
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

  if (context.mounted) {
  // ไปที่หน้า Login
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


  Future<void> _performLogout(SharedPreferences prefs, BuildContext context) async {
    await prefs.remove('userName');
    await prefs.remove('roleName');
    await prefs.remove('accessToken');
    await clearAllData();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
      (Route<dynamic> route) => false,
    );
  }

@override
Widget build(BuildContext context) {
  return WillPopScope(
    onWillPop: () async {
      // แสดง dialog เมื่อกดปุ่ม back
      _showLogoutDialog(context);
      return Future.value(false); // หยุดการกลับหน้าก่อนหน้า
    },
    child: Consumer<LogoutProvider>(
      builder: (context, logoutProvider, child) {
        if (logoutProvider.shouldLogout) {
          print("Forcing logout...");
          Future.delayed(Duration.zero, () {
            final logoutProvider = Provider.of<LogoutProvider>(context, listen: false);
            forceLogout(context, logoutProvider);
          });
        }
        return AppBar(
          surfaceTintColor: Colors.transparent,
          backgroundColor: Colors.white,
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
                        ),
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
      },
    ),
  );
}
}

