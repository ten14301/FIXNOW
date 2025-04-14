import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:download/download.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import '../UserProvider.dart';

class ReportPage extends StatefulWidget {
  @override
  _ReportPageState createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  List<Map<String, dynamic>> data = [];
  List<Map<String, dynamic>> filteredData = [];
  bool isLoading = true;
  String filterKeyword = "";
  String filterStatus = "ทั้งหมด";
  int currentPage = 1;
  int itemsPerPage = 5;
  bool _isDisposed = false;
  String apiURL = dotenv.env['API_URL'] ?? '';
  @override
  void initState() {
    super.initState();
    fetchData();
  }
  void dispose() {
  _isDisposed = true;
  super.dispose();
}

Future<void> _downloadCSV(BuildContext context) async {
  try {
    List<List<String>> csvData = [
      ["ชื่อผู้แจ้ง", "วันที่", "ข้อมูลคำขอ", "สถานะ"],
      ...filteredData.map((row) => [
            row['user_name'] ?? '',
            row['date']?.split('T')[0] ?? '',
            row['request_info'] ?? '',
            row['current_status'] ?? '',
          ])
    ];

    String csvString = const ListToCsvConverter().convert(csvData);
    Uint8List csvBytes = Uint8List.fromList(utf8.encode('\ufeff$csvString'));

    if (Platform.isAndroid) {
      if (await Permission.storage.request().isGranted || await Permission.manageExternalStorage.request().isGranted) {
        Directory? directory;
        if (Platform.version.contains("29") || Platform.version.contains("30")) {
          directory = await getExternalStorageDirectory();  // Scoped Storage
        } else {
          directory = await getDownloadsDirectory(); // สำหรับเวอร์ชันเก่า
        }

        if (directory != null) {
          String path = "${directory.path}/filtered_report.csv";
          File file = File(path);
          await file.writeAsBytes(csvBytes);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("ไฟล์ CSV ถูกดาวน์โหลดเรียบร้อย ที่ $path")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("ไม่สามารถเข้าถึงโฟลเดอร์ดาวน์โหลดได้")),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ไม่ได้รับอนุญาตให้เข้าถึงพื้นที่เก็บข้อมูล")),
        );
      }
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/filtered_report.csv";
      final file = File(path);
      await file.writeAsBytes(csvBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ไฟล์ CSV ถูกบันทึกที่ $path")),
      );

      OpenFile.open(path);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
    );
  }
}

Future<void> fetchData() async {
  try {
    // ดึง accessToken จาก Provider หรือจากแหล่งข้อมูลที่ใช้ในการจัดการการยืนยันตัวตน
    final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;

    // ส่งคำขอ GET พร้อม Authorization header
    final response = await http.get(
      Uri.parse("$apiURL/api/maintenance/AllRequest"),
      headers: {
        'Authorization': 'Bearer $accessToken',  
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final responseData = json.decode(response.body);
      if (responseData['success'] == true && !_isDisposed) {
        setState(() {
          // หากได้รับข้อมูลสำเร็จ, อัปเดต data และ filteredData
          data = List<Map<String, dynamic>>.from(responseData['data']);
          filteredData = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load data");
      }
    } else {
      throw Exception("Failed to load data");
    }
  } catch (e) {
    if (!_isDisposed) {
      setState(() {
        isLoading = false;  // เปลี่ยนสถานะการโหลด
      });
    }
    print("Error fetching data: $e");
  }
}


void filterData() {
  setState(() {
    filteredData = data.where((row) {
      final keywordLower = filterKeyword.toLowerCase();

      final matchesKeyword = (row['user_name']?.toString().toLowerCase().contains(keywordLower) ?? false) ||
          (row['date']?.toString().toLowerCase().contains(keywordLower) ?? false) ||
          (row['request_info']?.toString().toLowerCase().contains(keywordLower) ?? false) ||
          (row['current_status']?.toString().toLowerCase().contains(keywordLower) ?? false);
      
      // ตรวจสอบสถานะ
      final matchesStatus = filterStatus == "ทั้งหมด" ||
          row['current_status']?.toString() == filterStatus;

      return matchesKeyword && matchesStatus;
    }).toList();
    currentPage = 1;
  });
}


  List<Map<String, dynamic>> getCurrentPageData() {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    return filteredData.sublist(
        startIndex, endIndex > filteredData.length ? filteredData.length : endIndex);
  }

  int getTotalPages() {
    return (filteredData.length / itemsPerPage).ceil();
  }

  String truncateText(String text, int maxLength) {
    if (text.length > maxLength) {
      return "${text.substring(0, maxLength)}...";
    }
    return text;
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    resizeToAvoidBottomInset: true,
    body: isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pie Chart
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // กราฟ
                    SfCircularChart(
                      title: ChartTitle(
                        text: 'สถานะคำขอ',
                        textStyle: GoogleFonts.kanit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      legend: Legend(isVisible: false), // ซ่อน Legend ของตัวกราฟ
                      series: <CircularSeries>[
                        PieSeries<_ChartData, String>(
                          dataSource: _getChartData(),
                          xValueMapper: (_ChartData data, _) => data.label,
                          yValueMapper: (_ChartData data, _) => data.value,
                          pointColorMapper: (_ChartData data, _) => data.color,
                          dataLabelSettings: DataLabelSettings(isVisible: false), // ซ่อน Label บนกราฟ
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ตัวเลขนอกกราฟ
                    Text(
                      "รายละเอียดสถานะ:",
                      style: GoogleFonts.kanit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // แสดงรายการสถานะและจำนวน
                    ..._getChartData().map((data) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: data.color, // สีที่ใช้ในกราฟ
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${data.label}: ${data.value}', // สถานะและจำนวน
                              style: GoogleFonts.kanit(fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),

                  const SizedBox(height: 8),

                  // ปุ่มดาวน์โหลด
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        _downloadCSV(context); // ฟังก์ชันดาวน์โหลด CSV
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/images/csv-icon.png', 
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ดาวน์โหลด',
                              style: GoogleFonts.kanit(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ช่องค้นหาและตัวกรอง
                  // ช่องค้นหาและตัวกรอง
                  Row(
                    children: [
                      // ปุ่มตัวกรอง
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showFilterPopup(context); // เรียก Popup ตัวกรอง
                          },
                          icon: Icon(Icons.filter_alt, size: 24, color: Colors.black),
                          label: Text(
                            'ตัวกรอง',
                            style: GoogleFonts.kanit(fontSize: 14, color: Colors.black),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white, // พื้นหลังสีขาว
                            elevation: 0, // ไม่มีเงา
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.zero, // ไม่มี border radius
                            ),
                            minimumSize: Size(50, 48),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // ช่องค้นหา
                      Expanded(
                        flex: 3,
                        child: TextField(
                          onChanged: (value) {
                            filterKeyword = value;
                            filterData();
                          },
                          decoration: InputDecoration(
                            hintText: 'ค้นหา',
                            hintStyle: GoogleFonts.kanit(),
                            filled: true, // เปิดการใส่สีพื้นหลัง
                            fillColor: Colors.white, // พื้นหลังสีขาว
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black), // เส้นขอบสีดำ
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.black), // เส้นขอบปกติ
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue, width: 2.0), // เส้นขอบเมื่อโฟกัส
                            ),
                            prefixIcon: Icon(Icons.search, color: Colors.black), // เพิ่มไอคอนค้นหา
                            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16), // เพิ่ม padding ภายใน
                          ),
                        ),
                      ),
                    ],
                  ),


                  const SizedBox(height: 16),

                  // หัวข้อ
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          "คนแจ้ง",
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          "วันที่",
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          "เนื้อหา",
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          "สถานะ",
                          style: GoogleFonts.kanit(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  Divider(thickness: 2),

                  // ข้อมูลแบบ Column + Divider
                  ListView.builder(
                    shrinkWrap: true, // ทำให้ ListView ใช้พื้นที่เท่าที่จำเป็น
                    physics: NeverScrollableScrollPhysics(), // ปิดการ Scroll ภายใน
                    itemCount: getCurrentPageData().length,
                    itemBuilder: (context, index) {
                      final item = getCurrentPageData()[index];
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  truncateText(item['user_name'] ?? '-', 8),
                                  style: GoogleFonts.kanit(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  item['date']?.split('T')[0] ?? '-',
                                  style: GoogleFonts.kanit(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  truncateText(item['request_info'] ?? '-', 10),
                                  style: GoogleFonts.kanit(),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  item['current_status'] ?? '-',
                                  style: GoogleFonts.kanit(
                                    color: _getStatusColor(item['current_status']),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          Divider(thickness: 1),
                        ],
                      );
                    },
                  ),

                  // Pagination
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _buildPaginationButtons(),
                  ),
                ],
              ),
            ),
          ),
  );
}


List<Widget> _buildPaginationButtons() {
  int totalPages = getTotalPages();
  List<Widget> buttons = [];
  int currentGroupStart = ((currentPage - 1) ~/ 4) * 4 + 1;

  // ปุ่มย้อนกลับ `<`
  if (currentGroupStart > 1) {
    buttons.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0), // เพิ่มระยะห่าง
        child: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              currentPage = currentGroupStart - 1;
            });
          },
        ),
      ),
    );
  }

  // ปุ่มในกลุ่มปัจจุบัน
  for (int i = currentGroupStart; i < currentGroupStart + 4 && i <= totalPages; i++) {
    buttons.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3), // เพิ่มระยะห่าง
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              currentPage = i;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: currentPage == i ? Colors.blue : Colors.grey,
            minimumSize: Size(40, 40),
          ),
          child: Text(
            "$i",
            style: GoogleFonts.kanit(color: Colors.white),
          ),
        ),
      ),
    );
  }

  // ปุ่มเลื่อนไปข้างหน้า `>`
  if (currentGroupStart + 4 <= totalPages) {
    buttons.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0), // เพิ่มระยะห่าง
        child: IconButton(
          icon: Icon(Icons.arrow_forward),
          onPressed: () {
            setState(() {
              currentPage = currentGroupStart + 4;
            });
          },
        ),
      ),
    );
  }

  return buttons;
}
void _showFilterPopup(BuildContext context) async {
  final double screenWidth = MediaQuery.of(context).size.width;
  final double screenHeight = MediaQuery.of(context).size.height;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
    ),
    backgroundColor: Colors.white,
    builder: (BuildContext context) {
      String? selectedStatus = filterStatus;
      String? selectedDateRange;

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
                        'ตัวกรอง',
                        style: GoogleFonts.kanit(
                          textStyle: TextStyle(
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
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
                SizedBox(height: screenHeight * 0.01),
                Padding(
                  padding: EdgeInsets.only(left: screenWidth * 0.02, bottom: screenHeight * 0.005),
                  child: 
                  Align(
                    alignment: Alignment.centerLeft,
                  child:Text(
                    'สถานะ',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF807A7A),
                      ),
                    ),
                  ),
                  ),
                ),
                ...['รอรับเรื่อง', 'รอการสำรวจ', 'อยู่ระหว่างการแก้ไข', 'ดำเนินการเสร็จสิ้น']
                    .map((status) => Padding(
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(screenWidth * 0.2, screenHeight * 0.05),
                                backgroundColor:
                                    selectedStatus == status ? Colors.green : Colors.white,
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedStatus = selectedStatus == status ? null : status;
                                });
                              },
                              child: Text(
                                status,
                                style: GoogleFonts.kanit(
                                  textStyle: TextStyle(
                                    color: selectedStatus == status ? Colors.white : Colors.black,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),

                SizedBox(height: screenHeight * 0.02),

                // ตัวเลือกวันที่
                Padding(
                  padding: EdgeInsets.only(left: screenWidth * 0.02, bottom: screenHeight * 0.005),
                  child: 
                  Align(
                    alignment: Alignment.centerLeft,
                  child:Text(
                    'วันที่',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        fontSize: screenWidth * 0.03,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF807A7A),
                      ),
                    ),
                  ),
                  ),
                ),

                ...['เก่าสุดไปล่าสุด', 'ล่าสุดไปเก่าสุด']
                    .map((dateRange) => Padding(
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(screenWidth * 0.2, screenHeight * 0.05),
                                backgroundColor: selectedDateRange == dateRange
                                    ? Colors.green
                                    : Colors.white,
                                side: const BorderSide(color: Colors.black),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  selectedDateRange =
                                      selectedDateRange == dateRange ? null : dateRange;
                                });
                              },
                              child: Text(
                                dateRange,
                                style: GoogleFonts.kanit(
                                  textStyle: TextStyle(
                                    color: selectedDateRange == dateRange
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: screenWidth * 0.03,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ))
                    .toList(),

                SizedBox(height: screenHeight * 0.02),

                // ปุ่มตกลง
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(screenWidth * 0.2, screenHeight * 0.06),
                    backgroundColor: const Color(0xFF4CAF50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      filterStatus = selectedStatus ?? "ทั้งหมด";
                      filterData();
                      if (selectedDateRange == 'น้อยไปมาก') {
                        sortData(ascending: true);
                      } else if (selectedDateRange == 'มากไปน้อย') {
                        sortData(ascending: false);
                      }
                    });
                    Navigator.pop(context);
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
}

void sortData({bool ascending = true}) {
  setState(() {
    filteredData.sort((a, b) {
      DateTime dateA = DateTime.parse(a['date']);
      DateTime dateB = DateTime.parse(b['date']);
      return ascending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
    });
  });
}



  Widget _buildPageButton(int page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            currentPage = page;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: currentPage == page ? Colors.blue : Colors.grey,
          minimumSize: Size(40, 40),
        ),
        child: Text(
          "$page",
          style: GoogleFonts.kanit(color: Colors.white),
        ),
      ),
    );
  }

List<_ChartData> _getChartData() {
  // นับจำนวนของแต่ละสถานะจาก filteredData
  Map<String, int> statusCount = {};

  for (var row in filteredData) { 
    String status = row['current_status'] ?? "ไม่ระบุสถานะ";
    if (statusCount.containsKey(status)) {
      statusCount[status] = statusCount[status]! + 1;
    } else {
      statusCount[status] = 1;
    }
  }

  return statusCount.entries
      .map((entry) => _ChartData(entry.key, entry.value, _getStatusColor(entry.key)))
      .toList();
}


Color _getStatusColor(String? status) {
  switch (status) {
    case "ดำเนินการเสร็จสิ้น":
      return Colors.green;
    case "รอการสำรวจ":
      return Colors.red;
    case "อยู่ระหว่างการแก้ไข":
      return Colors.orange;
    case "รอรับเรื่อง":
      return Colors.blue;
    default:
      return Colors.black;
  }
}
}

class _ChartData {
  _ChartData(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}
