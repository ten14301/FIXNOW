import 'package:fixnow/notification_follow_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import  '../notification_follow_provider_initial.dart';
import '../notification_provider_user.dart';
import '../UserProvider.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return 
      Scaffold(
        body: Center(
          child: Text(
            'Selected Index: $_selectedIndex',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        bottomNavigationBar: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
    );
  }
}

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool hasFollowNotification = Provider.of<Notification_FollowProvider>(context).hasFollowNotification;
    bool initial = Provider.of<NotificationFollowInitialProvider>(context).hasFollowNotification;

    final user = Provider.of<NotificationUserProvider>(context).user;
    final userName = Provider.of<UserProvider>(context).userName;

    return
    Theme(
      data: ThemeData(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    child:BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Image.asset(
            selectedIndex == 0
                ? 'assets/images/home-green.png'
                : 'assets/images/home-icon.png',
            width: 30,
            height: 30,
          ),
          label: 'หน้าหลัก',
        ),
        _buildNavItem(
          isSelected: selectedIndex == 1,
          label: 'ติดตามสถานะ',
          selectedImage: 'assets/images/follow-green.png',
          unselectedImage: 'assets/images/follow-icon.png',
          hasFollowNotification: hasFollowNotification,
          initial: initial,
          user: user,
          userName: userName,
        ),
        BottomNavigationBarItem(
          icon: Image.asset(
            selectedIndex == 2
                ? 'assets/images/history-green.png'
                : 'assets/images/history-icon.png',
            width: 30,
            height: 30,
          ),
          label: 'ประวัติ',
        ),
      ],
      currentIndex: selectedIndex.clamp(0, 2),
      selectedItemColor: Colors.green,
      unselectedItemColor: Colors.grey,
      onTap: onItemTapped,
    )
    );
  }
 BottomNavigationBarItem _buildNavItem({
    required bool isSelected,
    required String label,
    required String selectedImage,
    required String unselectedImage,
    bool hasFollowNotification = false,
    bool initial = false,
    String user = "",
    String userName = "",
  }) {
    return BottomNavigationBarItem(
      icon: Stack(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Image.asset(
              isSelected ? selectedImage : unselectedImage,
              fit: BoxFit.contain,
            ),
          ),
          if (hasFollowNotification && (user == userName) || initial) 
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
      label: label,
    );
  }
}
