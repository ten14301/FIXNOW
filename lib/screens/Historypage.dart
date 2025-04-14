import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart'; 
import '../UserProvider.dart';
import 'package:provider/provider.dart';
import '../notification_hasFetchChange.dart';
import '../component/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as path;

class HistoryPage extends StatefulWidget {
  final String userName;
  final String roleName;

  const HistoryPage({
    Key? key,
    required this.userName,
    required this.roleName,
  }) : super(key: key);

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<dynamic> posts = [];
  bool isLoading = true;
  String errorMessage = '';
  VideoPlayerController? _videoController;
  String apiURL = dotenv.env['API_URL'].toString();

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
  String apiUrl = "$apiURL/api/maintenance/history/user/${widget.userName}";

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  // รับ accessToken จาก Provider หรือแหล่งข้อมูลของคุณ

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $accessToken",  // เพิ่ม Authorization Header
        "Content-Type": "application/json",      // เพิ่ม Content-Type Header
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      print("jsonResponse: $jsonResponse");
      
      if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
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
  String formattedDateTime =
      "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

  double screenWidth = MediaQuery.of(context).size.width;
  double imageSize = screenWidth * 0.2;

  return Column(
    children: [
      GestureDetector(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: screenWidth * 0.01),
          child: Row(
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
                              : (post['other_place'] != null ? 'สถานที่: ' : ''),
                          style: GoogleFonts.kanit(
                            fontSize: screenWidth * 0.03,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: post['room_number']?.toString() ?? post['other_place']?.toString() ?? 'ไม่มีข้อมูล',
                          style: GoogleFonts.kanit(
                            fontSize: screenWidth * 0.03,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // รายละเอียดการแจ้ง
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.kanit(fontSize: screenWidth * 0.03),
                      children: [
                        TextSpan(
                          text: "รายละเอียดการแจ้ง: ",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: post['request_info']?.isNotEmpty == true ? post['request_info'] : 'ไม่มีคำอธิบาย',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // การเปลี่ยนแปลงสถานะล่าสุด
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.kanit(fontSize: screenWidth * 0.03),
                      children: [
                        TextSpan(
                          text: "การเปลี่ยนแปลงสถานะล่าสุด: ",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: formattedDateTime,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  // แสดงสถานะ พร้อมไอคอนสี
                  Row(
                    children: [


                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "สถานะ: ",
                              style: GoogleFonts.kanit(
                                fontSize: screenWidth * 0.03,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            TextSpan(
                              text: post['status'] ?? 'ไม่มีข้อมูล',
                              style: GoogleFonts.kanit(
                                fontSize: screenWidth * 0.03,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.01),
                      Icon(
                        Icons.circle,
                        size: MediaQuery.of(context).size.width * 0.02,
                        color: getStatusColor(post['status']),
                      ),
                    ],
                  ),

                  SizedBox(height: screenWidth * 0.02),

                  // แจ้งเหตุ
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.kanit(fontSize: screenWidth * 0.03),
                        children: [
                          TextSpan(
                            text: "แจ้งเหตุ: ",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: post['comment']?.isNotEmpty == true ? post['comment'] : 'ไม่มีความคิดเห็น',
                            style: TextStyle(
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),


                  SizedBox(height: screenWidth * 0.01),

                  // คนที่แก้ไขสถานะล่าสุด
                  Text(
                    'คนที่แก้ไขสถานะล่าสุด: ${post['action_user_name'] ?? 'ไม่ทราบ'}',
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
        ),
      ),
      Divider(thickness: 0.5, color: Colors.grey[300]),
    ],
  );
}


@override
Widget build(BuildContext context) {
  return Consumer<NotificationHasChangeProvider>(
    builder: (context, hasChangeProvider, child) {
      if (hasChangeProvider.hasMaintenanceNotification) {
        Future.microtask(() async {
          await fetchPosts();
          hasChangeProvider.clearMaintenanceNotification();
        });
      }

      if (isLoading) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (errorMessage.isNotEmpty || posts.isEmpty) {
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

      return Scaffold(
        backgroundColor: Colors.white,
        body: RefreshIndicator(
          onRefresh: () async {
            await fetchPosts();
          },
          child: ListView(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
            children: [
              Center(
                child: Text(
                  'ประวัติการแจ้งซ่อม',
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
        ),
      );
    },
  );
}
}



