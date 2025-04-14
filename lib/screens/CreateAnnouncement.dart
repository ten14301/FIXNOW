import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../UserProvider.dart';

class AnnouncementPage extends StatefulWidget {
  @override
  final String userName;
  const AnnouncementPage({Key? key, required this.userName}) : super(key: key);
  _AnnouncementPageState createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  TextEditingController messageController = TextEditingController();
  TextEditingController otherPlaceController = TextEditingController();
  TextEditingController expireDateController = TextEditingController();
  TextEditingController startDateController = TextEditingController();
  TextEditingController endDateController = TextEditingController();
  List<Map<String, dynamic>> announcements = [];
  List<String> floors = [];
  String selectedFloor = "กรุณาเลือกชั้น";
  List<Map<String, dynamic>> roomData = [];
  String selectedRoom = "กรุณาเลือกห้อง";
  String apiURL = dotenv.env['API_URL'] ?? '';
  bool isLoadingFloors = false;
  bool isLoadingRooms = false;
  bool isLoadingAnnouncements = false;

  @override
  void initState() {
    super.initState();
    fetchFloors();
    fetchAnnouncements();
  }

Future<void> fetchAnnouncements() async {
  setState(() {
    isLoadingAnnouncements = true;
  });

  try {
    // ดึง accessToken จาก UserProvider
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.get(
      Uri.parse('$apiURL/api/announcement'),
      headers: {
        'Authorization': 'Bearer $accessToken',
         'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> announcementData = json.decode(response.body);
      setState(() {
        announcements = List<Map<String, dynamic>>.from(announcementData);
      });
    } else {
      throw Exception("Failed to load announcements");
    }
  } catch (e) {
    print("Error fetching announcements: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to load announcements")),
    );
  } finally {
    if(mounted){
    setState(() {
      isLoadingAnnouncements = false;
    });
    }

  }
}

  Future<void> deleteAnnouncement(String announcementId) async {
  try {
    // ดึง accessToken จาก UserProvider
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.delete(
      Uri.parse('$apiURL/api/announcement/$announcementId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    print(announcementId);
    if (response.statusCode == 204) {
      fetchAnnouncements();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ลบประกาศสำเร็จ")),
      );
    } else {
      throw Exception("Failed to delete announcement");
    }
  } catch (e) {
    print("Error deleting announcement: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to delete announcement")),
    );
  }
}

void editAnnouncement(String announcementId, String currentMessage, String currentStart, String currentExpireDate) {
  TextEditingController editController = TextEditingController(text: currentMessage);
  TextEditingController startDateController = TextEditingController(text: currentStart);
  TextEditingController expireDateController = TextEditingController(text: currentExpireDate);
  String? errorMessage;

  Future<void> selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      controller.text = "${pickedDate.toLocal()}".split(' ')[0]; // แปลงเป็น YYYY-MM-DD
    }
  }

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text("แก้ไขประกาศ", style: GoogleFonts.kanit()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("ข้อความปัจจุบัน", style: GoogleFonts.kanit()),
                const SizedBox(height: 16),
                TextField(
                  controller: editController,
                  decoration: InputDecoration(
                    hintText: "แก้ไขข้อความ...",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text("วันที่เริ่ม", style: GoogleFonts.kanit()),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => selectDate(context, startDateController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: startDateController,
                      decoration: InputDecoration(
                        hintText: "เลือกวันที่เริ่ม",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text("วันหมดอายุ", style: GoogleFonts.kanit()),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => selectDate(context, expireDateController),
                  child: AbsorbPointer(
                    child: TextField(
                      controller: expireDateController,
                      decoration: InputDecoration(
                        hintText: "เลือกวันหมดอายุ",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (errorMessage != null)
                  Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("ยกเลิก", style: GoogleFonts.kanit()),
              ),
              ElevatedButton(
                onPressed: () async {
                  String updatedMessage = editController.text.trim();
                  String updatedStartDate = startDateController.text.trim();
                  String updatedExpireDate = expireDateController.text.trim();

                  if (updatedMessage.isEmpty) {
                    setState(() => errorMessage = "กรุณากรอกข้อความ");
                    return;
                  }
                if (updatedMessage == currentMessage) {
                    setState(() => errorMessage = "ข้อความไม่สามารถเหมือนเดิมได้");
                    return;
                  }
                  if (updatedStartDate.isEmpty || updatedExpireDate.isEmpty) {
                    setState(() => errorMessage = "กรุณาเลือกวันที่เริ่มต้นและวันหมดอายุ");
                    return;
                  }

                  try {
                    DateTime startDate = DateTime.parse(updatedStartDate);
                    DateTime expireDate = DateTime.parse(updatedExpireDate);
                    DateTime oldDate = DateTime.parse(startDateController.text);



                    startDate = DateTime(startDate.year, startDate.month, startDate.day);
                    expireDate = DateTime(expireDate.year, expireDate.month, expireDate.day);
                    oldDate = DateTime(oldDate.year, oldDate.month, oldDate.day);
                  

                    if (startDate.isBefore(oldDate) ) {
                      setState(() => errorMessage = "วันเริ่มต้นต้องไม่เก่ากว่าวันที่เดิม");
                      return;
                    }
                    if (expireDate.isBefore(startDate)) {
                      setState(() => errorMessage = "วันหมดอายุต้องไม่น้อยกว่าวันที่เริ่มต้น");
                      return;
                    }
                    if (startDate.isAtSameMomentAs(expireDate)) {
                      setState(() => errorMessage = "วันที่เริ่มต้นและวันหมดอายุไม่สามารถเป็นวันเดียวกันได้");
                      return;
                    }

                    // ถ้าผ่านเงื่อนไขทั้งหมด ให้ทำการอัปเดตประกาศ
                    await updateAnnouncement(announcementId, updatedMessage, updatedStartDate, updatedExpireDate);
                    Navigator.of(context).pop();
                  } catch (e) {
                    if(mounted){
                    setState(() => errorMessage = "รูปแบบวันที่ไม่ถูกต้อง");
                    }

                  }
                },
                child: Text("บันทึก", style: GoogleFonts.kanit()),
              ),
            ],
          );
        },
      );
    },
  );
}



Future<void> updateAnnouncement(
  String announcementId, 
  String updatedMessage,
  String updatedStartDate,
  String updatedExpireDate,

) async {  
  if (updatedMessage.characters.length > 150) {
      _showErrorDialog("ข้อความต้องไม่เกิน 150 ตัวอักษร");
      return;
  }

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.put(
      Uri.parse('$apiURL/api/announcement/$announcementId'),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'info': updatedMessage,
        'start': updatedStartDate,
        'expire': updatedExpireDate, 
      }),
    );

    if (response.statusCode == 200) {
      fetchAnnouncements(); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("แก้ไขประกาศสำเร็จ")),
      );
    } else {
      throw Exception("Failed to update announcement");
    }
  } catch (e) {
    print("Error updating announcement: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to update announcement")),
    );
  }
}




Future<void> fetchFloors() async {
  setState(() {
    isLoadingFloors = true;
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.get(
      Uri.parse('$apiURL/api/room/floor'),
      headers: {
        'Authorization': 'Bearer $accessToken',  // ใส่ Access Token ใน Header
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> floorData = json.decode(response.body);
      setState(() {
        floors = floorData.map((floor) => floor['first_digit'].toString()).toList();
      });
    } else {
      throw Exception("Failed to load floors");
    }
  } catch (e) {
    print("Error fetching floors: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load floors")),
      );
    }
  } finally {
    if(mounted){
    setState(() {
      isLoadingFloors = false;
    });
    }

  }
}


Future<void> fetchRoomsByFloor(String floor) async {
  setState(() {
    isLoadingRooms = true;
    roomData = [];
    selectedRoom = "กรุณาเลือกห้อง";
    otherPlaceController.clear();
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.get(
      Uri.parse('$apiURL/api/room/RoombyFloor/$floor'),
      headers: {
        'Authorization': 'Bearer $accessToken',  // ใส่ Access Token ใน Header
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        roomData = List<Map<String, dynamic>>.from(data);
      });
    } else {
      throw Exception("Failed to load rooms");
    }
  } catch (e) {
    print("Error fetching rooms: $e");
  } finally {
    setState(() {
      isLoadingRooms = false;
    });
  }
}

void _showErrorDialog(String message) {
  if (!mounted) return; // ตรวจสอบว่ายังติดอยู่กับหน้าหรือไม่
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("เกิดข้อผิดพลาด", style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
      content: Text(message, style: GoogleFonts.kanit()),
      actions: [
        TextButton(
          onPressed: () {
            if (mounted) Navigator.pop(context); // ปิดการแจ้งเตือน
          },
          child: Text("ตกลง", style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
void showCreateAnnouncementPopup() {
  String? errorMessage;  // To store error messages

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.1,
        ),
        child: StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "สร้างประกาศ",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedFloor,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "ชั้น",
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: "กรุณาเลือกชั้น",
                          child: Text("กรุณาเลือกชั้น"),
                        ),
                        ...floors.map((floor) {
                          return DropdownMenuItem(
                            value: floor,
                            child: Text("ชั้น $floor"),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFloor = value!;
                          if (selectedFloor != "กรุณาเลือกชั้น") {
                            fetchRoomsByFloor(selectedFloor).then((_) {
                              setState(() {});
                            });
                          } else {
                            roomData = [];
                            selectedRoom = "กรุณาเลือกห้อง";
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedRoom,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: "ห้อง",
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: "กรุณาเลือกห้อง",
                          child: Text("กรุณาเลือกห้อง"),
                        ),
                        ...roomData.map((room) {
                          return DropdownMenuItem<String>(
                            value: room['room_id'].toString(),
                            child: Text("ห้อง ${room['room_number']}"),
                          );
                        }).toList(),
                        const DropdownMenuItem(
                          value: "ห้องอื่น ๆ",
                          child: Text("ห้องอื่น ๆ"),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedRoom = value!;
                          if (selectedRoom != "กรุณาเลือกห้อง" && selectedRoom != "ห้องอื่น ๆ") {
                            otherPlaceController.clear();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otherPlaceController,
                      enabled: selectedRoom == "ห้องอื่น ๆ" && selectedFloor != "กรุณาเลือกชั้น",
                      decoration: const InputDecoration(
                        hintText: "ห้องอื่น ๆ",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: messageController,
                      decoration: InputDecoration(
                        hintText: "เพิ่มข้อความ....",
                        border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(16.0),
                        hintStyle: TextStyle(fontSize: 16, color: Colors.grey[500]),
                      ),
                      maxLines: 10,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: startDateController,
                      decoration: InputDecoration(
                        hintText: "วันเริ่มต้น (YYYY-MM-DD)",
                        border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(16.0),
                      ),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            startDateController.text = "${selectedDate.toLocal()}".split(' ')[0];
                            DateTime currentDate = DateTime.now();
                            DateTime startDate = DateTime.parse(startDateController.text);

                            currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                            startDate = DateTime(startDate.year, startDate.month, startDate.day);
                            if (startDate.isBefore(currentDate)) {
                              errorMessage = "วันเริ่มต้นต้องไม่เก่ากว่าวันที่ปัจจุบัน";
                              startDateController.clear();
                            } else {
                              errorMessage = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: expireDateController,
                      decoration: InputDecoration(
                        hintText: "วันหมดอายุ (YYYY-MM-DD)",
                        border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.all(16.0),
                      ),
                      onTap: () async {
                        FocusScope.of(context).requestFocus(FocusNode());
                        DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            expireDateController.text = "${selectedDate.toLocal()}".split(' ')[0];
                            DateTime currentDate = DateTime.now();
                            if (expireDateController.text.isNotEmpty) {
                              DateTime expireDate = DateTime.parse(expireDateController.text);
                              if (expireDate.isBefore(currentDate)) {
                                errorMessage = "วันหมดอายุต้องไม่เก่ากว่าวันที่ปัจจุบัน";
                                expireDateController.clear();
                              } else {
                                errorMessage = null;
                              }
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (errorMessage != null)
                      Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          String message = messageController.text;
                          String? otherPlace = otherPlaceController.text.isNotEmpty
                              ? otherPlaceController.text
                              : null;
                          String? roomId = selectedRoom != "กรุณาเลือกห้อง"
                              ? selectedRoom
                              : null;
                          String? expireDate = expireDateController.text;
                          String? startDate = startDateController.text;

                          if (message.isEmpty) {
                            setState(() {
                              errorMessage = "กรุณากรอกข้อความ";
                            });
                            return;
                          }

                          if (roomId == null && otherPlace == null) {
                            setState(() {
                              errorMessage = "กรุณาเลือกห้องหรือกรอกห้องอื่น ๆ";
                            });
                            return;
                          }

                          if (startDate.isNotEmpty && expireDate.isNotEmpty) {
                            try {
                              DateTime currentDate = DateTime.now();
                              DateTime startDateTime = DateTime.parse(startDate);
                              DateTime expireDateTime = DateTime.parse(expireDate);

                              currentDate = DateTime(currentDate.year, currentDate.month, currentDate.day);
                              startDateTime = DateTime(startDateTime.year, startDateTime.month, startDateTime.day);
                              expireDateTime = DateTime(expireDateTime.year, expireDateTime.month, expireDateTime.day);
                              if (startDateTime.isBefore(currentDate)) {
                                setState(() {
                                  errorMessage = "วันเริ่มต้นต้องไม่เก่ากว่าวันที่ปัจจุบัน";
                                });
                                startDateController.clear();
                              } else if (expireDateTime.isBefore(currentDate)) {
                                setState(() {
                                  errorMessage = "วันหมดอายุต้องไม่เก่ากว่าวันที่ปัจจุบัน";
                                });
                                expireDateController.clear();
                              } else if (startDateTime.isAfter(expireDateTime)) {
                                setState(() {
                                  errorMessage = "วันที่เริ่มต้นต้องน้อยกว่าวันหมดอายุ";
                                });
                                startDateController.clear();
                                expireDateController.clear();
                              } else if (startDateTime.isAtSameMomentAs(expireDateTime)) {
                                setState(() {
                                  errorMessage = "วันที่เริ่มต้นและวันที่หมดอายุไม่สามารถเป็นวันเดียวกันได้";
                                });
                                startDateController.clear();
                                expireDateController.clear();
                              }
                            } catch (e) {
                              setState(() {
                                errorMessage = "กรุณากรอกวันที่ให้ถูกต้อง";
                              });
                              startDateController.clear();
                              expireDateController.clear();
                            }
                          }

                          if (errorMessage == null) {
                            createAnnouncement(message, roomId, otherPlace, expireDate, startDate);
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          "โพสต์",
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}



Future<void> createAnnouncement(
  String message, String? roomId, String? otherPlace, String? expireDate, String? startDate) async {

    if (message.characters.length > 150) {
      _showErrorDialog("ข้อความต้องไม่เกิน 150 ตัวอักษร");
      return;
    }

  if (otherPlace != null && otherPlace.length > 50) {
    // แสดง AlertDialog แจ้งเตือนหาก otherPlace เกิน 50 ตัวอักษร
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("ผิดพลาด", style: GoogleFonts.kanit(fontSize: 18)),
          content: Text("สถานที่อื่น ๆ ไม่ควรเกิน 50 ตัวอักษร", style: GoogleFonts.kanit()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ปิด Popup
              },
              child: Text('ตกลง', style: GoogleFonts.kanit()),
            ),
          ],
        );
      },
    );
    return; // หยุดการทำงานเมื่อพบว่า otherPlace เกินขีดจำกัด
  }

  final Map<String, dynamic> announcementData = {
    'user_name': widget.userName,
    'info': message,
    'room_id': roomId,
    'other_place': otherPlace,
    'expire': expireDate,
    'start': startDate, 
  };

  print("Sending data: ${json.encode(announcementData)}");

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.post(
      Uri.parse('$apiURL/api/announcement'),
      headers: {
        'Authorization': 'Bearer $accessToken',  // ใส่ Access Token ใน Header
        'Content-Type': 'application/json',
      },
      body: json.encode(announcementData),
    );

    if (response.statusCode == 201) { 
      fetchAnnouncements();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("โพสต์ประกาศสำเร็จ")),
      );
    } else {
      throw Exception("Failed to create announcement: ${response.body}");
    }
  } catch (e) {
    print("Error creating announcement: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to create announcement")),
    );
  }
}


String convertToBangkokTime(String utcTime) {
  DateTime utcDateTime = DateTime.parse(utcTime).toUtc(); // แปลงเป็น UTC DateTime
  DateTime bangkokTime = utcDateTime.add(Duration(hours: 7));

  // ฟอร์แมตเวลาให้อยู่ในรูปแบบที่ต้องการ โดยไม่แสดงเวลา
  final DateFormat formatter = DateFormat('yyyy-MM-dd'); // ปรับฟอร์แมตให้แสดงแค่วัน
  return formatter.format(bangkokTime); // คืนค่าที่แปลงแล้วในรูปแบบ String
}


@override
Widget build(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  return Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'ประกาศ',
            style: GoogleFonts.kanit(
              fontSize: max(screenWidth, screenHeight) * 0.02,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        Expanded(
          child: isLoadingAnnouncements
              ? Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: announcements.length,
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    String message = announcement['info']?.toString() ?? 'ไม่มีข้อความ';
                    String roomNumber = announcement['room_number']?.toString() ?? 'ไม่ระบุ';
                    String announcementId = announcement['id']?.toString() ?? 'ไม่ระบุ';
                    String start = convertToBangkokTime(announcement['start']?.toString() ?? 'ไม่ระบุ');
                    String expire = convertToBangkokTime(announcement['expire']?.toString() ?? 'ไม่ระบุ');

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 4,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16.0),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.green,
                          child: Icon(Icons.announcement, color: Colors.white),
                        ),
                        title: Text(
                          message,
                          style: GoogleFonts.kanit(fontSize: screenWidth * 0.04, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "ห้อง: $roomNumber",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.03, color: Colors.grey[700]),
                            ),
                            Text(
                              "เริ่ม: $start",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.03, color: Colors.grey[700]),
                            ),
                            Text(
                              "หมดอายุ: $expire",
                              style: GoogleFonts.kanit(fontSize: screenWidth * 0.03, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                editAnnouncement(announcement['announcement_id'].toString(), announcement['info'],start,expire);
                              },
                            ),
                          IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              // แสดง confirmation dialog ก่อนลบประกาศ
                              showDialog(
                                context: context,
                                builder: (BuildContext dialogContext) {
                                  return AlertDialog(
                                    title: Text("ยืนยันการลบ"),
                                    content: Text("คุณต้องการลบประกาศนี้หรือไม่?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(dialogContext).pop(); // ปิด Dialog
                                        },
                                        child: Text("ยกเลิก"),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          // เรียกใช้ฟังก์ชันลบประกาศ
                                          deleteAnnouncement(announcement['announcement_id'].toString());
                                          Navigator.of(dialogContext).pop(); // ปิด Dialog
                                        },
                                        child: Text("ลบ"),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
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
    floatingActionButton: FloatingActionButton(
      onPressed: showCreateAnnouncementPopup,
      backgroundColor: Colors.green,
      child: const Icon(Icons.add),
    ),
  );
}
}
