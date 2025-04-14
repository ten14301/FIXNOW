import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRCodePage extends StatefulWidget {
  @override
  _QRCodePageState createState() => _QRCodePageState();
}

class _QRCodePageState extends State<QRCodePage> {
  String? qrCodePath;
  String? userName; // เก็บชื่อผู้ใช้งานที่ได้จาก Backend
  bool isLoading = false;
  String? roleName;
  int selectedRoleId = 2; // Default role
  String apiURL = dotenv.env['API_URL'] ?? '';
Future<void> generateQRCode() async {
  setState(() {
    isLoading = true;
  });

  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? accessToken = prefs.getString('accessToken');

    if (accessToken == null) {
      _showErrorDialog('ข้อผิดพลาด', 'ไม่พบ Access Token');
      setState(() {
        isLoading = false;
      });
      return;
    }

    final response = await http.post(
      Uri.parse('$apiURL/api/generate-qr'),
      headers: {
        'Authorization': 'Bearer $accessToken', // ใส่ Access Token ใน Header
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"role_type_id": selectedRoleId}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        qrCodePath = data['qrCode']; // Base64 QR Code
        userName = data['user_name']; // ชื่อผู้ใช้งานที่ได้จาก Backend
      });
    } else {
      _showErrorDialog('ล้มเหลว', 'ไม่สามารถสร้าง QR Code ได้');
    }
  } catch (e) {
    print('Error: $e');
    _showErrorDialog('ข้อผิดพลาด', 'ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้');
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}


  // บันทึก QR Code ลงในไฟล์
Future<void> _downloadQRCode(Uint8List imageData) async {
  try {
    // รับ path ของโฟลเดอร์เอกสารของแอป
    final directory = await getApplicationDocumentsDirectory();
    final fileName = userName != null ? '${userName}_QRCode.png' : 'QRCode.png';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    // บันทึกไฟล์ QR Code ลงในเครื่อง
    await file.writeAsBytes(imageData);

    // บันทึกไฟล์ลงในแกลเลอรี
    final result = await ImageGallerySaverPlus.saveImage(Uint8List.fromList(imageData));

    // ตรวจสอบว่าไฟล์ถูกบันทึกสำเร็จ
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ดาวน์โหลด QR Code สำเร็จ! ไฟล์ถูกบันทึกในแกลเลอรี'),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      _showErrorDialog('ข้อผิดพลาด', 'ไม่สามารถบันทึกไฟล์ไปที่แกลเลอรีได้');
    }
  } catch (e) {
    print('Error downloading QR Code: $e');
    _showErrorDialog('ข้อผิดพลาด', 'ไม่สามารถดาวน์โหลด QR Code ได้');
  }
}


  // แสดงข้อความผิดพลาด
  void _showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ตกลง'),
            ),
          ],
        );
      },
    );
  }

void _showRoleSelection(BuildContext context) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  String? result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    backgroundColor: Colors.white, // พื้นหลังเป็นสีขาว
    builder: (BuildContext context) {
      String? selectedOption; // ตัวเลือกที่ถูกเลือก
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'เลือกหน้าที่',
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF807A7A),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ปิด',
                              style: TextStyle(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF807A7A),
                              ),
                            ),
                            Container(
                              width: screenWidth * 0.08,
                              height: screenHeight * 0.05,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              child: const Image(
                                  image: AssetImage('assets/images/close.png')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Title "หน้าที่"
                Padding(
                  padding: EdgeInsets.only(bottom: screenHeight * 0.005),
                  child: Text(
                    'หน้าที่',
                    style: TextStyle(
                      fontSize: screenWidth * 0.03,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF807A7A),
                    ),
                  ),
                ),

                // Role Options
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedOption = selectedOption == 'Admin' ? null : 'Admin';
                        });
                      },
                      child: IntrinsicWidth(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          decoration: BoxDecoration(
                            color: selectedOption == 'Admin'
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: selectedOption == 'Admin'
                                  ? Colors.white
                                  : const Color(0xFF807A7A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedOption = selectedOption == 'Technician' ? null : 'Technician';
                        });
                      },
                      child: IntrinsicWidth(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          decoration: BoxDecoration(
                            color: selectedOption == 'Technician'
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Technician',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: selectedOption == 'Technician'
                                  ? Colors.white
                                  : const Color(0xFF807A7A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedOption = selectedOption == 'Regular' ? null : 'Regular';
                        });
                      },
                      child: IntrinsicWidth(
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          margin: const EdgeInsets.only(bottom: 8.0),
                          decoration: BoxDecoration(
                            color: selectedOption == 'Regular'
                                ? const Color(0xFF4CAF50)
                                : Colors.transparent,
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'Regular',
                            style: TextStyle(
                              fontSize: screenWidth * 0.03,
                              color: selectedOption == 'Regular'
                                  ? Colors.white
                                  : const Color(0xFF807A7A),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Confirm Button
                SizedBox(height: screenWidth * 0.04),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(selectedOption);
                    },
                    child: Text(
                      'ตกลง',
                      style: TextStyle(
                        fontSize: screenWidth * 0.03,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: screenWidth * 0.04),
              ],
            ),
          );
        },
      );
    },
  );

  if (result != null) {
    setState(() {
      roleName = result;
      selectedRoleId = roleName == 'Admin'
          ? 1
          : roleName == 'Technician'
              ? 3
              : 2;
      qrCodePath = null; // รีเซ็ต QR Code เมื่อเลือก Role ใหม่
    });
  }
}



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'สร้าง QR Code สำหรับ User',
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      GestureDetector(
                        onTap: () => _showRoleSelection(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            roleName ?? 'เลือก Role',
                            style: TextStyle(fontSize: screenWidth * 0.04, color: Colors.black),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      ElevatedButton(
                        onPressed: generateQRCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'สร้าง',
                          style: TextStyle(
                            fontSize: screenWidth * 0.04,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.03),
                      if (qrCodePath != null)
                        Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green, // กรอบพื้นหลังสีเขียว
                                border: Border.all(color: Colors.green, width: screenWidth * 0.01),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Image.memory(
                                base64Decode(qrCodePath!.split(',').last),
                                fit: BoxFit.cover,
                                width: screenWidth * 0.6,
                                height: screenWidth * 0.6,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () =>
                                  _downloadQRCode(base64Decode(qrCodePath!.split(',').last)),
                              icon: const Icon(Icons.download, color: Colors.green),
                              label: const Text(
                                'ดาวน์โหลด',
                                style: TextStyle(color: Colors.green, fontSize: 18),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
