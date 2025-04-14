import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'dart:io';
import 'Login_page.dart';


class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonWidth = (screenWidth > 600 ? 300 : screenWidth * 0.5).toDouble();


    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Image.asset(
                'assets/images/fixnow-logo.png',
                width: screenWidth * 0.5,
                height: screenHeight * 0.3,
                fit: BoxFit.contain,
              ),
            ),
            AutoSizeText(
              'FIXNOW',
              style: GoogleFonts.kanit(
                textStyle: TextStyle(
                  color: const Color(0xFF4CAF50),
                  fontSize: screenWidth * 0.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              maxLines: 1,
              minFontSize: 20, 
            ),
            SizedBox(height: screenHeight * 0.03),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Container(
                width: buttonWidth,
                height: screenHeight * 0.08,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.01,
                  horizontal: screenWidth * 0.03,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: AutoSizeText(
                    'เข้าใช้งาน',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth * 0.06, // ขนาดตัวอักษรที่ยืดหยุ่น
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    maxLines: 1,
                    minFontSize: 12, // ขนาดฟอนต์ต่ำสุด
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            GestureDetector(
              onTap: () {
                exit(0);
              },
              child: Container(
                width: buttonWidth,
                height: screenHeight * 0.08,
                padding: EdgeInsets.symmetric(
                  vertical: screenHeight * 0.01,
                  horizontal: screenWidth * 0.03,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: const Color(0xFFD4D6DD),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: AutoSizeText(
                    'ออก',
                    style: GoogleFonts.kanit(
                      textStyle: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth * 0.06, // ขนาดตัวอักษรที่ยืดหยุ่น
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    maxLines: 1,
                    minFontSize: 12, // ขนาดฟอนต์ต่ำสุด
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
