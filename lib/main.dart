import 'package:flutter/material.dart';
import 'ui/home_page.dart';
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';



void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(MyApp());
}


class MyApp extends StatelessWidget {
@override
Widget build(BuildContext context) {
return MaterialApp(
debugShowCheckedModeBanner: false,
title: 'دبیرخانه',
theme: ThemeData(fontFamily: 'sans'),
home: HomePage(),
);
}
}