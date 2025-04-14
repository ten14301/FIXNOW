import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../UserProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class UpdateQRCodePage extends StatefulWidget {
  final String userName;
  final String roleName;

  // Constructor accepting userName and roleName as required parameters
  UpdateQRCodePage({
    required this.userName,
    required this.roleName,
  });

  @override
  _UpdateQRCodePageState createState() => _UpdateQRCodePageState();
}

class _UpdateQRCodePageState extends State<UpdateQRCodePage> {
  List<Map<String, dynamic>> data = [];
  List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String filterKeyword = "";
  String apiURL = dotenv.env['API_URL'] ?? '';
  

  @override
  void initState() {
    super.initState();
    fetchData();
  }

Future<void> fetchData() async {
  try {
    // ดึง accessToken จาก Provider หรือแหล่งข้อมูลที่ใช้ในการจัดการการยืนยันตัวตน
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    // ส่งคำขอ GET พร้อม Authorization header
    final response = await http.get(
      Uri.parse('$apiURL/api/user/Allusers'),
      headers: {
        'Authorization': 'Bearer $accessToken',  
        'Content-Type': 'application/json',

      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> responseData = json.decode(response.body);
      setState(() {
        data = responseData
            .map((item) => {
                  "username": item['user_name'] ?? "N/A",
                  "role": item['role_name'] ?? "Unknown",
                })
            .toList();
        filteredData = List.from(data);
        isLoading = false;
      });
    } else {
      throw Exception("Failed to load data");
    }
  } catch (e) {
    if(mounted){
    setState(() {
      isLoading = false; // เปลี่ยนสถานะการโหลด
    });

    // แก้ไขข้อความ error เพื่อไม่ให้แสดง URL
    String errorMessage = e.toString();
    errorMessage = errorMessage.replaceAll(RegExp(r'http[s]?://\S+'), '[URL hidden]');

    print("Error fetching data: $errorMessage");
    // แสดง AlertDialog เมื่อเกิดข้อผิดพลาด
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('เกิดข้อผิดพลาด: $errorMessage'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // ปิด AlertDialog
              },
              child: Text('ตกลง'),
            ),
          ],
        );
      },
    );
    }
  }
}


Future<void> updateUser(String username, String roleId, {String? newUsername}) async {
  final url = Uri.parse('$apiURL/api/user/update');
  try {
    setState(() {
      isLoading = true; 
    });
    final Map<String, dynamic> body = {
      "username": username,
      "roleId": roleId,
    };

    if (newUsername != null && newUsername.isNotEmpty) {
      body["newUsername"] = newUsername;
    }

    print("Sending data: $body");

    // ดึง accessToken จาก provider หรือแหล่งข้อมูลที่ใช้ในการจัดการการยืนยันตัวตน
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    setState(() {
      isLoading = false;
    });
    if (response.statusCode == 200) {
      // Success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Success'),
            content: Text('อัปเดตข้อมูลสำเร็จ'),
            actions: [
              TextButton(
                onPressed: () {
                  if (!mounted) return;
                  Navigator.of(context).pop(); 
                setState(() {
                  if(mounted){
                    fetchData(); 
                  }
                });
                },
                child: Text('ตกลง'),
              ),
            ],
          );
        },
      );
    } else if (response.statusCode == 400) {
      final errorMessage = jsonDecode(response.body)['error'] ?? 'ข้อมูลไม่ถูกต้อง';
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('ข้อผิดพลาด: $errorMessage'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('ตกลง'),
              ),
            ],
          );
        },
      );
    } else {
      print("Error Response: ${response.body}");
      throw Exception('Failed to update user: ${response.statusCode}');
    }
  } catch (e) {
    print("Error occurred: $e");
    if(mounted) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('เกิดข้อผิดพลาด: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close AlertDialog
              },
              child: Text('ตกลง'),
            ),
          ],
        );
        
      },
    );
        }
  }
}
Future<void> deleteUser(String username) async {
    final url = Uri.parse('$apiURL/api/user/delete');
    try {
      final Map<String, dynamic> body = {
        "username": username,
      };

      print("Sending data: $body");

      // ดึง accessToken จาก provider หรือแหล่งข้อมูลที่ใช้ในการจัดการการยืนยันตัวตน
      final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Success dialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Success'),
              content: Text('ลบข้อมูลสำเร็จ'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close AlertDialog
                  setState(() {
                    fetchData(); // โหลดข้อมูลใหม่ พร้อมอัปเดต UI
                  });
                  },
                  child: Text('ตกลง'),
                ),
              ],
            );
          },
        );
      } else if (response.statusCode == 400) {
        final errorMessage = jsonDecode(response.body)['error'] ?? 'ข้อมูลไม่ถูกต้อง';
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Error'),
              content: Text('ข้อผิดพลาด: $errorMessage'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('ตกลง'),
                ),
              ],
            );
          },
        );
      } else {
        print("Error Response: ${response.body}");
        throw Exception('Failed to delete user: ${response.statusCode}');
      }
    } catch (e) {
      print("Error occurred: $e");
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('เกิดข้อผิดพลาด: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close AlertDialog
                },
                child: Text('ตกลง'),
              ),
            ],
          );
        },
      );
}
}

  String mapRoleToId(String role) {
    switch (role) {
      case 'Admin':
        return '1';
      case 'Technician':
        return '3';
      case 'Regular':
        return '2';
      default:
        return '0';
    }
  }

  void showEditPopup(BuildContext context, Map<String, dynamic> item) {
    final TextEditingController nameController =
        TextEditingController(text: item['username'] ?? "");
    String selectedRole = item['role'] ?? "Unknown";

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'แก้ไขข้อมูล',
                style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: Colors.grey),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อผู้ใช้ใหม่ (ถ้ามี)',
                  labelStyle: GoogleFonts.kanit(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: ['Admin', 'Technician', 'Regular', 'Unknown']
                    .map((role) => DropdownMenuItem(
                          value: role,
                          child: Text(
                            role,
                            style: GoogleFonts.kanit(),
                          ),
                        ))
                    .toList(),
                onChanged: (newRole) {
                  if (newRole != null) {
                    selectedRole = newRole;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'สถานะ',
                  labelStyle: GoogleFonts.kanit(color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('ยกเลิก', style: GoogleFonts.kanit(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              onPressed: () {
                final updatedRoleId = mapRoleToId(selectedRole);
                final newUsername = nameController.text.isNotEmpty
                    ? nameController.text
                    : null;

              if (newUsername == item['username']) {
                updateUser(item['username'], updatedRoleId);
              } else {
                updateUser(item['username'], updatedRoleId, newUsername: newUsername);
              }
                Navigator.of(context).pop();
              },
              child: Text(
                'ตกลง',
                style: GoogleFonts.kanit(color: Colors.white, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Text(
                      'แก้ไข User',
                      style: GoogleFonts.kanit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() {
                              filterKeyword = value;
                              filteredData = data.where((row) {
                                return row['username']
                                        .toString()
                                        .toLowerCase()
                                        .contains(filterKeyword.toLowerCase()) ||
                                    row['role']
                                        .toString()
                                        .toLowerCase()
                                        .contains(filterKeyword.toLowerCase());
                              }).toList();
                            });
                          },
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'ค้นหา',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Username',
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Role',
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Actions',
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        final item = filteredData[index];
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item['username'],
                                    style: GoogleFonts.kanit(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item['role'],
                                    style: GoogleFonts.kanit(),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () {
                                      showEditPopup(context, item);
                                    },
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: Text('ยืนยันการลบ'),
                                            content: Text('คุณต้องการลบผู้ใช้นี้ใช่หรือไม่?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(), // ปิดกล่อง
                                                child: Text('ยกเลิก'),
                                              ),
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.of(context).pop();
                                                  deleteUser(item['username']);
                                                },
                                                child: Text('ลบ', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),

                              ],
                            ),
                            const Divider(),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
