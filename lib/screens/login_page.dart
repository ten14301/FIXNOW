import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fixnow/screens/Homepage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  XFile? _image;
  String? _fileName;

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      if (_isValidImage(pickedFile.name)) {
        setState(() {
          _image = pickedFile;
          _fileName = pickedFile.name.length > 10
              ? pickedFile.name.substring(0, 10)
              : pickedFile.name;
        });
      } else {
        _showErrorDialog('รูปภาพไม่ถูกต้อง', 'สามารถใช้ได้เฉพาะรูป PNG และ JPG เท่านั้น');
      }
    }
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (_isValidImage(pickedFile.name)) {
        setState(() {
          _image = pickedFile;
          _fileName = pickedFile.name.length > 5
              ? pickedFile.name.substring(0, 5)
              : pickedFile.name;
        });
      } else {
        _showErrorDialog('รูปภาพไม่ถูกต้อง', 'สามารถใช้ได้เฉพาะรูป PNG และ JPG เท่านั้น');
      }
    }
  }


Future<void> _sendImageToAPI() async {
  if (_image != null) {
    // ใช้ค่าจาก .env เพื่อเป็น API_KEY
    String apiKey = dotenv.env['API_KEY'] ?? '';
    String apiURL = dotenv.env['API_URL'] ?? '';

    // แสดง Loading Dialog
    _showLoadingDialog();

    try {
      await FirebaseMessaging.instance.deleteToken();
      // รับ FCM Token
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        Navigator.of(context).pop();
        _showErrorDialog('FCM Token ล้มเหลว', 'ไม่สามารถรับ FCM Token ได้');
        return;
      }

      // สร้าง Request
      var request = http.MultipartRequest('POST', Uri.parse('$apiURL/api/login/upload-qr'))
        ..headers.addAll({
          "Content-Type": "multipart/form-data",
          "x-api-key": apiKey,  
          "FCM-Token": fcmToken,
        })
        ..files.add(
          await http.MultipartFile.fromPath(
            'fileField',
            _image!.path,
          ),
        );

      // ส่ง Request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString(); // อ่าน response body
      Navigator.of(context).pop();

      print('Response: ${response.statusCode} ${response.reasonPhrase}');
      print('Response Body: $responseBody');

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(responseBody);

        if (jsonResponse.isNotEmpty) {
          String userName = jsonResponse['user']['name'];
          int roleId = jsonResponse['user']['role_id'];
          String roleName = _getRoleName(roleId);
          String accessToken = jsonResponse['access_token'];
          int isFisttime = jsonResponse['isFisttime'];
          bool CheckFirstTime = false;
          print("time login : ${jsonResponse['isFisttime']}" );

          // เก็บข้อมูลลง SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('userName', userName);
          await prefs.setString('roleName', roleName);
          await prefs.setString('accessToken', accessToken);

          print("prefs.getString('userName')" + prefs.getString('userName').toString());
          print("prefs.getString('roleName')" + prefs.getString('roleName').toString());
          print("prefs.getString('accessToken')" + prefs.getString('accessToken').toString());

          if(isFisttime == 0){
            CheckFirstTime = true;
          }
          else{
            CheckFirstTime = false;
          }
            Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomePage(
                userName: userName,
                roleName: roleName,
                accessToken: accessToken,
                CheckFirstTime: CheckFirstTime,
              ),
            ),
          );


        } else {
          _showErrorDialog('เข้าสู่ระบบล้มเหลว', 'ไม่พบข้อมูลผู้ใช้งาน');
        }
      } else if (response.statusCode == 403) {
        var jsonResponse = jsonDecode(responseBody);
        String errorMessage = jsonResponse['message'];

        if (errorMessage == 'User is inactive') {
          _showErrorDialog('เข้าสู่ระบบล้มเหลว', 'มีคนใช้ User นี้อยู่');
        } else {
          _showErrorDialog('การเข้าถึงถูกปฏิเสธ', errorMessage);
        }
      } else {
        _showErrorDialog('เข้าสู่ระบบล้มเหลว', 'ไม่พบข้อมูลผู้ใช้งาน');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        print("Error: $e");
        _showErrorDialog(
            'การเชื่อมต่อล้มเหลว', 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง');
      }
    }
  } else {
    _showErrorDialog('ไม่มีรูปภาพที่เลือก', 'กรุณาเลือกรูปภาพเพื่ออัปโหลด');
  }
}



  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _showErrorDialog(String title, String content) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  if (mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Text('ตกลง'),
              ),
            ],
          );
        },
      );
    } else {
      print("Widget has been unmounted. Cannot show error dialog.");
    }
  }

  bool _isValidImage(String fileName) {
    return fileName.toLowerCase().endsWith('.png') ||
        fileName.toLowerCase().endsWith('.jpg');
  }

  // ฟังก์ชันแปลง role_id เป็นชื่อ Role
  String _getRoleName(int roleId) {
    switch (roleId) {
      case 1:
        return "Admin";
      case 2:
        return "Regular";
      case 3:
        return "Technician";
      default:
        return "Unknown";
    }
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    print('Firebase Initialized');
    // หากต้องการทำอะไรหลังจาก Firebase เริ่มต้นแล้ว เช่น รับ FCM Token
    String? fcmToken = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $fcmToken");
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // Fixed Padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 50.0),
              Text(
                'ใช้ QR CODE',
                style: GoogleFonts.kanit(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 24.0, // Fixed Font Size
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                'เพื่อเข้าสู่ระบบ',
                style: GoogleFonts.kanit(
                  textStyle: const TextStyle(
                    color: Colors.black,
                    fontSize: 24.0, // Fixed Font Size
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              Container(
                width: 250.0,
                height: 250.0,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFF4CAF50), width: 5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Center(
                    child: _image == null
                        ? Text(
                            'ไม่มีรูปภาพที่เลือก หรือ ถ่าย',
                            style: GoogleFonts.kanit(
                              textStyle: const TextStyle(
                                fontSize: 18.0, // Fixed Font Size
                                color: Colors.black,
                              ),
                            ),
                          )
                        : ClipRect(
                            child: Image.file(
                              File(_image!.path),
                              fit: BoxFit.cover,
                              width: 250.0,
                              height: 250.0,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              GestureDetector(
                onTap: _uploadImage,
                child: Container(
                  width: 110.0 + (_fileName != null ? _fileName!.length : 0) * 10.0,
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 60.0,
                        height: 30.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Center(
                          child: Text(
                            'อัปโหลด',
                            style: GoogleFonts.kanit(
                              textStyle: const TextStyle(
                                color: Colors.black,
                                fontSize: 16.0, // Fixed Font Size
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10.0),
                      _fileName != null
                          ? Text(
                              _fileName!,
                              style: GoogleFonts.kanit(
                                textStyle: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16.0, // Fixed Font Size
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                      const SizedBox(width: 10.0),
                      Text(
                        '>',
                        style: GoogleFonts.kanit(
                          textStyle: const TextStyle(
                            color: Colors.black,
                            fontSize: 28.0, // Fixed Font Size
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              GestureDetector(
                onTap: _takePicture,
                child: Container(
                  width: 200.0,
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, size: 40.0), // Fixed Icon Size
                  ),
                ),
              ),
              const SizedBox(height: 30.0),
              GestureDetector(
                onTap: _sendImageToAPI,
                child: Container(
                  width: 250.0,
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Center(
                    child: Text(
                      'ยืนยัน',
                      style: GoogleFonts.kanit(
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 20.0, // Fixed Font Size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20.0),
              GestureDetector(
                onTap: () async {
                  bool? confirmExit = await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('ยืนยันการออก', style: GoogleFonts.kanit()),
                        content: Text('คุณต้องการออกจากแอปหรือไม่?', style: GoogleFonts.kanit()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('ยกเลิก', style: GoogleFonts.kanit()),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('ออก', style: GoogleFonts.kanit()),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmExit == true) {
                    exit(0);
                  }
                },
                child: Container(
                  width: 250.0,
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: Colors.grey, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'ออก',
                      style: GoogleFonts.kanit(
                        textStyle: const TextStyle(
                          color: Colors.black,
                          fontSize: 20.0, // Fixed Font Size
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
