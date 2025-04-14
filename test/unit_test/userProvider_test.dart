import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fixnow/screens/welcome_page.dart';
import 'package:fixnow/UserProvider.dart';

void main() {
  testWidgets('Should show WelcomeScreen when user is not logged in', (WidgetTester tester) async {
    // Mock the UserProvider
    final mockUserProvider = UserProvider();

    // กำหนดค่า userName, roleName ให้เป็นค่าว่างเพื่อแสดงว่าไม่ได้ล็อกอิน
    mockUserProvider.setUserData("", "", "");

    // Build the widget tree
    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>(
        create: (_) => mockUserProvider,
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    // Verify if WelcomeScreen is displayed
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}
