import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../UserProvider.dart';
import '../room_provider.dart';
import '../chatCheck_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../component/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

class ChatPage extends StatefulWidget {
  final dynamic post;
  final String userName;
  final String roleName;

  const ChatPage({
    required this.post,
    required this.userName,
    required this.roleName,
    Key? key,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  List<Map<String, dynamic>> messages = [];
  late IO.Socket socket;
  List<XFile?> _pickedFiles = [];
  List<Map<String, dynamic>> groupedMessages = [];
  bool isLoading = false;
  bool isSendingMessage = false;
  double uploadProgress = 0.0;
  bool isUploading = false;
  ScrollController _scrollController = ScrollController();
  int page = 1;
  String apiURL = dotenv.env['API_URL'] ?? '';
  VideoPlayerController? _videoController;

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
    _connectToSocket();
    socket.connect();
    _loadOldMessages(page);
    
  }
  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onControllerCreated(VideoPlayerController controller) {
    setState(() {
      _videoController = controller;
    });
  }
Future<String?> uploadFileToServer(File file) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    var uri = Uri.parse('$apiURL/api/FileStorage');
    var request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $accessToken'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    var response = await request.send();
    print("response.statusCode: ${response.statusCode}");
    if (response.statusCode == 200) {

      var responseBody = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseBody);
      print("fileurl: ${jsonResponse['fileUrl']}");
      return jsonResponse['fileUrl'];
    } else {
      print('Failed to upload file: ${response.reasonPhrase}');
      return null;
    }
  } catch (e) {
    print('Error uploading file: $e');
    return null;
  }
}

Future<String?> getPresignedUrl(String fileName, String fileType, BuildContext context) async {
  try {

    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Access token: $accessToken');

    final response = await http.post(
      Uri.parse('$apiURL/api/amazon/getPresignedUrl'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'fileName': fileName,
        'fileType': fileType,
      }),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      if (jsonResponse['success']) {
        return jsonResponse['url']; // URL สำหรับอัปโหลดไฟล์
      } else {
        print('Failed to get presigned URL');
        return null;
      }
    } else {
      print('Failed to get presigned URL: ${response.body}');
      return null;
    }
  } catch (e) {
    print('Error getting presigned URL: $e');
    return null;
  }
}

Future<String?> uploadFileToS3(String filePath, String presignedUrl, String fileName, String mimeType) async {
  try {
    String amazonUrl = dotenv.env['AmazonS3_BUCKET_LOCATION'] ?? '';
    final fileBytes = await File(filePath).readAsBytes();
    final request = http.Request('PUT', Uri.parse(presignedUrl))
      ..headers['Content-Type'] =  mimeType
      ..bodyBytes = fileBytes;

    final response = await request.send();
    if (response.statusCode == 200) {
      print('File uploaded successfully!');
      final fileUrl = '$amazonUrl/$fileName';
      return fileUrl; 

    } else {
      print('Failed to upload file: ${response.statusCode}');
    }
  } catch (e) {
    print('Error uploading file: $e');
  }
}
String generateRandomFileName(String originalName) {
  var uuid = Uuid();
  String randomString = uuid.v4();
  String extension = originalName.split('.').last;  
  return '$randomString.$extension';
}


void _connectToSocket() {
  if (!mounted) return;
  socket = IO.io(
    apiURL,  
    IO.OptionBuilder()
        .setTransports(['websocket'])  
        .enableAutoConnect()  
        .enableReconnection()
        .setReconnectionAttempts(10)  
        .setReconnectionDelay(1000)  
        .setReconnectionDelayMax(5000) 
        .build(),
  );

  socket.onConnect((_) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
      socket.emit('leave_room', roomProvider.roomId); 
      print('Connected to socket');
      socket.emit('join_room', widget.post['request_id']);
      context.read<RoomProvider>().setRoom(widget.post['request_id'].toString());
    });
  });

  socket.on('send_message', (data) {
    if (!mounted) return;
    print("Received message data: $data");

    if (data['userName'] != widget.userName) {
      setState(() {
        messages.add({
          "message": data['message'],
          "user": data['userName'],
          "time": data['time'],
          "isSender": data['userName'] == widget.userName,
          "files": data['files'],
        });
      });
    }
  });

  socket.onDisconnect((_) {
    if (!mounted) return;
    print('Socket disconnected, trying to reconnect...');
    Future.delayed(Duration(seconds: 2), () {
      if (mounted) socket.connect();
    });
  });

  socket.onReconnect((_) {
    if (!mounted) return;
    print('Reconnected to socket');
    socket.emit('join_room', widget.post['request_id']);
  });

  socket.onReconnectError((error) => print('Reconnect error: $error'));
  socket.onReconnectFailed((_) => print('Reconnect failed'));
}


void _loadOldMessages(int page) async {
  setState(() {
    isLoading = true;
  });

  final int requestId = widget.post['request_id'];
  final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
  print('Access token: $accessToken');

  try {
    final response = await http.get(
      Uri.parse('$apiURL/api/chat/messages/$requestId?page=$page'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json', 
      },
    );

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      print("jsonData: $jsonData");
      if (jsonData['success']) {
        List<Map<String, dynamic>> oldMessages = (jsonData['data'] as List)
            .map((msg) {
              print("file: ${msg['files']}");
              return {
                "message": msg['message'],
                "user": msg['senderName'],
                "time": "${msg['date']} ${msg['time']}",
                "isSender": msg['senderName'] == widget.userName,
                "files": msg['files'],
              };
            })
            .toList();

        setState(() {
          messages.addAll(oldMessages);
          isLoading = false;
        });
      } else {
        if (mounted){
        setState(() {
          isLoading = false;
        });
        }

        print("No more messages to load.");
      }
    } else {
      if(mounted){
      setState(() {
        isLoading = false;
      });
      }

      print("Failed to load old messages: ${response.body}");
    }
  } catch (e) {
    if(mounted){
          setState(() {
      isLoading = false;
    });
    }

    print("Error loading messages: $e");
  }
}


String formatDateToBangkokTime(String timeString) {
  try {
    // แยกค่าจาก input string
    List<String> parts = timeString.split(' ');
    String utcPart = parts[0];  // ดึงส่วน UTC เช่น 2025-01-14T17:00:00.000Z
    String localTimePart = parts[1]; // ดึงเวลาเช่น 12:21:00

    // นำ UTC date-time มา parse
    DateTime utcTime = DateTime.parse(utcPart).toUtc();

    // แปลงเวลาเป็นโซน Bangkok (UTC+7)
    DateTime bangkokTime = utcTime.add(Duration(hours: 7));

    // ใช้เวลาเฉพาะ HH:mm:ss จาก local time (เช่น 12:21:00) ถ้าจำเป็น
    List<String> localTimeParts = localTimePart.split(':');
    bangkokTime = bangkokTime.copyWith(
      hour: int.parse(localTimeParts[0]),
      minute: int.parse(localTimeParts[1]),
      second: int.parse(localTimeParts[2]),
    );

    // ฟอร์แมตแสดงผล
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(bangkokTime);
  } catch (e) {
    print("Error parsing date: $e");
    return timeString;
  }
}

void _pickMedia({required bool isImage}) async {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? pickedFiles = [];

  if (isImage) {
    pickedFiles = await _picker.pickMultiImage(); // สำหรับเลือกหลายภาพ
  } else {
    // ใช้ file_picker เลือกหลายไฟล์วิดีโอ
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true, // อนุญาตให้เลือกหลายไฟล์
    );

    if (result != null) {
      pickedFiles = result.files.map((file) => XFile(file.path!)).toList(); // แปลงเป็น XFile
    }
  }

  // ตรวจสอบจำนวนไฟล์และขนาดไฟล์
  if (pickedFiles != null && pickedFiles.isNotEmpty) {
    // ตรวจสอบจำนวนไฟล์
    if (pickedFiles.length > 5) {
      _showAlertDialog('เกินจำนวนไฟล์ที่อนุญาต', 'กรุณาเลือกไฟล์ไม่เกิน 5 ไฟล์');
    } else {
      // ตรวจสอบขนาดไฟล์
      bool isValid = true;
      for (var file in pickedFiles) {
        var fileSize = await file.length();
        if (fileSize > 100 * 1024 * 1024) { 
          isValid = false;
          break;
        }
      }

      if (!isValid) {
        _showAlertDialog('ไฟล์ใหญ่เกินไป', 'กรุณาเลือกไฟล์ที่มีขนาดไม่เกิน 100 MB');
      } else {
        setState(() {
          _pickedFiles.addAll(pickedFiles!);
        });
      }
    }
  }
}

// ฟังก์ชันแสดง AlertDialog
void _showAlertDialog(String title, String message) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
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
Future<void> _sendMessage() async {
  final messageText = _messageController.text.trim();
  final hasMedia = _pickedFiles.isNotEmpty;
  String env = dotenv.env['ENV'] ?? 'local'; 

  if (widget.userName == null || widget.userName.isEmpty) {
    print("Error: userName is empty or null");
    return;
  }
  if (messageText.characters.length > 150) {
    _showErrorDialog("ข้อความต้องไม่เกิน 150 ตัวอักษร");
    return;
  }
  // ถ้าไม่มีข้อความและไม่มีไฟล์ ก็ไม่ส่งอะไร
  if (messageText.isEmpty && !hasMedia) return;

  setState(() {
    isSendingMessage = true;
    uploadProgress = 0.0;
  });

  final messageData = {
    "message": messageText,
    "userName": widget.userName,
    "requestId": widget.post['request_id'],
    "time": DateTime.now().toLocal().toString().substring(0, 16),
    "files": [],
  };

  // ถ้ามีไฟล์
  if (hasMedia) {
    List<Map<String, dynamic>> newFiles = [];

    for (var file in List.from(_pickedFiles)) {
      if (file != null) {
        String randomFileName = generateRandomFileName(file.name);
        String fileExtension = file.path.split('.').last.toLowerCase();
        String mimeType;
        File convertedFile = File(file.path);
        if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (fileExtension == 'png') {
          mimeType = 'image/png';
        } else if (fileExtension == 'mp4') {
          mimeType = 'video/mp4';
        } else {
          mimeType = 'application/octet-stream';
        }

        if (env == 'local') {
          final fileUrl = await uploadFileToServer(convertedFile);
          if (fileUrl != null) {
            newFiles.add({
              'fileName': randomFileName,
              'fileType': mimeType,
              'fileUrl': fileUrl,
            });
          }
        } else if (env == 'cloud') {
          // ถ้าเป็น cloud, ใช้ Presigned URL และอัปโหลดไปยัง S3
          final presignedUrl = await getPresignedUrl(randomFileName, mimeType, context);
          if (presignedUrl != null) {
            final fileUrl = await uploadFileToS3(file.path, presignedUrl, randomFileName, mimeType);
            if (fileUrl != null) {
              newFiles.add({
                'fileName': randomFileName,
                'fileType': mimeType,
                'fileUrl': fileUrl,
              });
            }
          }
        }
      }
    }

    messageData['files']!.addAll(newFiles);
  }

  try {
    // ส่งข้อมูลผ่าน socket.io
    if (messageText.isNotEmpty || hasMedia) {
      final socketPayload = {
        "message": messageText,
        "userName": widget.userName,
        "requestId": widget.post['request_id'],
        "time": messageData['time'],
        "files": messageData['files'],
      };
      print("Sending message: $socketPayload");

      // ดึง accessToken จาก UserProvider
      final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
      print('Access token: $accessToken');

      // ส่งข้อมูลไปที่ API ด้วย POST
      final apiUrl = '$apiURL/api/chat/messages';
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',  // ใส่ Access Token ใน Header
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "userName": widget.userName,
          "requestId": widget.post['request_id'],
          "message": messageText,
          "date": DateTime.now().toLocal().toString().split(" ")[0],
          "time": messageData['time'],
          "is_read": false,
          "files": messageData['files'],
        }),
      );

      if (response.statusCode == 201) {
        print('Message sent to API successfully!');
        socket.emit('message_get', socketPayload);
      } else {
        print('Failed to send message to API. Status code: ${response.statusCode}');
      }

      // เพิ่มข้อความในแชท
      setState(() {
        messages.add({
          "message": messageText,
          "user": widget.userName,
          "time": messageData['time'],
          "isSender": true,
          "files": hasMedia ? messageData['files'] : null,
        });
        isSendingMessage = false;
      });

      _messageController.clear();
      _pickedFiles.clear();
    }
  } catch (e) {
    print("Error: $e");
    if (mounted) {
      setState(() {
        isSendingMessage = false;
      });
    }
  }
}


Widget _buildPreview() {
  if (_pickedFiles.isEmpty) return SizedBox();

  return Padding(
    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
    child: Row(
      children: [
        if (_pickedFiles.isNotEmpty &&
            (_pickedFiles[0]!.path.endsWith('.jpg') || _pickedFiles[0]!.path.endsWith('.png')))
          Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.25,
                height: MediaQuery.of(context).size.width * 0.25,
                child: Image.file(
                  File(_pickedFiles[0]!.path),
                  fit: BoxFit.cover,
                ),
              ),
              if (isSendingMessage)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  // แสดง confirmation dialog ก่อนลบ
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: Text("ยืนยันการลบ"),
                        content: Text("คุณต้องการลบไฟล์นี้หรือไม่?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(); // ปิด Dialog
                            },
                            child: Text("ยกเลิก"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _pickedFiles.removeAt(0); // ลบไฟล์
                              });
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

              ),
            ],
          )
        else if (_pickedFiles.isNotEmpty && _pickedFiles[0]!.path.endsWith('.mp4'))
          Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.25,
                height: MediaQuery.of(context).size.width * 0.25,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VideoPlayerWidget(
                    filePath: _pickedFiles[0]!.path,
                    onPlayPause: _togglePlayPause,
                    onControllerCreated: _onControllerCreated,
                    hideSlider: true,
                  ),
                ),
              ),
              if (isSendingMessage)
                Positioned.fill(
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              Positioned(
                top: 0,
                right: 0,
              child: IconButton(
                icon: Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  // แสดง confirmation dialog ก่อนลบ
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: Text("ยืนยันการลบ"),
                        content: Text("คุณต้องการลบไฟล์นี้หรือไม่?"),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(dialogContext).pop(); // ปิด Dialog
                            },
                            child: Text("ยกเลิก"),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _pickedFiles.removeAt(0); // ลบไฟล์
                              });
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

              ),
            ],
          ),
        if (_pickedFiles.length > 1)
          Stack(
            children: [
              Opacity(
                opacity: 0.5,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.25,
                  height: MediaQuery.of(context).size.width * 0.25,
                  child: _pickedFiles[1]!.path.endsWith('.jpg') || _pickedFiles[1]!.path.endsWith('.png')
                      ? Image.file(
                          File(_pickedFiles[1]!.path),
                          fit: BoxFit.cover,
                        )
                      : AspectRatio(
                          aspectRatio: 16 / 9,
                          child: VideoPlayerWidget(
                            filePath: _pickedFiles[1]!.path,
                            onPlayPause: _togglePlayPause,
                            onControllerCreated: _onControllerCreated,
                            hideSlider: true,
                          ),
                        ),
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: _showPreviewDialog,
                  child: Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: Icon(
                      Icons.add,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  );
}

void _showPreviewDialog() {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text('ดูเพิ่มเติม'),
          content: SingleChildScrollView(
            child: Column(
              children: _pickedFiles.map((file) {
                return file!.path.endsWith('.mp4')
                    ? Stack(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: MediaQuery.of(context).size.height * 0.5,
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: VideoPlayerWidget(
                                filePath: file.path,
                                onPlayPause: _togglePlayPause,
                                onControllerCreated: _onControllerCreated,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                        child: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            // แสดง confirmation dialog ก่อนลบ
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  title: Text("ยืนยันการลบ"),
                                  content: Text("คุณต้องการลบไฟล์นี้หรือไม่?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.of(dialogContext).pop(); // ปิด Dialog
                                      },
                                      child: Text("ยกเลิก"),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        // ใช้ setStateDialog เพื่อลบไฟล์
                                        setStateDialog(() {
                                          _pickedFiles.remove(file);
                                        });
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

                          ),
                        ],
                      )
                    : Stack(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width * 0.3,
                            height: MediaQuery.of(context).size.height * 0.2,
                            child: Image.file(File(file.path)),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setStateDialog(() {
                                  _pickedFiles.remove(file);
                                });
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {});
              },
              child: Text('ปิด'),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildChatBubble(String message, String user, String time, {bool isSender = false, dynamic fileUrl}) {
  print("fileUrl: $fileUrl");
  return Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.of(context).size.width * 0.05,
      vertical: MediaQuery.of(context).size.height * 0.01,
    ),
    child: Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            user.length > 10 ? '${user.substring(0, 10)}...' : user,
            style: GoogleFonts.kanit(
              fontSize: MediaQuery.of(context).size.width * 0.03,
              color: Colors.grey.shade600,
            ),
          ),
          Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
            decoration: BoxDecoration(
              color: isSender ? Colors.blue : Colors.black87,
              borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: GoogleFonts.kanit(
                      color: Colors.white,
                      fontSize: MediaQuery.of(context).size.width * 0.04,
                    ),
                  ),
                // ตรวจสอบว่า fileUrl เป็นลิสต์และแสดงไฟล์ทั้งหมด
                if (fileUrl is List && fileUrl.isNotEmpty)
                  Column(
                    children: List.generate(fileUrl.length, (index) {
                      String fileUrlString = fileUrl[index]['fileUrl'] ?? '';
                      if (fileUrlString.isEmpty) return Container();

                      // ใช้ path.extension() เพื่อดึงนามสกุลจริงของไฟล์
                      final ext = path.extension(Uri.parse(fileUrlString).path).toLowerCase();

                      return Stack(
                        children: [
                          // ถ้านามสกุลเป็น .mp4 ให้แสดงวิดีโอ
                          ext == '.mp4'
                              ? FutureBuilder(
                                  future: _getVideoAspectRatio(fileUrlString),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Container(
                                        child: Center(child: CircularProgressIndicator()),
                                      );
                                    }
                                    double aspectRatio = snapshot.data as double;
                                    double baseHeight = MediaQuery.of(context).size.width * 0.83 / aspectRatio;
                                    return Container(
                                      width: MediaQuery.of(context).size.width * 0.7,
                                      height: baseHeight,
                                      child: VideoPlayerWidget(
                                        filePath: fileUrlString,
                                        onPlayPause: _togglePlayPause,
                                        onControllerCreated: _onControllerCreated,
                                      ),
                                    );
                                  },
                                )
                              // ถ้านามสกุลเป็น .jpg, .jpeg หรือ .png ให้แสดงรูปภาพ
                              : (ext == '.jpg' || ext == '.jpeg' || ext == '.png')
                                  ? Container(
                                      width: 150,
                                      height: 150,
                                      child: Image.network(
                                        fileUrlString,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          } else {
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress.expectedTotalBytes != null
                                                    ? loadingProgress.cumulativeBytesLoaded /
                                                        (loadingProgress.expectedTotalBytes ?? 1)
                                                    : null,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    )
                                  : Container(), // กรณีที่นามสกุลไม่ตรงกับที่รองรับ
                          // ปุ่มขยาย (zoom) ให้ทำงานเฉพาะกับไฟล์ที่ไม่ใช่วิดีโอ
                          if (ext != '.mp4')
                            Positioned(
                              bottom: 5,
                              right: 5,
                              child: IconButton(
                                icon: Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  // เปิด Dialog เพื่อขยายรูปภาพหรือวิดีโอ
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      content: ext == '.mp4'
                                          ? Container(
                                              width: double.infinity,
                                              height: 300,
                                              child: VideoPlayerWidget(
                                                filePath: fileUrlString,
                                                onPlayPause: _togglePlayPause,
                                                onControllerCreated: _onControllerCreated,
                                              ),
                                            )
                                          : Image.network(
                                              fileUrlString,
                                              fit: BoxFit.contain,
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
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
              ],
            ),
          ),
          Text(
            formatDateToBangkokTime(time),
            style: GoogleFonts.kanit(
              fontSize: MediaQuery.of(context).size.width * 0.03,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<double> _getVideoAspectRatio(String videoUrl) async {
  final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
  await controller.initialize();
  double aspectRatio = controller.value.aspectRatio;
  controller.dispose(); // ปิด Controller หลังดึงข้อมูลเสร็จ
  return aspectRatio;
}
@override
void dispose() {
  if (mounted) {
    _scrollController.dispose();
    socket.disconnect();
  }
  super.dispose();
}

 @override
  Widget build(BuildContext context) {
    final chatCheck = Provider.of<ChatCheckProvider>(context, listen: false);
    chatCheck.setisChat(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
          child: Text(
            "แชทกับช่าง",
            style: GoogleFonts.kanit(
              fontSize: max(MediaQuery.of(context).size.height, MediaQuery.of(context).size.width) * 0.02,
              fontWeight: FontWeight.bold,
            ),
          ),
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(child: Text("No messages yet"))
                    : ListView.builder(
                        
                        controller: _scrollController,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          print("message: $message");
                          return _buildChatBubble(
                            message['message'] ?? 'No message available',
                            message['user'] ?? 'Unknown user',
                            message['time'],
                            isSender: message['isSender'] ?? false,
                            fileUrl: message['files'],
                          );
                        },
                      ),
          ),
          _buildPreview(),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.04,
              vertical: MediaQuery.of(context).size.height * 0.01,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey,
                  blurRadius: 8,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: isSendingMessage ? null : () {
                    _pickMedia(isImage: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.video_call),
                  onPressed: isSendingMessage ? null : () {
                    _pickMedia(isImage: false);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !isSendingMessage,
                    decoration: InputDecoration(
                      hintText: isSendingMessage ? "กำลังส่ง..." : "ส่งข้อความ...",
                      hintStyle: TextStyle(
                        color: isSendingMessage ? Colors.grey : Colors.black,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      suffixIcon: isSendingMessage
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            )
                          : null,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: isSendingMessage ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}






