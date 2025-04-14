import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'Chat.dart';
import 'package:http/http.dart' as http;
import '../notification_status_follow_provider.dart';
import 'package:provider/provider.dart';
import '../notification_hasFetchChange.dart';
import '../UserProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../component/video_player.dart';

class WaitProgress extends StatefulWidget {
  final dynamic post;
  final String userName;
  final List<String> Textinput;
  final List<List<XFile>> Files;

  const WaitProgress({
    required this.post,
    required this.Textinput,
    required this.Files,
    required this.userName,
    Key? key,
  }) : super(key: key);

  @override
  _WaitProgressState createState() => _WaitProgressState();
}

class _WaitProgressState extends State<WaitProgress> {
  bool showChatPage = false;
  VideoPlayerController? _videoController;
  String apiURL = dotenv.env['API_URL'] ?? '';
  List<dynamic> posts = [];
  String errorMessage = '';
  bool isLoading = true;
  Uint8List? decodeBase64(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      String cleanedBase64 = base64String.replaceAll(RegExp(r'[\s\n\r]+'), '');
      return base64Decode(cleanedBase64);
    } catch (e) {
      return null;
    }
  }
@override
  void initState() {
    super.initState();
    fetchPosts();
  }
  String truncateUsername(String username, int maxLength) {
    if (username.length > maxLength) {
      return '${username.substring(0, maxLength)}...';
    }
    return username;
  }

  Color getStatusColor(String status, int index, int currentIndex) {
    return index <= currentIndex ? Colors.green : Colors.grey.shade400;
  }

  String _truncateText(String text) {
    if (text.length > 5) {
      return text.substring(0, 5) + '...';
    } else {
      return text;
    }
  }

  DateTime _parseDateTime(String? date, String? time) {
    try {
      DateTime utcDate = DateTime.parse(date ?? '').toUtc();
      DateTime finalDateTime = utcDate;
      if (time != null && time.isNotEmpty) {
        finalDateTime = DateTime(
          utcDate.year,
          utcDate.month,
          utcDate.day,
          int.parse(time.split(':')[0]), // ชั่วโมง
          int.parse(time.split(':')[1]), // นาที
          int.parse(time.split(':')[2].split('.')[0]), // วินาที
        );
      }
      finalDateTime = finalDateTime.add(Duration(hours: 7));
      return finalDateTime;
    } catch (e) {
      return DateTime(1900); // หากไม่สามารถแปลงได้จะใช้วันที่ปี 1900
    }
  }
Future<void> fetchPosts() async {
  setState(() {
    isLoading = true; // ตั้งค่าก่อนเริ่มโหลด
  });

  String requestId = widget.post['request_id'].toString();
  String apiUrl = "$apiURL/api/maintenance/$requestId";
  final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
  try {
    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $accessToken', // เพิ่ม Authorization header
        'Content-Type': 'application/json',

      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);

      if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
        print("data $jsonResponse");

        if (mounted) {
          setState(() {
            var data = jsonResponse['data'];
            if (data is List) {
              posts = data
                ..sort((a, b) {
                  DateTime dateTimeA = _parseDateTime(a['date'], a['time']);
                  DateTime dateTimeB = _parseDateTime(b['date'], b['time']);
                  return dateTimeB.compareTo(dateTimeA);
                });
            } else {
              // ถ้าไม่ใช่ List ให้แปลงเป็น List
              posts = [data];
            }

            isLoading = false;
          });
        }
      } else {
        _handleNoData();
      }
    } else {
      _handleNoData();
    }
  } catch (e) {
    print("Error: $e");
    _handleNoData();
  }
}



// ฟังก์ชันสำหรับกรณีไม่มีข้อมูล
void _handleNoData() {
  if (mounted) {
    setState(() {
      errorMessage = "ไม่มีข้อมูล";
      isLoading = false;
    });
  }
}

@override
Widget build(BuildContext context) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;

  if (posts.isNotEmpty) {
    print("fetch ${posts[0]}");
  DateTime dateTime = _parseDateTime(posts[0]['date'], posts[0]['time']);
  String formattedDateTime = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  double screenWidth = MediaQuery.of(context).size.width;
    // ดึงค่า room_number, status, description, date และ time จาก posts
    String room = "${posts[0]['room_number'] != null 
      ? _truncateText(posts[0]['room_number'].toString().trim()) 
      : _truncateText(posts[0]['other_place']?.toString().trim() ?? '')}";
    String status = posts[0]['current_status'] ?? "ไม่มีสถานะ";
    String description = posts[0]['request_info'] ?? "ไม่มีคำอธิบาย";

    // รวม date และ time เป็นรูปแบบที่ฟังก์ชัน formatDateToBangkokTime ต้องการ
    String dateTimeString = formattedDateTime;

    String username = posts[0]['user_name'] ?? "ไม่ทราบชื่อผู้ใช้";

    int currentIndex;
    switch (status) {
      case "รอรับเรื่อง":
        currentIndex = 0;
        break;
      case "รอการสำรวจ":
        currentIndex = 1;
        break;
      case "อยู่ระหว่างการแก้ไข":
        currentIndex = 2;
        break;
      case "ดำเนินการเสร็จสิ้น":
        currentIndex = 3;
        break;
      default:
        currentIndex = 0;
    }

    List<String> fileUrls = [];
    if (widget.post['file_urls']![0] == null) {
      fileUrls = [];
    } else {
      fileUrls = List<String>.from(widget.post['file_urls'] ?? []);
    }

    List<Widget> mediaWidgets = [];

    // ตรวจสอบว่าเป็นไฟล์วิดีโอหรือภาพ
    for (var fileUrl in fileUrls) {
      if (fileUrl.endsWith('.mp4')) {
        mediaWidgets.add(VideoPlayerWidget(
          filePath: fileUrl,
          onPlayPause: () {
            setState(() {});
          },
          onControllerCreated: (controller) {
            setState(() {
              _videoController = controller;
            });
          },
        ));
      } else if (fileUrl.endsWith('.png') || fileUrl.endsWith('.jpg') || fileUrl.endsWith('.jpeg')) {
        mediaWidgets.add(
          ClipRRect(
            child: Image.network(
              fileUrl,
              width: screenWidth * 0.6,
              fit: BoxFit.cover,
            ),
          ),
        );
      }
    }

    return Consumer2<NotificationFollowProvider,NotificationHasChangeProvider>(
      builder: (context, chatProvider, hasChangeProvider, child) {
      final showChange = hasChangeProvider.hasMaintenanceNotification;
      if (showChange) {
        // ใช้ addPostFrameCallback เพื่อให้แน่ใจว่า fetchPosts() ถูกเรียกหลังจากการสร้าง widget เสร็จ
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print("Fetching new data...");
          fetchPosts();  // เรียกฟังก์ชันที่ต้องการแค่ครั้งเดียว
          hasChangeProvider.clearMaintenanceNotification();  // เคลียร์ notification
        });
      }

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: screenHeight * 0.03,
              horizontal: screenWidth * 0.05,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        3,
                        (index) => Expanded(
                          child: Container(
                            height: 15,
                            color: getStatusColor(status, index, currentIndex),
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                        (index) => CircleAvatar(
                          radius: screenWidth * 0.06,
                          backgroundColor:
                              index <= currentIndex ? Colors.green : Colors.grey,
                          child: index <= currentIndex
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.04),
                Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.zero,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 5,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "ห้อง : $room",
                            style: GoogleFonts.kanit(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "สถานะ : $status",
                            style: GoogleFonts.kanit(
                              fontSize: screenWidth * 0.045,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Colors.grey.shade400,
                        thickness: 1,
                        height: screenHeight * 0.03,
                      ),
                      if (status == "รอการสำรวจ")
                        SizedBox(
                          height: screenHeight * 0.6,
                          child: ChatPage(
                            post: widget.post,
                            userName: username,
                            roleName: "Customer",
                          ),
                        )
                      else if (status == "อยู่ระหว่างการแก้ไข")
                        Center(
                          child: showChatPage
                              ? SizedBox(
                                  height: screenHeight * 0.6,
                                  child: ChatPage(
                                    post: widget.post,
                                    userName: username,
                                    roleName: "Customer",
                                  ),
                                )
                              : Container(
                                  width: screenWidth * 0.8,
                                  padding: EdgeInsets.all(screenWidth * 0.05),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.2),
                                        spreadRadius: 2,
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: screenWidth * 0.12,
                                        backgroundColor: Colors.grey.shade100,
                                        child: Icon(
                                          Icons.build,
                                          size: screenWidth * 0.12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.02),
                                      Text(
                                        "อยู่ระหว่างการแก้ไข",
                                        style: GoogleFonts.kanit(
                                          fontSize: screenWidth * 0.05,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.01),
                                      Text(
                                       dateTimeString, // วันที่และเวลา
                                        style: GoogleFonts.kanit(
                                          fontSize: screenWidth * 0.04,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      SizedBox(height: screenHeight * 0.03),
                                      ElevatedButton(
                                        onPressed: () {
                                          // เปลี่ยนไปแสดง ChatPage
                                          setState(() {
                                            showChatPage = true;
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: EdgeInsets.symmetric(
                                            vertical: screenHeight * 0.015,
                                            horizontal: screenWidth * 0.2,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                        ),
                                        child: Text(
                                          "แชท",
                                          style: GoogleFonts.kanit(
                                            fontSize: screenWidth * 0.045,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        )
                      else if (status == "ดำเนินการเสร็จสิ้น")
                        Center(
                          child: Container(
                            width: screenWidth * 0.8,
                            padding: EdgeInsets.all(screenWidth * 0.05),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: screenWidth * 0.2, // ขนาดไอคอน
                                ),
                                SizedBox(height: screenHeight * 0.02),
                                Text(
                                  "ดำเนินการเสร็จสิ้น",
                                  style: GoogleFonts.kanit(
                                    fontSize: screenWidth * 0.05,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Text(
                                  dateTimeString, // วันที่และเวลา
                                  style: GoogleFonts.kanit(
                                    fontSize: screenWidth * 0.04,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.08,
                                  backgroundColor: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.black54,
                                    size: screenWidth * 0.06,
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.01),
                                Text(
                                  truncateUsername(username, 10),
                                  style: GoogleFonts.kanit(
                                    fontSize: screenWidth * 0.035,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: screenWidth * 0.03),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(screenWidth * 0.04),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD9E7F2),
                                  borderRadius: BorderRadius.circular(10),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      description,
                                      style: GoogleFonts.kanit(
                                        fontSize: screenWidth * 0.04,
                                        fontWeight: FontWeight.w400,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    if (mediaWidgets.isNotEmpty) ...mediaWidgets,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                ],
              ),
                ),
            ],
          ),
          ),
        );
      },
    );
  } else {
    print("posts is empty");
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(), // แสดงสถานะ loading
      ),
    );
  }
  }
}

