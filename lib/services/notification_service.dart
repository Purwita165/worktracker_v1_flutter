import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {

  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder',
          'Reminder',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

Future<void> init() async {
  print("INIT 1");

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');

  const settings = InitializationSettings(
    android: android,
  );

  await _plugin.initialize(settings);

  print("INIT 2");
}

Future<void> testNow() async {
  print("TEST NOTIF DIPANGGIL");

  const androidDetails = AndroidNotificationDetails(
    'tes_channel_v2',
    'Tes Channel V2',
    importance: Importance.max,
    priority: Priority.high,
    playSound: true,
    enableVibration: true,
  );

  const details = NotificationDetails(android: androidDetails);

  await _plugin.show(
    999,
    'TEST LANGSUNG',
    'Kalau ini muncul, notif OK',
    details,
  );
}


}