import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:fixnow/screens/welcome_page.dart';
import 'notification_maintenance_provider.dart';
import 'notification_chat_provider.dart';
import 'notification_status_provider.dart';
import 'package:provider/provider.dart';
import 'notification_status_follow_provider.dart';
import 'notification_follow_provider.dart';
import 'notification_provider_user.dart';
import 'notification_hasFetch.dart';
import 'UserProvider.dart';
import 'room_provider.dart';
import 'notification_hasFetchChange.dart';
import 'notification_announcementFetch.dart';
import 'notification_follow_provider_initial.dart';
import './screens/Homepage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'logout_provider.dart';
import 'chatCheck_provider.dart';
import 'dart:convert';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await dotenv.load();
  bool notificationCheck = false;
  // ตั้งค่าการแจ้งเตือนท้องถิ่น
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  if (message.notification != null) {
    String title = message.notification!.title ?? 'No Title';
    String body = message.notification!.body ?? 'No Body';
        final chatCheck = Provider.of<ChatCheckProvider>(navigatorKey.currentContext!, listen: false).currentChat;
        if (chatCheck && title == "ข้อความใหม่") {
          return;
        }
    flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
          channelDescription: 'การแจ้งเตือนทั่วไป',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
});


  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Opened app from notification: ${message.notification?.title}');
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationStatusProvider()),
        ChangeNotifierProvider(create: (_) => NotificationFollowProvider()),
        ChangeNotifierProvider(create: (_) => Notification_FollowProvider()),
        ChangeNotifierProvider(create: (_) => NotificationHasProvider()),
        ChangeNotifierProvider(create: (_) => NotificationHasChangeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationUserProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => LogoutProvider()),
        ChangeNotifierProvider(create: (_) => NotificationAnnounceFetch()),
        ChangeNotifierProvider(create: (_) => NotificationFollowInitialProvider()),
        ChangeNotifierProvider(create: (_) => ChatCheckProvider()),
      ],
      child: MyApp(notificationCheck: notificationCheck),
    ),
  );
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message: ${message.notification?.title}');
}

class MyApp extends StatelessWidget {
  final bool notificationCheck;

  // แก้ไขคอนสตรัคเตอร์ให้รับพารามิเตอร์ notificationCheck
  const MyApp({Key? key, required this.notificationCheck}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    Future<void> _logoutUser(BuildContext context) async {
          print("User และข้อมูลทั้งหมดถูกล้างแล้ว");
        }

      print("Received message: ${message.notification!.title}");
      if (message.notification!.title == "แจ้งซ่อมบำรุง") {
        // อัปเดต notificationCheck เป็น true เมื่อได้รับการแจ้งเตือน
        final provider = Provider.of<NotificationProvider>(context, listen: false);
        provider.setMaintenanceNotification(true);

        final providerFetch = Provider.of<NotificationHasProvider>(context, listen: false);
        providerFetch.setMaintenanceNotification(true); 

        print("Maintenance Notification: ${provider.hasMaintenanceNotification}");
        print("Provider Fetch Notification: ${providerFetch.hasMaintenanceNotification}");
      }
      else if(message.notification!.title == "ข้อความใหม่"){
        final provider = Provider.of<NotificationChatProvider>(context, listen: false);
        final providerFollow = Provider.of<NotificationFollowProvider>(context, listen: false);
        provider.setMaintenanceNotification(true);
        providerFollow.setStatusFollowNotification(true);

        String Body_message = message.notification!.body!;
        List<String> parts = Body_message.split(' ');
        String requestId = parts.last;

        providerFollow.setStatusFollowMessage(requestId);
        provider.setChatMessage(requestId);
      }
      else if(message.notification!.title == "สถานะการซ่อมเปลี่ยนแปลง"){
        final provider = Provider.of<NotificationStatusProvider>(context, listen: false);
        final providerFollow = Provider.of<NotificationFollowProvider>(context, listen: false);
        final providerFollow_ = Provider.of<Notification_FollowProvider>(context, listen: false);
        final providerMaintenance = Provider.of<NotificationProvider>(context, listen: false);
        providerMaintenance.setMaintenanceNotification(true);
        print("สถานะเปลี่ยนแปลง");
        final providerHasChange = Provider.of<NotificationHasChangeProvider>(context, listen: false);

        final providerUser = Provider.of<NotificationUserProvider>(context, listen: false);

        provider.setStatusNotification(true);
        providerFollow.setStatusFollowNotification(true);
        providerFollow_.setFollowNotification(true);
        providerHasChange.setMaintenanceNotification(true);

        providerUser.clearUser();
        String Body_message = message.notification!.body!;
        List<String> parts = Body_message.split(' ');
        String requestId = parts[1];
        String user = parts[3];

        print("user: $user");
        print("Body_message: $Body_message");

        print('Request ID: $requestId');
        providerUser.setUser(user);
        provider.setStatusMessage(requestId);
        providerFollow.setStatusFollowMessage(requestId);
      }
      else if(message.notification!.title == "แจ้งเตือน Logout"){
        final logoutProvider = Provider.of<LogoutProvider>(context, listen: false);
        logoutProvider.setShouldLogout(true);
      }
      else if(message.notification!.title == "ประกาศใหม่"){
        final provider = Provider.of<NotificationAnnounceFetch>(context, listen: false);
        provider.setMaintenanceNotification(true);
      }
      else if(message.notification!.title == "ประกาศมีการแก้ไข"){
        final provider = Provider.of<NotificationAnnounceFetch>(context, listen: false);
        provider.setMaintenanceNotification(true);
      }
    });

    return MaterialApp(
      title: 'FIXNOW',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: Provider.of<UserProvider>(context, listen: false).loadUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.isLoggedIn) {
                  // ดึง FCM Token และอัปเดต
                  _updateFcmToken(userProvider,context);
                  return HomePage(
                    userName: userProvider.userName,
                    roleName: userProvider.roleName,
                    CheckFirstTime: false,
                    accessToken : userProvider.accessToken,
                  );
                } else {
                  return WelcomeScreen();
                }
              },
            );
          } else {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _updateFcmToken(UserProvider userProvider,context) async {


    String? fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      print("ไม่สามารถรับ FCM Token ได้");
      return;
    }
    await _sendFcmTokenToApi(fcmToken, userProvider,context);
  }

  Future<void> _sendFcmTokenToApi(String fcmToken, UserProvider userProvider,context) async {
    try {
      final accessToken = Provider.of<UserProvider>(context, listen: false).accessToken;
      print('Access Token: $accessToken');
      String apiURL = dotenv.env['API_URL'] ?? '';
      final response = await http.put(
        Uri.parse('$apiURL/api/user/updateFcmToken'),
        headers: <String, String>{
        "Authorization": "Bearer $accessToken", 
        "Content-Type": "application/json",  
        },
        body: jsonEncode(<String, String>{
          'username': userProvider.userName,
          'fcmToken': fcmToken,
        }),
      );
      if (response.statusCode == 200) {
        print('FCM Token ได้รับการอัปเดต');
      } else {
        print('การอัปเดต FCM Token ล้มเหลว');
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปเดต FCM Token: $e');
    }
  }
}
