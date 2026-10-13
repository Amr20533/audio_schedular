import 'package:audio_scheduler/views/main_view.dart';
import 'package:flutter/material.dart';
import 'controllers/app_controller.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle notification tap to open Adhan Screen when locked phone is unlocked
    },
  );

  runApp(const AdhanApp());
} 

class AdhanApp extends StatefulWidget {
  const AdhanApp({super.key});
 
  @override
  State<AdhanApp> createState() => _AdhanAppState();
}
 
class _AdhanAppState extends State<AdhanApp> {
  final AppController _controller = AppController();
 
  @override
  void initState() {
    super.initState();
    _controller.init();
  }
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Signatures Player',
      theme: ThemeData(
        // colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFAC643B)),
        useMaterial3: true,
      ),
      home: MainView(controller: _controller),
    );
  }
}
