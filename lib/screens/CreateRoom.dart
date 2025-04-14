import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../UserProvider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';

class RoomPage extends StatefulWidget {
  final String userName;
  final String roleName;

  const RoomPage({Key? key, required this.userName, required this.roleName})
      : super(key: key);

  @override
  _RoomPageState createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  bool isLoading = false;
  List<dynamic> floors = [];
  List<dynamic> rooms = [];
  List<String> roomDataCheck = [];
  List<String> roomDataCheckNothide = [];
  List<String> roomData = []; 
  String? selectedFloor;
  String apiURL = dotenv.env['API_URL'] ?? '';
  final TextEditingController roomNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchFloors();
  }

Future<void> fetchFloors() async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    final response = await http.get(
      Uri.parse('$apiURL/api/room/floorNotHide'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json', 
      },
    );
    if (response.statusCode == 200) {
      setState(() {
        floors = json.decode(response.body);
      });
    } else {
      print('Failed to load floors: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching floors: $e');
  }
}

Future<void> fetchRooms(String floorNumber) async {
  setState(() {
    isLoading = true;
    rooms.clear();
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;  // หากต้องการใช้งาน accessToken
    final response = await http.get(
      Uri.parse('$apiURL/api/room/RoombyFloor/$floorNumber'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',  
      },
    );
    
    if (response.statusCode == 200) {
      setState(() {
        rooms = json.decode(response.body);
        isLoading = false;
      });
    } else {
      print('Failed to load rooms: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching rooms: $e');
    setState(() {
      isLoading = false;
    });
  }
}

Future<void> hideRoom(String roomId) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    final response = await http.put(
      Uri.parse('$apiURL/api/room/hideRoom/$roomId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      if (mounted) {
        setState(() {
          rooms.removeWhere((room) => room['room_id'].toString() == roomId);
        });
        fetchRooms(selectedFloor!);
      }
    } else {
      print('Failed to hide room: ${response.statusCode}');
    }
  } catch (e) {
    print('Error hiding room: $e');
  }
}

Future<void> unhideRoom(String roomNumber,String roomId) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    print('Unhiding roomId: $roomNumber');
    await _fetchAllRoomsnothide(context);
  // ตรวจสอบห้องใหม่ซ้ำกับห้องที่มีอยู่หรือไม่
    print('RoomDataCheckNothide: $roomDataCheckNothide');
      if (roomDataCheckNothide.contains(roomNumber)) {
        showAlertDialog('มีห้องที่เปิดใช้งานอยู่แล้ว 1 ห้องกรุณาซ่อนห้องดังกล่าวก่อนถึงจะใช้งานห้องนี้ได้');
        return;
      }

    final response = await http.put(
      Uri.parse('$apiURL/api/room/unhideRoom/$roomId'),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      print('Response status unhide: ${response.statusCode}');

      // โหลดข้อมูลใหม่หลังจาก unhide
      if (selectedFloor != null) {
        fetchRooms(selectedFloor!);
      } else {
        _fetchAllRooms(context);
      }
      
      print('Room $roomId successfully unhidden.');
    } else {
      print('Failed to unhide room: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error unhiding room: $e');
  }
}
Future<void> _fetchAllRoomsnothide(BuildContext context) async {
  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    print('Fetching rooms...'); // Log ว่าเริ่มดึงข้อมูล

    final response = await http.get(
      Uri.parse('$apiURL/api/room/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print('Received data: $data'); // Log Data ที่ได้รับ

      if (mounted) {
        setState(() {
          roomDataCheckNothide = List<String>.from(
            data.where((room) => room['isnot_hide'] == true)
                .map((room) => room['room_number'].toString()),
          );
          isLoading = false;
        });
      }
    } else {
      print('Error: ${response.body}'); 
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      throw Exception('ไม่สามารถโหลดข้อมูลห้องได้: ${response.body}');
    }
  } catch (e) {
    print('Exception: $e');

    // แสดงแจ้งเตือนให้ผู้ใช้
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
      );
    }
  }
}

Future<void> _fetchAllRooms(BuildContext context) async {
  setState(() {
    isLoading = true;
  });

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    print('Fetching rooms...'); // Log ว่าเริ่มดึงข้อมูล

    final response = await http.get(
      Uri.parse('$apiURL/api/room/'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );

    print('Response status: ${response.statusCode}'); // Log Status Code

    if (response.statusCode == 200) {
      var data = json.decode(response.body);
      print('Received data: $data'); // Log Data ที่ได้รับ

      if (mounted) {
        setState(() {
          roomDataCheck = List<String>.from(
            data.map((room) => room['room_number'].toString()),
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
        SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
      );
    }
  }
}

Future<void> createRoom() async {
  final roomName = roomNameController.text.trim();
  await _fetchAllRoomsnothide(context);
  if (roomName.isEmpty) {
    showAlertDialog('กรุณากรอกชื่อห้อง่ที่ช่องชื่อช่อง');
    return;
  }

  if (!RegExp(r'^\d+$').hasMatch(roomName)) {
    showAlertDialog('ชื่อห้องต้องเป็นตัวเลขเท่านั้น');
    return;
  }
  if(roomName.characters.length > 3){
    showAlertDialog('ชื่อห้องต้องมีความยาวไม่เกิน 3 ตัวอักษร');
    return;
  }

  if (roomDataCheckNothide.contains(roomName)) {
    showAlertDialog('ห้องซ้ำ กรุณาซ่อนห้องเก่าก่อน');
    return;
  }

  try {
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
    final response = await http.post(
      Uri.parse('$apiURL/api/room/createRoom'),
      headers: {
        'Authorization': 'Bearer $accessToken', 
        'Content-Type': 'application/json', 
      },
      body: json.encode({'roomName': roomName}),
    );

    if (response.statusCode == 201) {
      final newRoom = json.decode(response.body);
      setState(() {
        rooms.add(newRoom);
      });
      roomNameController.clear();  // ล้างฟอร์ม

      // Fetch rooms ใหม่สำหรับชั้นที่เลือกอยู่
      if (selectedFloor != null) {
        fetchRooms(selectedFloor!);  // เรียกฟังก์ชัน fetchRooms ใหม่
      }
      await fetchFloors();
      showAlertDialog('สร้างห้องเรียบร้อยแล้ว');
    } else {
      showAlertDialog('ไม่สามารถสร้างห้องได้ กรุณาลองใหม่อีกครั้ง');
      print('Failed to create room: ${response.statusCode}');
    }
  } catch (e) {
    print('Error creating room: $e');
  }
}


  void showAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('แจ้งเตือน'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ตกลง'),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  double width = MediaQuery.of(context).size.width;
  double height = MediaQuery.of(context).size.height;

  return Scaffold(
    backgroundColor: Colors.white,
    body: Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.04,
            vertical: height * 0.02,
          ),
          child: DropdownButtonFormField<String>(
            value: selectedFloor,
            hint: Text('เลือกชั้น'),
            onChanged: (value) {
              setState(() {
                selectedFloor = value;
              });
              if (value != null) {
                fetchRooms(value);
              }
            },
            items: floors.map((floor) {
              return DropdownMenuItem<String>(
                value: floor['first_digit'],
                child: Text('ชั้น ${floor['first_digit']}'),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: width * 0.04,
            vertical: height * 0.02,
          ),
          child: TextField(
            controller: roomNameController,
            decoration: InputDecoration(
              labelText: 'ชื่อห้อง...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            createRoom();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: Size(width * 0.8, height * 0.07),
          ),
          child: Text('สร้างห้อง'),
        ),
        SizedBox(
          height: height * 0.02,
        ),
        Expanded(
          child: selectedFloor == null
              ? Center(
                  child: Text(
                    'กรุณาเลือกชั้นเพื่อดูรายชื่อห้อง',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        return Card(
                          margin: EdgeInsets.symmetric(
                            vertical: height * 0.01,
                            horizontal: width * 0.04,
                          ),
                          color: room['isnot_hide'] == false
                              ? Colors.grey[300]
                              : null,
                          child: ListTile(
                            title: Text(
                              'ห้อง ${room['room_number']}',
                              style: TextStyle(
                                color: room['isnot_hide'] == false
                                    ? Colors.black
                                    : null,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (room['isnot_hide'] != false)
                                  IconButton(
                                    icon: Icon(Icons.visibility_off),
                                    onPressed: () {
                                      hideRoom(room['room_id'].toString());
                                    },
                                  ),
                                if (room['isnot_hide'] == false)
                                  IconButton(
                                    icon: Icon(Icons.visibility),
                                    onPressed: () {
                                      unhideRoom(room['room_number'].toString(),room['room_id'].toString());
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
  );
}
}
