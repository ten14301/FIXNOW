import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../UserProvider.dart';
import '../component/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PostmaintenanceRequest extends StatefulWidget {
  List<dynamic> roomData;
  List<dynamic> otherData;

  String userName;
  String roleName;

  PostmaintenanceRequest({
    Key? key,
    required this.roomData,
    required this.otherData,
    required this.userName,
    required this.roleName,
  }) : super(key: key);

  @override
  State<PostmaintenanceRequest> createState() => _PostmaintenanceRequestState();
}

Dio dio = Dio();



class _PostmaintenanceRequestState extends State<PostmaintenanceRequest> {
  late List<TextEditingController> _textControllers;
  late List<FocusNode> _focusNodes;
  List<ValueNotifier<List<XFile>>> _otherSelectedFiles = [];
  List<dynamic> combinedData = []; 

  String apiURL = dotenv.env['API_URL'] ?? '';
  String errorMessage = '';
  bool isLoading = false;
  VideoPlayerController? _videoController;
  bool isPlaying = false; 
  ValueNotifier<List<XFile>> _pickedFiles = ValueNotifier<List<XFile>>([]);
  late List<ValueNotifier<List<XFile>>> _roomSelectedFiles;
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
    combinedData = [...widget.roomData, ...widget.otherData];
_textControllers = List.generate(combinedData.length, (index) => TextEditingController());
_focusNodes = List.generate(combinedData.length, (index) => FocusNode());
_roomSelectedFiles = List.generate(combinedData.length, (_) => ValueNotifier<List<XFile>>([]));
  
  }
  void _onControllerCreated(VideoPlayerController controller) {
    setState(() {
      _videoController = controller; // Save the controller
    });
  }

Future<void> createPost(int index) async {
  try {
    final String access_token = Provider.of<UserProvider>(context, listen: false).accessToken;

    String requestInfo = _textControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .join(", ");

    if (requestInfo.isEmpty) {
      _showErrorDialog("กรุณากรอกข้อมูลการแจ้งซ่อม");
      return;
    }
    if (requestInfo.characters.length > 150) {
      _showErrorDialog("ข้อความต้องไม่เกิน 150 ตัวอักษร");
      return;
    }

    List<Map<String, String>> filesData = [];
    List<Future<String?>> uploadTasks = [];

    String env = dotenv.env['ENV'] ?? 'local'; 
    for (var file in _roomSelectedFiles[index].value) {
      File convertedFile = File(file.path);
      String fileName = generateRandomFileName(file.name);
      String fileType = file.mimeType ?? 'application/octet-stream';

      if (env == 'local') {

          uploadTasks.add(uploadFileToServer(convertedFile));

      } else if (env == 'cloud') {
        // อัปโหลดไฟล์ไปที่ S3
        String? presignedUrl = await getPresignedUrl(fileName, fileType);
        if (presignedUrl != null) {
          uploadTasks.add(uploadFileToS3(file.path, presignedUrl, fileName, fileType));
        } else {
          print('ไม่สามารถรับ Presigned URL ได้');
        }
      }
    }

    List<String?> uploadedFileUrls = await Future.wait(uploadTasks);

    for (int i = 0; i < uploadedFileUrls.length; i++) {
      if (uploadedFileUrls[i] != null) {
        filesData.add({
          'fileName': generateRandomFileName(_roomSelectedFiles[index].value[i].name),
          'fileUrl': uploadedFileUrls[i]!,
          'file_type': _roomSelectedFiles[index].value[i].mimeType ?? 'application/octet-stream',
        });
      }
    }

    var combinedData = [...widget.roomData, ...widget.otherData];
    String? roomID = combinedData[index] is String ? combinedData[index] : null;
    int? roomIDParsed = int.tryParse(roomID ?? "");
    String? otherPlace = combinedData.length > widget.roomData.length
        ? combinedData[index] as String
        : null;

    if (roomIDParsed == null && otherPlace == null) {
      _showErrorDialog("กรุณากรอกข้อมูลห้องหรือสถานที่");
      return;
    }

    String placeholder = (roomIDParsed == null && otherPlace == null) ? "placeholder_value" : "";

    if (widget.userName.isEmpty || widget.roleName.isEmpty || requestInfo.isEmpty) {
      _showErrorDialog("กรุณากรอกข้อมูลที่จำเป็นทั้งหมด");
      return;
    }

    String currentDate = DateTime.now().toIso8601String().split("T")[0];
    String currentTime = DateTime.now().toIso8601String().split("T")[1].split(".")[0];

    Map<String, dynamic> jsonData = {
      "userName": widget.userName,
      "roomID": roomIDParsed != null ? roomIDParsed : null,
      "date": currentDate,
      "time": currentTime,
      "requestInfo": requestInfo,
      "otherPlace": otherPlace,
      "roleName": widget.roleName,
      "files": filesData.isNotEmpty ? filesData : [],
      "placeholder": placeholder,
    };

    Response response = await dio.post(
      "$apiURL/api/maintenance",
      data: jsonEncode(jsonData),
      options: Options(
        headers: {
          'Authorization': 'Bearer $access_token',
          'Content-Type': 'application/json',
        },
        contentType: "application/json",
        validateStatus: (status) => status! < 500,
      ),
    );

    setState(() {
      isLoading = false;
    });

    if (response.statusCode == 201) {
      if (response.data['success'] == true) {
        deleteRoomsByIndex(index);
        _showSuccessDialog("การโพสต์สำเร็จ!");
      } else {
        _showErrorDialog("ไม่สามารถโพสต์ข้อมูลได้: ${response.data['message']}");
      }
    } else {
      _showErrorDialog("การตอบกลับจากเซิร์ฟเวอร์ผิดพลาด: ${response}");
      print(response);
    }
  } catch (e) {
    setState(() {
      isLoading = false;
    });
    _showErrorDialog("เกิดข้อผิดพลาด: $e");
  }
}

void _showSuccessDialog(String message) {
  if (!mounted) return; 
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("สำเร็จ", style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
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
void deleteRoomsByIndex(int index) {
  // คัดลอกข้อมูลจาก combinedData
  List<dynamic> combinedDataCopy = List.from(combinedData);
  List<TextEditingController> textControllersCopy = List.from(_textControllers);
  List<FocusNode> focusNodesCopy = List.from(_focusNodes);
  List<ValueNotifier<List<XFile>>> roomSelectedFilesCopy = List.from(_roomSelectedFiles);

  // ลบข้อมูลจาก combinedData
  combinedDataCopy.removeAt(index);
  textControllersCopy.removeAt(index);
  focusNodesCopy.removeAt(index);
  roomSelectedFilesCopy.removeAt(index);

  // อัปเดตข้อมูลใหม่ใน setState
  setState(() {
    combinedData = combinedDataCopy; // อัปเดต combinedData
    _textControllers = textControllersCopy;
    _focusNodes = focusNodesCopy;
    _roomSelectedFiles = roomSelectedFilesCopy;
  });
}
void _pickMedia({required bool isImage, required int roomIndex}) async {
  final ImagePicker _picker = ImagePicker();
  List<XFile>? pickedFiles = [];

  if (isImage) {
    pickedFiles = await _picker.pickMultiImage(); // สำหรับเลือกภาพ
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

  if (pickedFiles.isNotEmpty) {
    // ตรวจสอบว่า index สำหรับ combinedData
    if (roomIndex < combinedData.length) {
      int currentFileCount = _roomSelectedFiles[roomIndex].value.length;
      int newFileCount = pickedFiles.length;

      // ตรวจสอบจำนวนไฟล์
      if (currentFileCount + newFileCount > 5) {
        _showErrorDialog('ไม่สามารถส่งไฟล์เกิน 5 ไฟล์ได้');
        return;
      }

      // ตรวจสอบขนาดไฟล์
      List<XFile> validFiles = [];
      for (var file in pickedFiles) {
        int fileSize = await file.length(); 
        if (fileSize > 100 * 1024 * 1024) { 
          _showErrorDialog('พบไฟล์ที่มีขนาดเกิน 100MB กรุณาเลือกใหม่');
          return; // หยุดทำงานทันทีหากพบไฟล์ที่ใหญ่เกินไป
        }
        validFiles.add(file);
      }

      // เพิ่มไฟล์ที่ผ่านการตรวจสอบเข้าไป
      _roomSelectedFiles[roomIndex].value = List.from(_roomSelectedFiles[roomIndex].value)..addAll(validFiles);
      _roomSelectedFiles[roomIndex].notifyListeners();
    }
  }
}


Widget _buildPreview(int roomIndex) {
  return ValueListenableBuilder<List<XFile>>(
    valueListenable: _roomSelectedFiles[roomIndex],
    builder: (context, files, child) {
      if (files.isEmpty) return SizedBox();

      return Padding(
        padding: EdgeInsets.all(8.0),
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: List.generate(files.length, (index) {
            final file = files[index];
            final isImage = file.path.endsWith('.jpg') || file.path.endsWith('.png');

            return Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  child: isImage
                      ? Image.file(File(file.path), fit: BoxFit.cover)
                      : AspectRatio(
                          aspectRatio: 16 / 9,
                          child: VideoPlayerWidget(
                            filePath: file.path,
                            onPlayPause: _togglePlayPause,
                            onControllerCreated: _onControllerCreated,
                            hideSlider: true,
                          ),
                        ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
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
                                  // ลบไฟล์เมื่อกดยืนยัน
                                  _roomSelectedFiles[roomIndex].value = List.from(_roomSelectedFiles[roomIndex].value)..removeAt(index);
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
            );
          }),
        ),
      );
    },
  );
}

Future<String?> getPresignedUrl(String fileName, String fileType) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  
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
        return jsonResponse['url']; 
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


Future<List<String>> uploadMultipleFilesToS3(List<String> filePaths, String presignedUrl, List<String> fileNames, String mimeType) async {
  try {
    List<Future<String?>> uploadTasks = [];
    for (int i = 0; i < filePaths.length; i++) {
      String filePath = filePaths[i];
      String fileName = fileNames[i];
      uploadTasks.add(uploadFileToS3(filePath, presignedUrl, fileName, mimeType));
    }

    // รอให้การอัพโหลดทั้งหมดเสร็จสิ้น
    List<String?> fileUrls = await Future.wait(uploadTasks);

    // กรองเฉพาะ URL ที่ไม่เป็น null
    return fileUrls.where((url) => url != null).cast<String>().toList();
  } catch (e) {
    print('Error uploading files: $e');
    return [];
  }
}

Future<String?> uploadFileToS3(String filePath, String presignedUrl, String fileName, String mimeType) async {
  try {

    final fileBytes = await File(filePath).readAsBytes();
    final request = http.Request('PUT', Uri.parse(presignedUrl))
      ..headers['Content-Type'] = mimeType
      ..bodyBytes = fileBytes;
    String amazonUrl = dotenv.env['AmazonS3_BUCKET_LOCATION'] ?? '';
    final response = await request.send();
    if (response.statusCode == 200) {
      print('File uploaded successfully!');
      final fileUrl = '$amazonUrl/$fileName';
      return fileUrl;
    } else {
      print('Failed to upload file: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Error uploading file: $e');
    return null;
  }
}
String generateRandomFileName(String originalName) {
  var uuid = Uuid();
  String randomString = uuid.v4();  // ใช้ UUID เพื่อสร้างชื่อไฟล์แบบสุ่ม
  String extension = originalName.split('.').last;  // รับนามสกุลไฟล์จากชื่อไฟล์ต้นฉบับ
  return '$randomString.$extension';  // สร้างชื่อไฟล์ใหม่
}

void _showPreviewDialog(int roomIndex) {
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: Text('ดูเพิ่มเติม'),
          content: SingleChildScrollView(
            child: Column(
              children: List.generate(_roomSelectedFiles[roomIndex].value.length, (index) {
                final file = _roomSelectedFiles[roomIndex].value[index];
                final isImage = file.path.endsWith('.jpg') || file.path.endsWith('.png');

                return Stack(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width * 0.3, 
                      height: MediaQuery.of(context).size.height * 0.2, 
                      child: isImage
                          ? Image.file(File(file.path), fit: BoxFit.cover)
                          : AspectRatio(
                              aspectRatio: 16 / 9,
                              child: VideoPlayerWidget(
                                filePath: file.path,
                                onPlayPause: _togglePlayPause,
                                onControllerCreated: _onControllerCreated,
                                hideSlider: true,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setStateDialog(() {
                            _roomSelectedFiles[roomIndex].value = List.from(_roomSelectedFiles[roomIndex].value)..removeAt(index);
                          });
                          _roomSelectedFiles[roomIndex].notifyListeners();
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('ปิด'),
            ),
          ],
        );
      },
    ),
  );
}

@override
Widget build(BuildContext context) {
  // เพิ่มฟังก์ชันเพื่อดึงขนาดหน้าจอ
  double screenWidth = MediaQuery.of(context).size.width;
  double screenHeight = MediaQuery.of(context).size.height;

  return Scaffold(
    backgroundColor: Colors.white,
    body: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.04),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "แจ้งซ่อม",
                style: GoogleFonts.kanit(
                  textStyle: TextStyle(
                    color: Colors.black,
                    fontSize: screenWidth * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (combinedData.isNotEmpty)
              ...combinedData.asMap().entries.map((entry) {
                final int index = entry.key;
                final dynamic roomName = entry.value;

                // ตรวจสอบประเภทของข้อมูล
                String displayName = '';
                if (roomName is String) {
                  displayName = roomName;
                } else if (roomName is int) {
                  displayName = roomName.toString();
                }


                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          vertical: screenHeight * 0.02,
                          horizontal: screenWidth * 0.04,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey, width: 2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              displayName.length > 26? '${displayName.substring(0, 26)}...' : displayName,
                              style: GoogleFonts.kanit(
                                color: Colors.black,
                                fontSize: screenWidth * 0.04,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    double dialogWidth = screenWidth * 1;
                                    return AlertDialog(
                                      backgroundColor: Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      content: SingleChildScrollView(
                                        child: Container(
                                          width: dialogWidth,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Center(
                                                child: Text(
                                                  "แจ้งซ่อม: $displayName",
                                                  style: GoogleFonts.kanit(
                                                    color: Colors.black,
                                                    fontSize: screenWidth * 0.04,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    height: screenHeight * 0.25,
                                                    color: Colors.white,
                                                    child: Stack(
                                                      children: [
                                                        if (index >= 0)
                                                          TextField(
                                                            textAlignVertical: TextAlignVertical.top,
                                                            controller: _textControllers[index],
                                                            maxLines: null,
                                                            expands: true,
                                                            keyboardType: TextInputType.multiline,
                                                            style: GoogleFonts.kanit(
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                            decoration: const InputDecoration(
                                                              filled: true,
                                                              fillColor: Colors.white,
                                                              hintText: "เพิ่มข้อความ...",
                                                              border: OutlineInputBorder(),
                                                              contentPadding: EdgeInsets.only(left: 10.0, top: 12.0, right: 40.0),
                                                            ),
                                                          )
                                                        else
                                                            Text("TextField not displayed, index: $index"), 
                                                        Positioned(
                                                          top: 10,
                                                          right: 10,
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons.attach_file,
                                                              color: Colors.black,
                                                            ),
                                                            onPressed: () {
                                                              showModalBottomSheet(
                                                                context: context,
                                                                builder: (context) {
                                                                  return Wrap(
                                                                    children: [
                                                                      ListTile(
                                                                        leading: const Icon(Icons.image),
                                                                        title: const Text('เลือกภาพ'),
                                                                        onTap: () {
                                                                          Navigator.pop(context);
                                                                          _pickMedia(isImage: true, roomIndex: index);
                                                                        },
                                                                      ),
                                                                      ListTile(
                                                                        leading: const Icon(Icons.video_library),
                                                                        title: const Text('เลือกวิดีโอ'),
                                                                        onTap: () {
                                                                          Navigator.pop(context);
                                                                          _pickMedia(isImage: false, roomIndex: index);
                                                                        },
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
                                                  ),
                                                  const SizedBox(width: 10),
                                                  if (index >= 0 && index < _roomSelectedFiles.length)
                                                    ValueListenableBuilder<List<XFile>>(
                                                      valueListenable: _roomSelectedFiles[index],
                                                      builder: (context, selectedFiles, child) {
                                                        return _buildPreview(index);
                                                      },
                                                    )
                                                  else
                                                    const SizedBox.shrink(),
                                                  const Divider(
                                                    color: Colors.grey,
                                                    thickness: 2,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                                GestureDetector(
                                          onTap: () async {
                                            setState(() {
                                              isLoading = true;
                                            });
                                            Navigator.pop(context);
                                            await createPost(index);
                                            setState(() {
                                              isLoading = false;
                                            });
                                          },
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: screenWidth * 0.05,
                                              vertical: screenHeight * 0.01,
                                            ),
                                            child: DecoratedBox(
                                              decoration: const BoxDecoration(
                                                color: Colors.green,
                                                borderRadius: BorderRadius.zero,
                                              ),
                                              child: Center(
                                                child: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: screenHeight * 0.015,
                                                  ),
                                                  child: Text(
                                                    "ส่งการแจ้งซ่อม",
                                                    style: GoogleFonts.kanit(
                                                      color: Colors.white,
                                                      fontSize: screenWidth * 0.04,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),

                                              const SizedBox(height: 10),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Image.asset(
                                'assets/images/edit.png',
                                width: screenWidth * 0.06,
                                height: screenWidth * 0.06,
                              ),
                            ),
                            const SizedBox(width: 10),
                         IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                // แสดง confirmation dialog ก่อนลบ
                                showDialog(
                                  context: context,
                                  builder: (BuildContext dialogContext) {
                                    return AlertDialog(
                                      title: Text("ยืนยันการลบ"),
                                      content: Text("คุณต้องการลบห้องนี้หรือไม่?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(dialogContext).pop(); // ปิด Dialog
                                          },
                                          child: Text("ยกเลิก"),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            deleteRoomsByIndex(index); // ลบห้อง
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
                    ),
                  ],
                );
              }).toList(),
          ],
        ),
      ),
    ),
  );
}

}


