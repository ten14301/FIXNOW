import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:fixnow/notification_announcementFetch.dart';
import 'package:provider/provider.dart';
import '../UserProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
class MaintenanceRequest extends StatefulWidget {

  final Function(List, List) onNextPage; 
  const MaintenanceRequest({
    Key? key,
    required this.onNextPage,
  }) : super(key: key);


  @override
  _MaintenanceRequestState createState() => _MaintenanceRequestState();
}


class _MaintenanceRequestState extends State<MaintenanceRequest> {
  int selectedFloor = -1;
  List<String> roomData = []; 
  List<String> roomDataCheck = []; 
  List<bool> messageStates = [];
  List<String> StoreData = []; 
  String StoreOtherData = "";
  List<String> StoreOtherDataList = [];
  bool isLoading = true;    
  Map<String, Color> roomColors = {};
  Map<String, Color> iconColors = {};
  List<Map<String, dynamic>> announcements = [];
  String apiURL = dotenv.env['API_URL'] ?? '';
  final ScrollController _scrollController = ScrollController();
  int currentPage = 0; 

  @override
  void initState() {
    super.initState();
    _loadDataAndFetchAnnouncement();

  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
Future<void> _loadDataAndFetchAnnouncement() async {
  await Provider.of<UserProvider>(context, listen: false).loadUserData();
  _fetchAnnouncement(context);
  _fetchAllRooms(context);
}
Future<void> _fetchAnnouncement(BuildContext context) async {
  try {
    // โหลด Access Token จาก Provider
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    final response = await http.get(
      Uri.parse('$apiURL/api/announcement'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        if (mounted) {
          setState(() {
            announcements = data.where((item) {
              final startDateStr = item['start'];
              final expireDateStr = item['expire'];
              
              final startDate = DateTime.tryParse(startDateStr);
              final expireDate = DateTime.tryParse(expireDateStr);
              final startDateOnly = DateTime(startDate!.year, startDate.month, startDate.day);
            final expireDateOnly = DateTime(expireDate!.year, expireDate.month, expireDate.day);
              if (expireDateStr == null || expireDateStr.isEmpty) {
                return false;
              }

              if (startDateStr == null || startDateStr.isEmpty) {
                return false;
              }
              
              // เปรียบเทียบแค่วันที่ (ไม่สนใจเวลา)
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              print("Start Date: $startDate, Today: $today");


              return (expireDateOnly.isAfter(today) || expireDateOnly.isAtSameMomentAs(today)) &&
                    (startDateOnly.isBefore(today) || startDateOnly.isAtSameMomentAs(today));

            }).map<Map<String, dynamic>>((item) {
              return {
                "info": item['info'],
                "room_number": item['room_number'],
                "start": item['start'],
                "date": item['date'],
                "time": item['time'],
                "expire": item['expire'], 
              };
            }).toList();
          });
        }
      } else {
        _setNoAnnouncement();
      }
    } else {
      print("Error response: ${response.body}");
      _setNoAnnouncement();
    }
  } catch (e) {
    print("Error fetching announcements: $e");
    _setNoAnnouncement();
  }
}


// ตั้งค่าเมื่อไม่มีประกาศ
void _setNoAnnouncement() {
  if (mounted) {
    setState(() {
      announcements = [{"message": "ไม่มีประกาศ"}];
    });
  }
}



Widget buildRoomContainer(String roomNumber, Color color, VoidCallback onTap) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: screenWidth * 0.15, // ใช้เปอร์เซ็นต์
      height: screenHeight * 0.08, // ใช้เปอร์เซ็นต์
      margin: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: color,
      ),
      child: Center(
        child: Text(
          roomNumber,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
Widget buildIconContainer(String assetPath, Function onTap, Color color) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  return GestureDetector(
    onTap: () => onTap(),
    child: Container(
      width: screenWidth * 0.15, // ใช้เปอร์เซ็นต์
      height: screenHeight * 0.10, // ใช้เปอร์เซ็นต์
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(screenWidth * 0.15 * 0.2), // ปรับตามเปอร์เซ็นต์
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.15 * 0.1), // ปรับตามเปอร์เซ็นต์
        child: Image.asset(assetPath, 
        fit: BoxFit.contain),
      ),
    ),
  );
}

@override
  Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  return Consumer<NotificationAnnounceFetch>(
  builder: (context,announceProvider,child) {
  if (announceProvider.hasMaintenanceNotification) {
        Future.microtask(() async {
          await _fetchAnnouncement(context);
          announceProvider.clearMaintenanceNotification();
        });
      }
    return Scaffold(
    backgroundColor: Colors.white,
    body:
     SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
children: [
  if (announcements.isNotEmpty && announcements[0]["room_number"] != null)
SingleChildScrollView(
controller: _scrollController,
child:Container(
  padding: const EdgeInsets.all(10),
  width: screenWidth * 0.9,
  height: screenHeight * 0.25,
  decoration: BoxDecoration(
    color: Colors.white,
    border : Border.all(color: Colors.grey[300]! , width: 1),
  ),
child: Column(
  children: [
    SizedBox(
      height: max(screenHeight, screenWidth) * 0.22,
      child: ListView.builder(
        itemCount: announcements.length,
        itemBuilder: (context, index) {
          final roomName = announcements[index]["room_number"]?.toString();
          final message = announcements[index]["info"] ?? '';

          bool isLongMessage = message.length > 10;

          if (messageStates.length <= index) {
            messageStates.add(isLongMessage);
          }

          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.all(max(screenHeight, screenWidth) * 0.015),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!, width: 1),
            ),
            child: GestureDetector(
              onTap: isLongMessage
                  ? () {
                      setState(() {
                        messageStates[index] = !messageStates[index];
                      });
                    }
                  : null, // ไม่ให้กดได้ถ้าข้อความสั้นกว่า 10 ตัวอักษร
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: max(screenHeight, screenWidth) * 0.07,
                    padding: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.red[600],
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Center(
                      child: Text(
                        'ประกาศ',
                        style: GoogleFonts.kanit(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: max(screenHeight, screenWidth) * 0.015,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: max(screenHeight, screenWidth) * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ห้อง: $roomName',
                          style: GoogleFonts.kanit(
                            textStyle: TextStyle(
                              color: Colors.blue[600],
                              fontSize: max(screenHeight, screenWidth) * 0.015,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: max(screenHeight, screenWidth) * 0.01),
                        Row(
                      children: [
                        Expanded(
                          child: Text(
                            isLongMessage
                                ? (messageStates[index]
                                    ? '${message.substring(0, message.length >= 10 ? 10 : message.length)}...อ่านเพิ่มเติม'
                                    : message)
                                : message, // แสดงข้อความเต็มถ้าสั้นกว่า 10 ตัวอักษร
                            style: GoogleFonts.kanit(
                              textStyle: TextStyle(
                                color: Colors.black,
                                fontSize: max(screenHeight, screenWidth) * 0.013,
                              ),
                            ),
                            maxLines: isLongMessage ? 1 : null,
                            overflow: isLongMessage ? TextOverflow.ellipsis : null,
                          ),
                        ),
                      ],
                    ),

                      ],
                    ),
                  ),
                  if (index < 3)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'NEW',
                        style: GoogleFonts.kanit(
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth * 0.02,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  ],
),
),
),

SizedBox(height: screenHeight * 0.02),
            Text(
              "แจ้งซ่อม",
              style: GoogleFonts.kanit(
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          GestureDetector(
            onTap: () {
              _showSelectFloor((int floor) {
                setState(() {
                  selectedFloor = floor;
                });
              _fetchRoom(context,selectedFloor);
              });
            },
            child: Container(
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    selectedFloor == -1 ? "แตะเพื่อเลือกชั้น" : "ชั้น $selectedFloor",
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Image.asset(
                    'assets/images/edit.png',
                    width: screenWidth * 0.1,
                    height: screenHeight * 0.06,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.04, 
              ),
              constraints: BoxConstraints(
                minWidth: screenWidth * 0.9,
                minHeight: screenHeight * 0.4,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Color(0xFFEBE5E5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (roomData.isEmpty)
                    Text('ยังไม่ได้เลือกชั้น',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth * 0.03,
                      ),
                    ),

                    ) 
                  else ...[
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: isLoading 
                        ? [CircularProgressIndicator()]
                        : roomData.length > 1 
                          ? roomData.sublist(0, (roomData.length / 2).ceil()).map<Widget>((room) {
                              return buildRoomContainer(
                                room,
                                roomColors[room] ?? Colors.green,
                                () {
                                  setState(() {
                                    if (roomColors[room] == Colors.red) {
                                      roomColors[room] = Colors.green;
                                      StoreData.remove(room);
                                    } else {
                                      roomColors[room] = Colors.red;
                                      StoreData.add(room);
                                    }
                                  });
                                },
                              );
                            }).toList()
                          : roomData.map<Widget>((room) {
                              return buildRoomContainer(
                                room,
                                roomColors[room] ?? Colors.green,
                                () {
                                  setState(() {
                                    if (roomColors[room] == Colors.red) {
                                      roomColors[room] = Colors.green;
                                      StoreData.remove(room);
                                    } else {
                                      roomColors[room] = Colors.red;
                                      StoreData.add(room);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // ใช้ Expanded เพื่อให้ไอคอนขยายเต็มพื้นที่ในแต่ละคอลัมน์
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/stair.png',
                                  () {
                                    String key = 'บันไดทางซ้ายของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['บันไดทางซ้ายของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/woman.png',
                                  () {
                                    String key = 'ห้องน้ำหญิงทางซ้ายของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ห้องน้ำหญิงทางซ้ายของชั้น$selectedFloor'] ?? Colors.white
                                ),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                                buildIconContainer(
                                  'assets/images/man.png',
                                  () {
                                    String key = 'ห้องน้ำชายทางซ้ายของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ห้องน้ำชายทางซ้ายของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/elevator.png',
                                  () {
                                    String key = 'ลิฟท์ทางซ้ายของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ลิฟท์ทางซ้ายของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/elevator.png',
                                  () {
                                    String key = 'ลิฟท์ทางขวาของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ลิฟท์ทางขวาของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/woman.png',
                                  () {
                                    String key = 'ห้องน้ำหญิงทางขวาของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ห้องน้ำหญิงทางขวาของชั้น$selectedFloor'] ?? Colors.white
                                ),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                                buildIconContainer(
                                  'assets/images/man.png',
                                  () {
                                    String key = 'ห้องน้ำชายทางขวาของชั้น$selectedFloor';
                                    print("Man Right clicked!");
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['ห้องน้ำชายทางขวาของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                buildIconContainer(
                                  'assets/images/stair.png',
                                  () {
                                    String key = 'บันไดทางขวาของชั้น$selectedFloor';
                                    setState(() {
                                      if (StoreOtherDataList.contains(key)) {
                                        StoreOtherDataList.remove(key);
                                        iconColors[key] = Colors.white;
                                      } else {
                                        StoreOtherDataList.add(key);
                                        iconColors[key] = Colors.red;
                                      }
                                    });
                                  },
                                  iconColors['บันไดทางขวาของชั้น$selectedFloor'] ?? Colors.white
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: roomData.sublist((roomData.length / 2).ceil(), roomData.length).map<Widget>((room) {
                          return buildRoomContainer(
                            room,
                            roomColors[room] ?? Colors.green,
                            () {
                              setState(() {
                                if (roomColors[room] == Colors.red) {
                                  roomColors[room] = Colors.green;
                                  StoreData.remove(room);
                                } else {
                                  roomColors[room] = Colors.red;
                                  StoreData.add(room);
                                }
                              });
                            },
                          );
                        }).toList(),
                      )
                  ],
                ],
              ),
            ),
          ),

            const SizedBox(height: 10),            
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                GestureDetector(
                  onTap: () {
                    showInputDialog(context);
                  },
                  child: Container(
                    width: screenWidth * 0.45,
                    height: screenHeight * 0.08,
                    margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFEBE5E5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                          Expanded(
                          child: Center(
                            child: Text(
                              StoreOtherData.isNotEmpty
                                  ? (StoreOtherData.length > 5 ? '${StoreOtherData.substring(0, 5)}...' : StoreOtherData)
                                  : "กรอกสถานที่อื่น ๆ",
                              style: GoogleFonts.kanit(
                                textStyle: const TextStyle(
                                  color: Color(0xFF87898D),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.02),
                          child: Image.asset(
                            'assets/images/edit.png',
                              width: screenWidth * 0.08,
                              height: screenHeight * 0.05,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10), 
                GestureDetector(
                onTap: () {
                  if(StoreOtherData.isNotEmpty){
                  StoreOtherDataList.add(StoreOtherData);
                  }

                  setState(() {
                    // ฟังก์ชันตรวจสอบการมีห้องซ้ำ
                    bool isRoomExists = StoreOtherDataList.any((room) {
                      return roomDataCheck.contains(room); 
                    });

                    if (isRoomExists) {
                      // แจ้งเตือนว่ามีห้องอยู่แล้ว
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                              "ผิดพลาด",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              "มีห้องอยู่แล้วในตัวเลือก กรุณาลบในช่องสถานที่อื่น ๆ และเลือกห้องในตัวเลือก",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.04),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // ปิด Popup
                                },
                                child: Text(
                                  "ตกลง",
                                  style: GoogleFonts.kanit(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    } else if (StoreData.isEmpty && StoreOtherData.isEmpty && StoreOtherDataList.isEmpty) {
                      // แจ้งเตือนให้เลือกห้องก่อน
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text(
                              "ผิดพลาด",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold),
                            ),
                            content: Text(
                              "กรุณาเลือกห้อง",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.04),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // ปิด Popup
                                },
                                child: Text(
                                  "ตกลง",
                                  style: GoogleFonts.kanit(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      // ไปหน้าถัดไปตามปกติ ถ้าไม่มีห้องซ้ำและมีข้อมูล
                      widget.onNextPage(
                        StoreData, // ส่งข้อมูลห้อง
                        StoreOtherDataList, // ส่งข้อมูลสถานที่อื่น ๆ
                      );
                    }
                  });
                },
              child: Container(
                width: screenWidth * 0.39,
                height: screenHeight * 0.08,
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF374151),
                  border: Border.all(
                    color: Colors.black,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // จัดตำแหน่งแนวตั้งให้เป็นกลาง
              crossAxisAlignment: CrossAxisAlignment.center, // จัดตำแหน่งแนวนอนให้เป็นกลาง
              children: [
                // ใช้ Flexible เพื่อให้ภาพไม่เกิดการ overflow
                Flexible(
                  child: Image.asset(
                    'assets/images/fix-white.png',
                      width: screenWidth * 0.08,
                      height: screenHeight * 0.05,
                    fit: BoxFit.contain, // ปรับขนาดภาพให้ไม่เกินขนาดที่กำหนด
                  ),
                ),
                // ข้อความที่ปรับขนาดตามความสูงของหน้าจอ
                Flexible(
                  child: Text(
                    "ยืนยัน",
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: screenHeight * 0.02,
                      ),
                    ),
                  ),
                ),
              ],
            ),

              ),
            )

                ],
              ),
            )
          ],
        ),
      ),
      ),
    );
  }
  );
  }


  Future<void> _storeUserData(String name, String role) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    await prefs.setString('role_name', role);
  }

Future<void> _fetchRoom(BuildContext context, int selectedFloor) async {
  setState(() {
    isLoading = true;
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    final response = await http.get(
      Uri.parse('$apiURL/api/room/RoombyFloor/$selectedFloor'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      if (mounted) {
        setState(() {
          roomData = List<String>.from(
            data.where((room) => room['isnot_hide'] == true)
                .map((room) => room['room_number'].toString()),
          );
          isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      throw Exception('ไม่สามารถโหลดข้อมูลห้องได้: ${response.body}');
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
    print('Error fetching data: $e');
  }
}


Future<void> _fetchAllRooms(BuildContext context) async {
  setState(() {
    isLoading = true;
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;


    final response = await http.get(
      Uri.parse('$apiURL/api/room/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );


    if (response.statusCode == 200) {
      var data = json.decode(response.body);

      if (mounted) {
        setState(() {
          roomDataCheck = List<String>.from(
            data.where((room) => room['isnot_hide'] == true)
                .map((room) => room['room_number'].toString()),
          );
          isLoading = false;
        });
      }
    } else {
      print('Error: ${response.body}'); // Log ข้อความ Error
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      throw Exception('ไม่สามารถโหลดข้อมูลห้องได้: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e'); // Log Exception
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }

    // แสดงแจ้งเตือนให้ผู้ใช้
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อกับ Server')),
      );
    }
  }
}



Future<dynamic> _fetchfloor(BuildContext context) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');
    final response = await http.get(
      Uri.parse('$apiURL/api/room/floor'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('ไม่สามารถโหลดข้อมูลห้องได้: ${response.body}');
  } catch (e) {
    throw Exception('ไม่สามารถโหลดข้อมูลห้องได้: $e');
  }
}
void showInputDialog(BuildContext context) {
  final TextEditingController textController = TextEditingController(
    text: StoreOtherData.isNotEmpty ? StoreOtherData : '', // กำหนดค่าจาก StoreOtherData ถ้ามีค่า
  );

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('กรอกสถานที่อื่น ๆ', style: GoogleFonts.kanit(fontSize: 18)),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'กรุณากรอกสถานที่อื่น ๆ', // ข้อความแนะนำกรอกสถานที่
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog ถ้ายกเลิก
            },
            child: Text('ยกเลิก', style: GoogleFonts.kanit()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                String inputText = textController.text.trim();

                if (inputText.characters.isNotEmpty && inputText.characters.length <= 15) {

                  StoreOtherData = inputText; 
                  Navigator.pop(context);
                } else if (inputText.isEmpty) {
                  StoreOtherData = ""; 
                  Navigator.pop(context); // ปิด dialog
                } else {
                  Future.delayed(Duration(milliseconds: 100), () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text("ผิดพลาด", style: GoogleFonts.kanit(fontSize: 18)),
                          content: Text("สถานที่อื่น ๆ ไม่ควรเกิน 15 ตัวอักษร", style: GoogleFonts.kanit()),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text('ตกลง', style: GoogleFonts.kanit()),
                            ),
                          ],
                        );
                      },
                    );
                  });
                }
              });
              print('ข้อความที่พิมพ์: ${textController.text}');
            },
            child: Text('ตกลง', style: GoogleFonts.kanit()),
          ),
        ],
      );
    },
  );
}

void _showSelectFloor(Function(int selectedFloor) onFloorSelected) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    backgroundColor: Colors.white,
    builder: (BuildContext context) {
      return FutureBuilder(
        future: _fetchfloor(context),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No data available'));
          } else {
            var floorData = snapshot.data;
            var floorNumbers = floorData.map<int>((floor) {
              return int.tryParse(floor['first_digit'].toString()) ?? 0;
            }).toList();

            int selectedFloor = -1;

            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: screenWidth,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.04,
                          vertical: screenHeight * 0.01,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'เลือกชั้น',
                              style: GoogleFonts.kanit(
                                textStyle: TextStyle(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,  // ใช้ MainAxisSize.min เพื่อให้ Row ใช้พื้นที่น้อยที่สุด
                            mainAxisAlignment: MainAxisAlignment.end, // ชิดขวา
                            crossAxisAlignment: CrossAxisAlignment.center, // จัดตำแหน่งให้ตรงกลางในแนวตั้ง
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
                        )

                          ],
                        ),
                      ),
                      const Divider(),
                      SizedBox(height: screenHeight * 0.02),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: floorNumbers.length,
                        itemBuilder: (context, index) {
                          int number = floorNumbers[index];
                          Color buttonColor = selectedFloor == number ? Colors.green : Colors.white;
                          Color textColor = selectedFloor == number ? Colors.white : Colors.black;

                          return Padding(
                            padding: EdgeInsets.only(left: screenWidth * 0.02),
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(screenWidth * 0.2, screenHeight * 0.05),
                                      backgroundColor: buttonColor,
                                      side: const BorderSide(color: Colors.black),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        selectedFloor = number;
                                      });
                                    },
                                    child: Text(
                                      'ชั้น $number',
                                      style: GoogleFonts.kanit(
                                        textStyle: TextStyle(
                                          color: textColor,
                                          fontSize: screenWidth * 0.03,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: screenWidth * 0.02),
                              ],
                            ),
                          );
                        },
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(screenWidth * 0.2, screenHeight * 0.07),
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onFloorSelected(selectedFloor);
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
                      SizedBox(height: screenHeight * 0.02),
                    ],
                  ),
                );
              },
            );
          }
        },
      );
    },
  );
}
}
