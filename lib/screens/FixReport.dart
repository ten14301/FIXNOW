import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../notification_chat_provider.dart';
import '../notification_status_provider.dart';
import '../notification_hasFetch.dart';
import '../notification_hasFetchChange.dart';
import '../UserProvider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../component/video_player.dart';
import 'package:path/path.dart' as path;


class FixReport extends StatefulWidget {
  final String userName;
  final String roleName;
  final Function(dynamic)? onChoose;

  const FixReport({
    Key? key,
    required this.userName,
    required this.roleName,
    this.onChoose,
  }) : super(key: key);

  @override
  _FixReportState createState() => _FixReportState();
}

class _FixReportState extends State<FixReport> {
  List<dynamic> posts = [];
  bool isLoading = true;
  bool isLoading_status = false;
  Set<int> selectedPosts = {};
  Map<int, TextEditingController> commentControllers = {};
  String? selectedStatus;
  String apiURL = dotenv.env['API_URL'] ?? '';
  VideoPlayerController? _videoController;
  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

Future<void> fetchPosts() async {
  String apiUrl = "$apiURL/api/maintenance/AllRequest";

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken; 

    final response = await http.get(
      Uri.parse(apiUrl),
      headers: {
        "Authorization": "Bearer $accessToken", 
        "Content-Type": "application/json",   
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success'] == true && jsonResponse['data'] != null) {
        print("Posts: $jsonResponse");
        setState(() {
          posts = jsonResponse['data'];
          for (var i = 0; i < posts.length; i++) {
            commentControllers[i] = TextEditingController();
          }
          isLoading = false;
        });
      }
    }
  } catch (e) {
    isLoading = false;
    print("Error fetching posts: $e");
  }
}

Future<void> _updateStatus() async {
  if (selectedStatus == null || selectedPosts.isEmpty) {
    _showPopup("ข้อผิดพลาด", "กรุณาเลือกสถานะ");
    return;
  }
  setState(() {
    isLoading_status = true; 
  });
  bool isSuccess = true;
  List<int> selectedIndexes = List.from(selectedPosts);

  for (int index in selectedIndexes) {
    if(posts[index]['current_status'] == selectedStatus) {
      _showPopup("ข้อผิดพลาด", "สถานะเดิมและสถานะใหม่ต้องไม่ตรงกัน");
      return;
    }
    if ((commentControllers[index]?.text.trim().characters.length ?? 0) > 50) {
      _showPopup("ข้อผิดพลาด", "ตัวอักษรในคอมเมนต์ควรไม่เกิน 50 ตัวอักษร");
      return;
    }

    Map<String, dynamic> payload = {
      "whoChange": widget.userName,
      "userName": posts[index]['user_name'],
      "requestId": posts[index]['request_id'],
      "newStatus": selectedStatus,
      "comment": commentControllers[index]?.text.trim() ?? "",
    };

    String apiUrl = "$apiURL/api/maintenance/updateRequest";

    try {
      final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          "Authorization": "Bearer $accessToken",  
          "Content-Type": "application/json",      
        },
        body: jsonEncode(payload),
      );
      print("response update status: ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          posts[index]['current_status'] = selectedStatus;
          commentControllers[index]?.clear();
        });
      } else {
        print("Failed to update status: ${response.statusCode}");
        isSuccess = false;
      }
    } catch (e) {
      print("Error updating status: $e");
      isSuccess = false;
    }
  }

  setState(() {
    isLoading_status = false; // ซ่อน loading เมื่อเสร็จสิ้น
    selectedPosts.clear();
    selectedStatus = null;
  });

  Navigator.pop(context);

  _showPopup(
    isSuccess ? "สำเร็จ" : "ล้มเหลว",
    isSuccess ? "การเปลี่ยนสถานะสำเร็จ" : "เกิดข้อผิดพลาดในการเปลี่ยนสถานะ",
  );

  fetchPosts();
}

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

void _showStatusDialog() {
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;
  if (selectedPosts.isEmpty) return;

  bool isLoading = false;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true, 
    builder: (context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom, 
            ),
            child: Container(
              height: screenHeight * 0.8,  // ปรับขนาดสูงสุดให้เท่ากับ 80% ของความสูงหน้าจอ
              width: screenWidth, // ให้ขนาดความกว้างเต็มหน้าจอ
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "เปลี่ยนสถานะ",
                          style: GoogleFonts.kanit(
                            fontSize: screenWidth * 0.04, // ใช้ screenWidth เพื่อกำหนดขนาดตัวอักษร
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Row(
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
                  const Divider(height: 1, color: Colors.grey),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: StatefulBuilder(
                        builder: (context, setModalState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatusButton(context,"รอการสำรวจ", setModalState),
                              _buildStatusButton(context,"อยู่ระหว่างการแก้ไข", setModalState),
                              _buildStatusButton(context,"ดำเนินการเสร็จสิ้น", setModalState),
                              SizedBox(height: screenHeight * 0.04),
                              ...selectedPosts.map((index) {
                                final post = posts[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                        Text(
                                        "${post['room_number'] != null ? 'ห้อง: ${post['room_number']?.toString()}' : (post['other_place'] != null ? 'สถานที่: ${post['other_place']?.toString()}' : 'ไม่มีข้อมูล')}",
                                        style: GoogleFonts.kanit(
                                          fontSize: screenWidth * 0.03,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(width: screenWidth * 0.02),
                                      Text(
                                        "ผู้แจ้ง: ${post['user_name'] ?? 'ไม่ระบุ'}",
                                        style: GoogleFonts.kanit(
                                          fontSize: screenWidth * 0.03,
                                          color: Colors.grey,
                                        ),
                                      ),
                                        ],
                                      ),
                                      Text(
                                        "สถานะปัจจุบัน: ${post['current_status'] ?? 'ไม่ระบุ'}",
                                        style: GoogleFonts.kanit(
                                          fontSize: screenWidth * 0.03,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      TextField(
                                        controller: commentControllers[index],
                                        maxLines: 2,
                                        decoration: InputDecoration(
                                          hintText: "เพิ่มคอมเมนต์สำหรับห้องนี้...",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              SizedBox(height: screenHeight * 0.04),

                              // Confirm Button
                              Center(
                                child: isLoading
                                    ? const CircularProgressIndicator() // แสดง loading เมื่อกำลังทำงาน
                                    : ElevatedButton(
                                        onPressed: () async {
                                          setModalState(() {
                                            isLoading = true;
                                          });
                                          await _updateStatus();
                                          setModalState(() {
                                            isLoading = false; 
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: Size(
                                            screenWidth * 0.4,
                                            screenHeight * 0.07,
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                        child: Text(
                                          "ยืนยัน",
                                          style: GoogleFonts.kanit(
                                            fontSize: screenWidth * 0.03, // ใช้ screenWidth ในการกำหนดขนาดข้อความ
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                              SizedBox(height: screenHeight * 0.04),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}


Widget _buildStatusButton(BuildContext context,String status, StateSetter setModalState) {
  bool isSelected = selectedStatus == status;
  double screenWidth = MediaQuery.of(context).size.width;
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        backgroundColor: isSelected ? Colors.green : Colors.white,
        side: BorderSide(
          color: isSelected ? Colors.green : Colors.black,
        ),
      ),
      onPressed: () {
        setModalState(() {
          selectedStatus = isSelected ? null : status;
        });
        
      },
      child: Text(
        status,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontSize: screenWidth * 0.04,
        ),
      ),
    ),
  );
}
void _showPopup(String title, String message) {
  double screenWidth = MediaQuery.of(context).size.width;
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.kanit(fontSize: screenWidth * 0.05, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.kanit(fontSize: screenWidth * 0.04),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); 
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


@override
Widget build(BuildContext context) {
  return Consumer4<NotificationChatProvider, NotificationStatusProvider, NotificationHasProvider, NotificationHasChangeProvider>(
    builder: (context, chatProvider, statusProvider, fetchProvider, hasChangeProvider, child) {
      double screenWidth = MediaQuery.of(context).size.width;
      double screenHeight = MediaQuery.of(context).size.height;

      return Scaffold(
        backgroundColor: Colors.white,
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        "รายการแจ้งซ่อม",
                        style: GoogleFonts.kanit(
                          fontSize: screenWidth * 0.05,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.02),
                    Expanded(
                      child: ListView.builder(
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          bool isSelected = selectedPosts.contains(index);
                          bool isUnread = posts[index]['is_change'] == false;
                          List<dynamic> imageData = posts[index]['file_urls'] ?? [];
                          String requestId = posts[index]['request_id'].toString();

                          String userName = posts[index]['user_name'] ?? 'ไม่ระบุ';
                          
                          // แปลงเวลาตามโซน Bangkok (UTC+7)
                          DateTime parsedDateTime = _parseDateTime(posts[index]['date'], posts[index]['time']);
                          String requestTime = DateFormat('dd/MM/yyyy HH:mm').format(parsedDateTime);

                          bool showYellowDot = chatProvider.chatMessages[requestId] ?? false;
                          bool showStatusChange = statusProvider.statusMessages[requestId] ?? false;
                          final showFetch = fetchProvider.hasMaintenanceNotification;
                          final showChange = hasChangeProvider.hasMaintenanceNotification;

                          if (showFetch) {
                            fetchPosts();
                            fetchProvider.clearMaintenanceNotification();
                          }

                          if (showChange) {
                            fetchPosts();
                            hasChangeProvider.clearMaintenanceNotification();
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  selectedPosts.remove(index);
                                } else {
                                  selectedPosts.add(index);
                                  posts[index]['is_change'] = true;
                                  statusProvider.removeStatusMessage(requestId);
                                }
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  color: Colors.transparent,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      buildImageGallery(imageData),
                                      SizedBox(width: screenWidth * 0.02),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "ผู้แจ้ง: $userName",
                                              style: GoogleFonts.kanit(
                                                fontSize: screenWidth * 0.03,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: posts[index]['room_number'] != null 
                                                  ? 'ห้อง: ' 
                                                  : (posts[index]['other_place'] != null ? 'สถานที่: ' : ''), 
                                              style: GoogleFonts.kanit(
                                                fontSize: screenWidth * 0.03,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            TextSpan(
                                              text: posts[index]['room_number']?.toString() ?? posts[index]['other_place']?.toString() ?? 'ไม่มีข้อมูล', 
                                              style: GoogleFonts.kanit(
                                                fontSize: screenWidth * 0.03,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),


                                            RichText(
                                              text: TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'รายละเอียดการแจ้ง: ', 
                                                    style: GoogleFonts.kanit(
                                                      fontSize: screenWidth * 0.03,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: posts[index]['request_info'] ?? 'ไม่มีคำอธิบาย', 
                                                    style: GoogleFonts.kanit(
                                                      fontSize: screenWidth * 0.03,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),


                                             Text(
                                              "การเปลี่ยนแปลงสถานะล่าสุด:",
                                              style: GoogleFonts.kanit(
                                                fontSize: screenWidth * 0.03,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                            ),
                                            Text(
                                              requestTime,
                                              style: GoogleFonts.kanit(
                                                fontSize: screenWidth * 0.03,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: 'สถานะ: ', // คำว่า "สถานะ:" เป็นสีดำ
                                                  style: GoogleFonts.kanit(
                                                    fontSize: screenWidth * 0.03,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: posts[index]['current_status'] ?? 'ไม่ระบุ', // ค่าของสถานะเป็นสีน้ำเงินเทา
                                                  style: GoogleFonts.kanit(
                                                    fontSize: screenWidth * 0.03,
                                                    color: Colors.blueGrey,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                          "คนที่แก้ไขสถานะล่าสุด: : ${posts[index]['last_action_user_name'] ?? 'ไม่ระบุ'}",
                                            style: GoogleFonts.kanit(
                                              fontSize: screenWidth * 0.03,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blueGrey,
                                            
                                                    ),
                                                  ),

                                          ],
                                        ),
                                      ),
                                      if (showStatusChange || isUnread) 
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: Icon(
                                            Icons.circle,
                                            color: Colors.red,
                                            size: 12,
                                          ),
                                        ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (posts[index]['current_status'] != 'รอรับเรื่อง' && posts[index]['current_status'] != 'ดำเนินการเสร็จสิ้น')
                                            Stack(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                                                  onPressed: () {
                                                    if (widget.onChoose != null) {
                                                      widget.onChoose!(posts[index]);
                                                    }
                                                    chatProvider.removeChatMessage(requestId);
                                                  },
                                                ),
                                                if (showYellowDot)
                                                  Positioned(
                                                    top: 4,
                                                    right: 4,
                                                    child: Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: const BoxDecoration(
                                                        color: Colors.yellow,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          Icon(
                                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                                            color: isSelected ? Colors.green : Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: screenHeight * 0.02),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
        floatingActionButton: selectedPosts.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _showStatusDialog,
                label: Text(
                  "เปลี่ยนสถานะ",
                  style: GoogleFonts.kanit(
                    fontSize: screenWidth * 0.04,
                  ),
                ),
                icon: const Icon(Icons.edit),
              )
            : null,
      );
    },
  );
}

// ฟังก์ชันแปลงเวลาให้เป็นโซน Bangkok (UTC+7)
DateTime _parseDateTime(String? date, String? time) {
  try {
    DateTime utcDate = DateTime.parse(date ?? '').toUtc();
    DateTime finalDateTime = utcDate;
    
    if (time != null && time.isNotEmpty) {
      List<String> timeParts = time.split(':');
      finalDateTime = DateTime(
        utcDate.year,
        utcDate.month,
        utcDate.day,
        int.parse(timeParts[0]), // ชั่วโมง
        int.parse(timeParts[1]), // นาที
        int.parse(timeParts[2].split('.')[0]), // วินาที
      );
    }
    
    finalDateTime = finalDateTime.add(const Duration(hours: 7)); // UTC+7 (Bangkok)
    return finalDateTime;
  } catch (e) {
    return DateTime(1900); // กรณี error ให้ใช้วันที่ default
  }
}
}



