import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notification_maintenance_provider.dart';
import '../notification_follow_provider.dart';
import '../notification_provider_user.dart';
import '../notification_follow_provider_initial.dart';
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
  List<dynamic> isUnread_ = [];

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
        bottomNavigationBar: Admin_menu(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
    );
  }
}

class Admin_menu extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const Admin_menu({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ดึงค่า hasMaintenanceNotification
    bool hasMaintenanceNotification = Provider.of<NotificationProvider>(context).hasMaintenanceNotification;
    bool hasStatusFollowNotification = Provider.of<Notification_FollowProvider>(context).hasFollowNotification;
    bool initial = Provider.of<NotificationFollowInitialProvider>(context).hasFollowNotification;

    final user = Provider.of<NotificationUserProvider>(context).user;
    final userName = Provider.of<UserProvider>(context).userName;
    // พิมพ์ค่าของ hasMaintenanceNotification เพื่อดูว่าเป็นค่าอะไร
    print("user $user");
    print('userName $userName');
    print("hasMaintenanceNotification: $hasMaintenanceNotification");
    print("hasStatusFollowNotification: $hasStatusFollowNotification");
    return 
    Theme(
      data: ThemeData(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    ),
    child:BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(
        color: Colors.green, // สีเขียวเมื่อเลือก
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: const TextStyle(
        color: Colors.grey, // สีเทาเมื่อยังไม่เลือก
      ),
      
      items: <BottomNavigationBarItem>[

        _buildNavItem(
          isSelected: selectedIndex == 0,
          label: 'หน้าหลัก',
          selectedImage: 'assets/images/home-green.png',
          unselectedImage: 'assets/images/home-icon.png',
        ),
        _buildNavItem(
          isSelected: selectedIndex == 1,
          label: 'งานซ่อม',
          selectedImage: 'assets/images/fix-green.png',
          unselectedImage: 'assets/images/fix-report.png',
          hasNotification: hasMaintenanceNotification,
          hasStatusFollowNotification: hasStatusFollowNotification
        ),
        _buildNavItemFollow(
          isSelected: selectedIndex == 2,
          label: 'ติดตามสถานะ',
          selectedImage: 'assets/images/follow-green.png',
          unselectedImage: 'assets/images/follow-icon.png',
          hasStatusFollowNotification: hasStatusFollowNotification,
          initial: initial,
          user: user,
          userName: userName,
        ),
        _buildNavItem(
          isSelected: selectedIndex == 3,
          label: 'ประวัติ',
          selectedImage: 'assets/images/history-green.png',
          unselectedImage: 'assets/images/history-icon.png',
        ),
        _buildNavItem(
          isSelected: selectedIndex > 4,
          label: 'อื่น ๆ',
          selectedImage: 'assets/images/other-icon-green.png',
          unselectedImage: 'assets/images/other-icon.png',
        ),
      ],
      currentIndex: selectedIndex.clamp(0, 4),
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
    bool hasNotification = false, 
    bool hasStatusFollowNotification = false,
    
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
          if (hasNotification || hasStatusFollowNotification) 
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
 BottomNavigationBarItem _buildNavItemFollow({
    required bool isSelected,
    required String label,
    required String selectedImage,
    required String unselectedImage,
    bool hasStatusFollowNotification = false,
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
          if (hasStatusFollowNotification && (user == userName) || initial) 
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
