import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../notification_status_follow_provider.dart';
import '../notification_hasFetchChange.dart';
import '../notification_maintenance_provider.dart';
import '../notification_follow_provider_initial.dart';
import '../UserProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../component/video_player.dart';
import 'package:path/path.dart' as path;

class FollowRequest extends StatefulWidget {
  final String userName;
  final String roleName;
  final Function(dynamic)? onSelected;

  const FollowRequest({
    Key? key,
    required this.userName,
    required this.roleName,
    this.onSelected,
  }) : super(key: key);

  @override
  _FollowRequestState createState() => _FollowRequestState();
}

class _FollowRequestState extends State<FollowRequest> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  VideoPlayerController? _videoController;
  bool hasFetched = false;
  String apiURL = dotenv.env['API_URL'] ?? '';
  void _togglePlayPause() {
    if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
  String apiUrl = "$apiURL/api/maintenance/user/${widget.userName}";

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $accessToken",  // เพิ่ม Authorization Header
        "Content-Type": "application/json",      // เพิ่ม Content-Type Header
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
        print(jsonResponse['data']);
        if (mounted) {
          setState(() {
            posts = jsonResponse['data']
              ..sort((a, b) {
                DateTime dateTimeA = _parseDateTime(a['date'], a['time']);
                DateTime dateTimeB = _parseDateTime(b['date'], b['time']);
                return dateTimeB.compareTo(dateTimeA); // เรียงใหม่ไปเก่า
              });
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = "ไม่มีข้อมูล";
            isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          errorMessage = "ไม่มีข้อมูล";
          isLoading = false;
        });
      }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        errorMessage = "ไม่มีข้อมูล";
        isLoading = false;
      });
    }
  }
}
Future<void> updateRead(String requestId, String userName) async { 
  String apiUrl = "$apiURL/api/maintenance/updateReadRequests/$requestId?userName=$userName"; // ส่ง userName ไปกับ URL

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    final response = await http.put(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success'] == true) {
        print("อัปเดตสถานะการอ่านสำเร็จ: $requestId");
      } else {
        print("อัปเดตสถานะการอ่านไม่สำเร็จ: ${jsonResponse['message']}");
      }
    } else {
      print("เกิดข้อผิดพลาด: ${response.statusCode}");
    }
  } catch (e) {
    print("ข้อผิดพลาดในการอัปเดตสถานะการอ่าน: $e");
  }
}


DateTime _parseDateTime(String? date, String? time) {
  try {
    // แปลงวันที่จาก UTC มาเป็นเวลาในเขตเวลา Bangkok (UTC +7)
    DateTime utcDate = DateTime.parse(date ?? '').toUtc();
    
    // กำหนดเวลาหากมีข้อมูลเวลา
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

    // เปลี่ยนจาก UTC เป็นเวลา Bangkok
    finalDateTime = finalDateTime.add(Duration(hours: 7)); // UTC +7 สำหรับ Bangkok
    
    return finalDateTime;
  } catch (e) {
    return DateTime(1900); // หากไม่สามารถแปลงได้จะใช้วันที่ปี 1900
  }
}


  Color getStatusColor(String? status) {
    switch (status) {
      case 'รอรับเรื่อง':
        return Colors.red;
      case 'รอการสำรวจ':
        return Colors.green;
      case 'อยู่ระหว่างการดำเนินการแก้ไข':
        return Colors.blue;
      case 'ดำเนินการเสร็จสิ้น':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
Widget buildImageGallery(dynamic imageData) {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  double imageWidth = screenWidth * 0.2;
  double imageHeight = screenHeight * 0.2;

  if (imageData is List && imageData.isNotEmpty) {
    List<String> imageUrls = List<String>.from(imageData.where((url) => url != null));

    if (imageUrls.isNotEmpty) {
      String firstImage = imageUrls[0];
      print("First image: $firstImage");

      // ใช้ path.extension() เพื่อตรวจสอบนามสกุลไฟล์
      String extension = path.extension(Uri.parse(firstImage).path).toLowerCase();

      if (imageUrls.isNotEmpty) {
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: extension == '.png' || extension == '.jpg' || extension == '.jpeg'
                  ? Image.network(
                      firstImage,
                      width: imageWidth,
                      height: imageHeight,
                      fit: BoxFit.contain,
                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        } else {
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                  : null,
                            ),
                          );
                        }
                      },
                      errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                        return buildDefaultImage(imageWidth);
                      },
                    )
                  : extension == '.mp4'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            width: imageWidth,
                            height: imageHeight,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: VideoPlayerWidget(
                                filePath: firstImage,
                                onPlayPause: _togglePlayPause,
                                onControllerCreated: (controller) {},
                                hideSlider: true,
                              ),
                            ),
                          ),
                        )
                      : buildDefaultImage(imageWidth), 
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text("รูปภาพ/วิดีโอทั้งหมด"),
                      content: Container(
                        width: screenWidth,
                        height: screenHeight * 0.8,
                        child: SingleChildScrollView(
                          child: Column(
                            children: imageUrls.map((file) {
                              String fileExtension = path.extension(Uri.parse(file).path).toLowerCase();
                              if (fileExtension == '.mp4') {
                                return Container(
                                  width: screenWidth * 0.8,
                                  height: screenHeight * 0.4,
                                  child: VideoPlayerWidget(
                                    filePath: file,
                                    onPlayPause: _togglePlayPause,
                                    onControllerCreated: (controller) {},
                                  ),
                                );
                              } else if (fileExtension == '.png' || fileExtension == '.jpg' || fileExtension == '.jpeg') {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    file,
                                    width: screenWidth * 0.8,
                                    height: screenHeight * 0.4,
                                    fit: BoxFit.contain,
                                    errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                                      return buildDefaultImage(screenWidth * 0.8);
                                    },
                                  ),
                                );
                              }
                              return Container();
                            }).toList(),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text("ปิด"),
                        ),
                      ],
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: screenWidth * 0.04,
                  backgroundColor: Colors.grey.withOpacity(0.7),
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      } else {
        if (extension != '.mp4') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.network(
              firstImage,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                return buildDefaultImage(imageWidth);
              },
            ),
          );
        } else {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: imageWidth,
              height: imageHeight,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoPlayerWidget(
                  filePath: firstImage,
                  onPlayPause: _togglePlayPause,
                  onControllerCreated: (controller) {},
                  hideSlider: true,
                ),
              ),
            ),
          );
        }
      }
    }
  }

  return buildDefaultImage(imageWidth);
}



Widget buildDefaultImage(double width) {
  return Container(
    width: width,
    height: width,
    color: Colors.grey,
    child: const Icon(Icons.image_not_supported),
  );
}



Widget buildPost(dynamic post) {
  DateTime dateTime = _parseDateTime(post['date'], post['time']);
  String formattedDateTime = "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  double screenWidth = MediaQuery.of(context).size.width;
  double imageSize = screenWidth * 0.2;  // กำหนดขนาดคงที่สำหรับรูปหรือวีดีโอ

  String requestId = post['request_id'].toString();
  bool showStatusChange = Provider.of<NotificationFollowProvider>(context).statusFollowMessages[requestId] ?? false;
  return Column(
    children: [
      GestureDetector(
        onTap: () async {
          if (widget.onSelected != null) {
            await updateRead(requestId, post['user_name']);
            widget.onSelected!(post);
          }
          Provider.of<NotificationFollowProvider>(context, listen: false).removeStatusFollowMessage(requestId);

        },
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: imageSize,
                    height: imageSize,
                    child: buildImageGallery(post['file_urls']),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: post['room_number'] != null 
                                    ? 'ห้อง: ' 
                                    : (post['other_place'] != null ? 'สถานที่: ' : ''), // หัวข้อเป็นตัวหนา
                                style: GoogleFonts.kanit(
                                  fontSize: screenWidth * 0.03,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: post['room_number']?.toString() ?? post['other_place']?.toString() ?? 'ไม่มีข้อมูล', // ค่าของห้องหรือสถานที่
                                style: GoogleFonts.kanit(
                                  fontSize: screenWidth * 0.03,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // แสดง "รายละเอียดการแจ้ง" (สีดำ) + request_info (สีเทา)
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.kanit(fontSize: screenWidth * 0.03),
                            children: [
                              TextSpan(
                                text: "รายละเอียดการแจ้ง: ",
                                style: TextStyle(color: Colors.black,
                                fontWeight: FontWeight.bold,
                                ), // สีดำ

                                
                              ),
                              TextSpan(
                                text: post['request_info'] != null && post['request_info']!.isNotEmpty
                                    ? (post['request_info']!.length > 10
                                        ? '${post['request_info']!.substring(0, 10)}...'
                                        : post['request_info'])
                                    : 'ไม่มีคำอธิบาย',
                                style: TextStyle(color: Colors.grey), // สีเทา
                              ),
                            ],
                          ),
                        ),

                        // แสดง "การเปลี่ยนแปลงสถานะล่าสุด" (สีดำ) + date time (สีเทา)
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.kanit(fontSize: screenWidth * 0.03),
                            children: [
                              TextSpan(
                                text: "การเปลี่ยนแปลงสถานะล่าสุด: ",
                                style: TextStyle(color: Colors.black,
                                fontWeight: FontWeight.bold,
                                ), // สีดำ
                              ),
                              TextSpan(
                                text: formattedDateTime,
                                style: TextStyle(color: Colors.grey), // สีเทา
                              ),
                            ],
                          ),
                        ),

                        Row(
                          children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'สถานะ: ', // คำว่า "สถานะ:" เป็นตัวหนา
                                  style: GoogleFonts.kanit(
                                    fontSize: screenWidth * 0.03,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: post['current_status'] ?? 'ไม่มีข้อมูล', 
                                  style: GoogleFonts.kanit(
                                    fontSize: screenWidth * 0.03,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.01), 
                            Icon(
                              Icons.circle,
                              size: MediaQuery.of(context).size.width * 0.02,
                              color: getStatusColor(post['current_status']),
                            ),
                          ],
                        ),
                        if (post['last_action_user_name'] != null) 
                        Text(
                          'คนที่แก้ไขสถานะล่าสุด: ${post['last_action_user_name'] ?? 'ไม่ทราบ'}',
                          style: GoogleFonts.kanit(
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showStatusChange ||  post['is_read'] == false)
                Positioned(
                  right: 8.0,
                  top: 8.0,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.circle,
                      color: Colors.red,
                      size: 12,
                    ),
                  ),
                ),

              Positioned(
                right: screenWidth * 0.03,
                top: (screenWidth * 0.2) / 2 - (screenWidth * 0.04 / 2),
                child: Icon(
                  Icons.arrow_forward_ios, // ลูกศรไปข้างหน้า
                  size: screenWidth * 0.04,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
      ),
      Divider(thickness: 0.5, color: Colors.grey[300]), // เส้นแบ่งระหว่างโพสต์
    ],
  );
}


@override
Widget build(BuildContext context) {
  // ตรวจสอบสถานะการโหลด
  if (isLoading) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // ตรวจสอบข้อผิดพลาด
  if (errorMessage.isNotEmpty) {
    return Scaffold(
      backgroundColor: Colors.white,    
      body: Center(
        child: Text(
          "ไม่มีข้อมูล",
          style: GoogleFonts.kanit(
            fontSize: MediaQuery.of(context).size.width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  // ตรวจสอบว่ามีข้อมูลโพสต์หรือไม่
  if (posts.isEmpty) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          "ไม่มีข้อมูล",
          style: GoogleFonts.kanit(
            fontSize: MediaQuery.of(context).size.width * 0.05,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  return Consumer2<NotificationFollowProvider,NotificationHasChangeProvider>(
    builder: (context, chatProvider, hasChangeProvider,child) {
      final showChange = hasChangeProvider.hasMaintenanceNotification;

      if(showChange){
        fetchPosts();
        hasChangeProvider.setMaintenanceNotification(false);
      }
      return Scaffold(
        backgroundColor: Colors.white,
        body: ListView(
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
          children: [
            Center(
              child: Text(
                'ติดตามสถานะการแจ้งซ่อม',
                style: GoogleFonts.kanit(
                  fontSize: MediaQuery.of(context).size.width * 0.06,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).size.width * 0.04),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: posts.map<Widget>((post) => buildPost(post)).toList(),
            ),
          ],
        ),
      );
    },
  );
}
}


