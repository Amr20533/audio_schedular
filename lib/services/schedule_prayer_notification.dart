import 'package:audio_scheduler/main.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

Future<void> schedulePrayerNotification(int id, String prayerName, DateTime scheduledTime) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'adhan_channel_id',
    'Adhan Notifications',
    channelDescription: 'Notifications for exact prayer times',
    importance: Importance.max,
    priority: Priority.high,
    sound: RawResourceAndroidNotificationSound('adhan'),
    playSound: true,
    fullScreenIntent: true,
  );

  const NotificationDetails notificationDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id,
    'Time for $prayerName',
    'Tap to open Adhan',
    tz.TZDateTime.from(scheduledTime, tz.local),
    notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
  );
}