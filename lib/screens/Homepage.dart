import 'package:fixnow/notification_status_follow_provider.dart';
import 'package:fixnow/screens/Chat.dart';
import 'package:fixnow/screens/FixReport.dart';
import 'package:flutter/material.dart'; 
import 'Maintenance_request.dart';
import 'PostMaintenance_request.dart';
import '../component/appbar.dart';
import '../component/appbar_back.dart';
import '../component/menu.dart';
import '../component/technician_menu.dart';
import '../component/admin_menu.dart';
import 'FollowReqeustpage.dart';
import 'UpdateUser.dart';
import 'GenerateQR.dart';
import 'WaitProgress.dart';
import 'Historypage.dart';
import 'CreateAnnouncement.dart';
import 'Report.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../notification_maintenance_provider.dart';
import '../notification_follow_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'CreateRoom.dart';
import '../UserProvider.dart';
import '../notification_follow_provider_initial.dart';
import '../chatCheck_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  String userName;
  final String roleName;
  final String? accessToken;
  final bool CheckFirstTime;

  HomePage({
  required this.userName, 
  required this.roleName,
  required this.CheckFirstTime,
  required this.accessToken,
  });

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> Textinput = [];
  List<List<XFile>> Files = [];
  List<dynamic> StoreData = [];
  List<dynamic> StoreOtherData = [];
  bool isLoading = false;
  int numPage = 0;
  int currentPage = 0;
  bool isChange = false;
  bool isRead = false;
  dynamic selectedData;
  dynamic DataForchat;
  String apiURL = dotenv.env['API_URL'].toString();
 @override
  void initState() {
    super.initState();
    fetchMaintenanceNotifications();
    fetchisReadNotifications();
    if (widget.CheckFirstTime) {
    _showEditUsernameDialog(context, widget.userName, mapRoleToId(widget.roleName));
  }
  }
  void _goToPreviousPage() {
    setState(() {
      numPage = 0;
    });
  }
Future<void> fetchMaintenanceNotifications() async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  
    final response = await http.get(
      Uri.parse('$apiURL/api/maintenance/changeRequests'),
      headers: {
        "Authorization": "Bearer $accessToken",  
        "Content-Type": "application/json",  
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      setState(() {
        isChange = data.contains(false);
        if (isChange) {
          Provider.of<NotificationProvider>(context, listen: false).setMaintenanceNotification(isChange);
        }
      });
    } else {
      throw Exception('Failed to load notifications');
    }
  } catch (e) {
    print('Error fetching notifications: $e');
  }
}
Future<void> fetchisReadNotifications() async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  
    final response = await http.get(
      Uri.parse('$apiURL/api/maintenance/readRequests/user/${widget.userName}'),
      headers: {
        "Authorization": "Bearer $accessToken",  
        "Content-Type": "application/json",  
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List<dynamic>;
      setState(() {
        isRead = data.contains(false);
        print('isRead: $isRead');
        if (isRead) {
          Provider.of<NotificationFollowInitialProvider>(context, listen: false).setFollowNotification(isRead);
        }
      });
    } else {
      throw Exception('Failed to load notifications');
    }
  } catch (e) {
    print('Error fetching notifications: $e');
  }
}
void _showEditUsernameDialog(BuildContext context, String currentUsername, String roleId) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    TextEditingController usernameController = TextEditingController(text: currentUsername);

    showDialog(
      context: context,
      barrierDismissible: false, // ไม่ให้กดออกจาก Dialog ได้ระหว่างโหลด
      builder: (BuildContext dialogContext) {
        bool isLoading = false; // ตัวแปรเช็คสถานะโหลด
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.3,
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("คุณต้องการเปลี่ยนชื่อผู้ใช้หรือไม่", style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 20),
                    isLoading
                        ? CircularProgressIndicator()  // แสดง Loading
                        : TextField(
                            controller: usernameController,
                            decoration: InputDecoration(labelText: "ชื่อผู้ใช้ใหม่"),
                          ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!isLoading)
                          TextButton(
                            onPressed: () {
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else {
                                debugPrint("ไม่สามารถปิด Dialog ได้");
                              }
                            },
                            child: Text("ไม่เปลี่ยนชื่อ"),
                          ),
                        TextButton(
                          onPressed: () async {
                            String newUsername = usernameController.text.trim();

                            if (newUsername.isEmpty) {
                              return; 
                            }

                            if (newUsername == currentUsername) {
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('แจ้งเตือน'),
                                    content: Text('ชื่อใหม่ต้องไม่เหมือนชื่อเก่า'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text('ตกลง'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              return; // หยุดการทำงาน ไม่ต้องไปอัปเดต
                            }

                            setState(() => isLoading = true); 
                            bool success = await updateUser(context, currentUsername, roleId, newUsername: newUsername);
                            
                            if (success && dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(); 
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('Success'),
                                    content: Text('อัปเดตข้อมูลสำเร็จ'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(),
                                        child: Text('ตกลง'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else {
                              setState(() => isLoading = false); 
                            }
                          },
                          child: Text("บันทึก"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  });
}


Future<bool> updateUser(BuildContext context, String username, String roleId, {String? newUsername}) async {
  final url = Uri.parse('$apiURL/api/user/update');
  try {
    final Map<String, dynamic> body = {
      "username": username,
      "roleId": roleId,
      "isFistlogin": true,
    };

    if (newUsername != null && newUsername.isNotEmpty) {
      body["newUsername"] = newUsername;
    }

    print("Sending data: $body");

    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    final response = await http.put(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      // อัปเดตค่าใน SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', newUsername!);

      // ใช้ setState เพื่ออัปเดตค่าของ userName ใน StatefulWidget
      setState(() {
        widget.userName = newUsername;
        numPage = 0;  // รีเฟรชหน้าทั้งหมด
      });
      print("prefs.getString('userName'): ${prefs.getString('userName')}");

      return true;
    } else if (response.statusCode == 400) {
      // แสดงข้อผิดพลาดหากการอัปเดตไม่สำเร็จ
      final errorMessage = jsonDecode(response.body)['error'] ?? 'ข้อมูลไม่ถูกต้อง';
      setState(() => isLoading = false); // ซ่อน Loading
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text('ข้อผิดพลาด: $errorMessage'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // ปิด dialog
                },
                child: Text('ตกลง'),
              ),
            ],
          );
        },
      );
    }
  } catch (e) {
    print("Error occurred: $e");
    setState(() => isLoading = false); // ซ่อน Loading
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อกับเซิร์ฟเวอร์'),
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
  }
  return false;
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
@override
Widget build(BuildContext context) {
  print('Current userName: ${widget.userName}');
  print('Current roleName: ${widget.roleName}');
  
 return PopScope(
    canPop: numPage == 0, 
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) {
        if (numPage > 0) {
          _goToPreviousPage();
        }
      }
    },
    child: Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: numPage == 0
            ? CustomAppBar(userName: widget.userName)
            : CustomAppBar_nologout(
                onPreviousPage: _goToPreviousPage,
                userName: widget.userName,
              ),
      ),
      body: widget.roleName == "Technician"
          ? _buildTechnicianBody()
          : widget.roleName == "Admin"
              ? _buildAdminBody()
              : _buildRegularBody(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    ),
  );
}


  Widget _buildTechnicianBody() {
    switch (numPage) {
      case 8:
        Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return ReportPage();
      case 7:
        return ChatPage(
          post: DataForchat, 
          userName: widget.userName, 
          roleName: widget.roleName
          );
      case 6:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return WaitProgress(
          post: selectedData,
          userName: widget.userName,
          Textinput: Textinput,
          Files: Files,
        );
      case 4:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return PostmaintenanceRequest(
          roomData: StoreData,
          userName: widget.userName,
          roleName: widget.roleName,
          otherData: StoreOtherData,
        );
      case 3:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return HistoryPage(
          userName: widget.userName,
          roleName: widget.roleName,
        );

      case 2:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
      Provider.of<NotificationFollowInitialProvider>(context, listen: false).setFollowNotification(false);
        return FollowRequest(
          userName: widget.userName,
          roleName: widget.roleName,
          onSelected: (post) {
            setState(() {
              selectedData = post;
              numPage = 6;
              currentPage = 1;
            });
          },
        );
      case 1:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return FixReport(
                userName: widget.userName,
                roleName: widget.roleName,
                onChoose : (post) {
                  setState(() {
                    DataForchat = post;
                    numPage = 7;
                    currentPage = 1;
                  });
                },
        );
      default:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return MaintenanceRequest(
          onNextPage: (storeData, storeOtherData) {
            setState(() {
              StoreData = List<dynamic>.from(storeData);
              StoreOtherData = List<String>.from(storeOtherData);
              numPage = 4;
            });
          },
        );
    }
  }

   Widget _buildAdminBody() {
    switch (numPage) {
      case 12:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return RoomPage(
          userName: widget.userName,
          roleName: widget.roleName,
        );
      case 11:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return AnnouncementPage(
          userName: widget.userName,
        );
      case 10:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return QRCodePage();
      case 9:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return UpdateQRCodePage(
          userName: widget.userName, 
          roleName: widget.roleName
        );
      case 8:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return ReportPage();
      case 7:
        return ChatPage(
          post: DataForchat, 
          userName: widget.userName, 
          roleName: widget.roleName
          );
      case 6:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return WaitProgress(
          post: selectedData,
          Textinput: Textinput,
          userName: widget.userName,
          Files: Files,
        );
      case 4:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return PostmaintenanceRequest(
          roomData: StoreData,
          userName: widget.userName,
          roleName: widget.roleName,
          otherData: StoreOtherData,
        );
      case 3:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return HistoryPage(
          userName: widget.userName,
          roleName: widget.roleName,
        );

      case 2:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
      Provider.of<NotificationFollowInitialProvider>(context, listen: false).setFollowNotification(false);
        return FollowRequest(
          userName: widget.userName,
          roleName: widget.roleName,
          onSelected: (post) {
            setState(() {
              selectedData = post;
              numPage = 6;
            });
          },
        );
      case 1:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return FixReport(
                userName: widget.userName,
                roleName: widget.roleName,
                onChoose : (post) {
                  setState(() {
                    DataForchat = post;
                    numPage = 7;
                  });
                },
        );
      default:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return MaintenanceRequest(
          onNextPage: (storeData, storeOtherData) {
            setState(() {
              StoreData = List<dynamic>.from(storeData);
              StoreOtherData = List<String>.from(storeOtherData);
              numPage = 4;
            });
          },
        );
    }
  }

  Widget _buildRegularBody() {
    switch (numPage) {
      case 4:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return PostmaintenanceRequest(
          roomData: StoreData,
          userName: widget.userName,
          roleName: widget.roleName,
          otherData: StoreOtherData,
        );
      case 3:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return WaitProgress(
          post: selectedData,
          Textinput: Textinput,
          userName: widget.userName,
          Files: Files,
        );
      case 2:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return HistoryPage(
          userName: widget.userName,
          roleName: widget.roleName,
        );
      case 1:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
      Provider.of<NotificationFollowInitialProvider>(context, listen: false).setFollowNotification(false);
        return FollowRequest(
          userName: widget.userName,
          roleName: widget.roleName,
          onSelected: (post) {
            setState(() {
              selectedData = post;
              numPage = 3;
            });
          },
        );
      default:
      Provider.of<ChatCheckProvider>(context, listen: false).setisChat(false);
        return MaintenanceRequest(
          onNextPage: (storeData, storeOtherData) {
            setState(() {
              StoreData = List<dynamic>.from(storeData);
              StoreOtherData = List<String>.from(storeOtherData);
              numPage = 4;
            });
          },
        );
    }
  }

Widget _buildBottomNavigationBar() {
  if (widget.roleName == "Technician") {
    return Technician_menu(
      selectedIndex: (numPage == 6)
          ? 2
          : (numPage == 4)
              ? 0
              :(numPage == 7)
                  ? 1
              : (numPage > 5)
                  ? 5
                  : numPage,
      onItemTapped: _onTechnicianMenuTapped,
    );
  } else if (widget.roleName == "Admin") {
    return Admin_menu(
      selectedIndex: (numPage == 6)
          ? 2
          : (numPage == 4)
              ? 0
              :(numPage == 7)
                  ? 1
              : (numPage > 5)
                  ? 5
                  : numPage,
      onItemTapped: _onAdminMenuTapped,
    );
  } else {
    print('numPage: $numPage');
    return CustomBottomNavigationBar(
      selectedIndex:(numPage == 3)
          ? 1
          : (numPage == 4)
              ? 0
                  : numPage,
      onItemTapped: _onRegularMenuTapped,
    );
  }
}
  void _onRegularMenuTapped(int index) {
    setState(() {
      switch (index) {
        case 0:
          StoreData.clear();
          StoreOtherData.clear();
          numPage = 0;
          break;
        case 1:
          numPage = 1;
          Provider.of<Notification_FollowProvider>(context, listen: false).clearFollowNotification();
        case 2:
          numPage = index;
          break;
          
      }
    });
  }

void _onTechnicianMenuTapped(int index) {
  setState(() {
    switch (index) {
      case 0: // หน้าหลัก
        StoreData.clear();
        StoreOtherData.clear();
        numPage = 0;
        break;
      case 1: // งานซ่อม
        numPage = 1; // ไปที่หน้า FixReport
        Provider.of<NotificationProvider >(context, listen: false).clearMaintenanceNotification();
        break;
      case 2: // ติดตามสถานะ
        numPage = 2;
        Provider.of<Notification_FollowProvider>(context, listen: false).clearFollowNotification();
        break;
      case 3: // ประวัติ
        numPage = 3;
        break;
      case 4: // อื่น ๆ
         _showOtherOptionsPopup(widget.roleName);
        break;
    }
  });
}

void _onAdminMenuTapped(int index) {
  setState(() {
    switch (index) {
      case 0: // หน้าหลัก
        StoreData.clear();
        StoreOtherData.clear();
        numPage = 0;
        break;
      case 1: // งานซ่อม
        numPage = 1; // ไปที่หน้า FixReport
        Provider.of<NotificationProvider >(context, listen: false).clearMaintenanceNotification();
        break;
      case 2: // ติดตามสถานะ
        numPage = 2;
        Provider.of<Notification_FollowProvider>(context, listen: false).clearFollowNotification();
        print('Clear status follow messages');
        break;
      case 3: // ประวัติ
        numPage = 3;
        break;
      case 4: // อื่น ๆ
        _showOtherOptionsPopup(widget.roleName);
        break;
    }
  });
}
void _showOtherOptionsPopup(String roleName) async {
  final double screenWidth = MediaQuery.of(context).size.width;
  final double screenHeight = MediaQuery.of(context).size.height;

  String? result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    backgroundColor: Colors.white,
    builder: (BuildContext context) {
      String? selectedOption;

      Map<String, List<Map<String, dynamic>>> groupedOptions = {
        'QR CODE': [
          {'label': 'สร้าง QR CODE', 'action': 'createQRCode'},
          {'label': 'แก้ไข User', 'action': 'editQRCode'},
        ],
        'รายงาน': [
          {'label': 'หน้ารายงาน', 'action': 'report'},
        ],
        'ประกาศ': [
          {'label': 'หน้าประกาศ', 'action': 'announcement'},
        ],
        'ห้อง': [
          {'label': 'จัดการห้อง', 'action': 'createRoom'},
        ],
      };

      if (roleName != "Admin") {
        groupedOptions = {
          'รายงาน': groupedOptions['รายงาน']!,
        };
      }

      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  color: Colors.white,
                  width: screenWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenHeight * 0.01,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'เมนูอื่น ๆ',
                        style: GoogleFonts.kanit(
                          textStyle: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(null),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ปิด',
                              style: GoogleFonts.kanit(
                                textStyle: TextStyle(
                                  fontSize: screenWidth * 0.03,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF807A7A),
                                ),
                              ),
                            ),
                            Container(
                              width: screenWidth * 0.08,
                              height: screenHeight * 0.05,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                              ),
                              child: const Image(image: AssetImage('assets/images/close.png')),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                SizedBox(height: screenHeight * 0.02),
                // Dynamic Options by Group
                ...groupedOptions.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header for each category like "QR CODE", "รายงาน"
                      Padding(
                        padding: EdgeInsets.only(
                          left: screenWidth * 0.02,
                          top: screenHeight * 0.015,
                          bottom: screenHeight * 0.005,
                        ),
                        child: Text(
                          entry.key,
                          style: GoogleFonts.kanit(
                            textStyle: TextStyle(
                              fontSize: screenWidth * 0.03,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF807A7A),
                            ),
                          ),
                        ),
                      ),
                      ...entry.value.map((option) {
                        return Padding(
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(screenWidth * 0.2, screenHeight * 0.05),
                                backgroundColor: selectedOption == option['action']
                                    ? Colors.green
                                    : Colors.white,
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedOption = option['action'];
                                });
                              },
                              child: Text(
                                option['label'],
                                style: GoogleFonts.kanit(
                                  textStyle: TextStyle(
                                    color: selectedOption == option['action']
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),

                SizedBox(height: screenWidth * 0.02),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(screenWidth * 0.2, screenHeight * 0.06),
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(selectedOption);
                  },
                  child: Text(
                    'ตกลง',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.03,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: screenWidth * 0.02),
              ],
            ),
          );
        },
      );
    },
  );

  // Trigger page navigation after the dialog is dismissed
  if (result != null) {
    setState(() {
      switch (result) {
        case 'createRoom':
          numPage = 12;
          break;
        case 'createQRCode':
          numPage = 10;
          break;
        case 'editQRCode':
          numPage = 9;
          break;
        case 'report':
          numPage = 8;
          break;
        case 'announcement':
          numPage = 11;
          break;
        default:
          print('No action defined for $result');
      }
    });
  }
}

  
}
