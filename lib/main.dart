import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'pages/todo_page.dart';
import 'services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print("STEP 1");

  tzdata.initializeTimeZones();

  print("STEP 2");

  NotificationService().init(); // TANPA await

  print("STEP 3");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
  

    return MaterialApp(
      /*
      Menghilangkan tulisan DEBUG di pojok kanan atas
      */
      debugShowCheckedModeBanner: false,


      title: 'WorkTracker_v1',

        home: const TodoPage(),
    );
  }
}
