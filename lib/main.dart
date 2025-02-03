import 'package:flutter/material.dart';
import 'package:launcher/home.dart';
import 'package:launcher/library.dart';
import 'package:launcher/settings.dart';
import 'package:localpkg/environment.dart';
import 'package:localpkg/error.dart';
import 'package:localpkg/logger.dart';
import 'package:localpkg/theme.dart';
import 'package:quick_navbar/quick_navbar.dart';

void main(List<String> arguments) {
  if (!Environment.desktop) {
    print("environment not desktop");
    CrashScreen(message: "This device was not detected as a desktop. If this device is a desktop, please contact support.");
  } else {
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calebh101 Launcher',
      theme: brandTheme(seedColor: Colors.red),
      darkTheme: brandTheme(seedColor: Colors.red, darkMode: true),
      home: QuickNavBar(items: [
        QuickNavBarItem(
          label: "Home",
          icon: Icons.home,
          widget: Home(),
        ),
        QuickNavBarItem(
          label: "Catalog",
          icon: Icons.book,
          widget: Library(),
        ),
        QuickNavBarItem(
          label: "Settings",
          icon: Icons.settings,
          widget: Settings(),
        ),
      ]),
    );
  }
}
