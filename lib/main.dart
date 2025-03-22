import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:launcher/home.dart';
import 'package:launcher/library.dart';
import 'package:launcher/settings.dart';
import 'package:localpkg/error.dart';
import 'package:localpkg/logger.dart';
import 'package:localpkg/theme.dart';
import 'package:quick_navbar/quick_navbar.dart';
import 'package:system_info2/system_info2.dart';

void main(List<String> arguments) {
  (() async {
    print("PLATFORM: ${await getCurrentPlatform()}");
  })();

  if (!Environment.isDesktop && !Environment.isAndroid) {
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

Future<String> getCurrentPlatform() async {
  final String arch = SysInfo.kernelArchitecture == ProcessorArchitecture.x86_64 ? "x64" : "arm64";

  if (kIsWeb) {
    return 'web';
  }

  if (Platform.isAndroid) {
    return 'android';
  }

  if (Platform.isIOS) {
    return 'ios';
  }

  if (Platform.isMacOS) {
    final deviceInfo = DeviceInfoPlugin();
    final macInfo = await deviceInfo.macOsInfo;
    return macInfo.arch == "x86_64" ? "darwin-x64" : 'darwin-arm64';
  }

  if (Platform.isLinux) {
    return 'linux-$arch';
  }

  if (Platform.isWindows) {
    return 'win-$arch';
  }

  return 'unknown';
}