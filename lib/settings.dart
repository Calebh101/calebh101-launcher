import 'package:flutter/material.dart';
import 'package:launcher/var.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: [
            AboutSettings(context: context, version: version, beta: beta, about: about),
            SettingTitle(title: "Data"),
            Setting(title: "Reset All Data and Settings", desc: "Resets all data and settings for the launcher, not the apps. This will reset your installed apps, so they will have to be reinstalled.", action: () async {
              if (await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to reset all data and settings? This cannot be undone. This will also clear the database of installed programs.") ?? false) {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                prefs.clear();
                showSnackBar(context, "Data and settings cleared!");
              }
            }),
          ],
        ),
      ),
    );
  }
}