import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:launcher/util.dart';
import 'package:launcher/view.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/functions.dart';
import 'package:localpkg/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool loading = false;

  @override
  void initState() {
    super.initState();
  }

  void refresh({bool mini = false}) {
    print("refreshing...");
    setState(() {});
  }

  Future<List> getData() async {
    print("getting data...");
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? data = prefs.getString("installed");
    List installed = data != null ? jsonDecode(data) : [];
    List apps = [];
    for (var app in installed) {
      app["id"] ??= "${app["name"]}";
      if (await checkInstalled(app["id"])) {
        print("app ${app["id"]} is installed");
        apps.add(app);
      }
    }
    return apps;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Installed"),
        leading: loading ? CircularProgressIndicator() : null,
      ),
      body: Center(
        child: FutureBuilder(future: getData(), builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (snapshot.hasData) {
            List data = snapshot.data!;
            if (data.isEmpty) {
              return Text("Head over to the catalog to install some apps!");
            }
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: data.length,
              itemBuilder: (context, index) {
                Map item = data[index];
                item["id"] ??= "${item["name"]}";
                return Padding(
                  key: Key("installed($index)"),
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(30, 143, 50, 50),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: ListTile(
                      key: Key("installed($index)"),
                      title: Text("${item["name"]}"),
                      subtitle: Text("Version: ${item["version"]}"),
                      onTap: () {
                        item["url"] = {};
                        navigate(context: context, page: ViewPage(item: item));
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.play_arrow_rounded),
                            onPressed: () async {
                              if (loading == true) {
                                print("session already going");
                              }

                              loading = true;
                              refresh(mini: true);

                              String path = getPath(item["id"]);
                              Map result = await playApp(name: item["id"], path: path);

                              if (result["success"] == false) {
                                Object e = result["error"];
                                print("error (${e.runtimeType}): $e");
                                showDialogue(context: context, title: "Whoops!", content: Text("There was an error launching this app: $e"));
                              }

                              loading = false;
                              refresh(mini: true);
                            },
                          ),
                          ReorderableDragStartListener(
                            index: index,
                            child: Icon(Icons.drag_handle),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                SharedPreferences prefs = await SharedPreferences.getInstance();
                String? data = prefs.getString("installed");
                List items = data != null ? jsonDecode(data) : [];
                if (newIndex > oldIndex) newIndex--;
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                prefs.setString('installed', jsonEncode(items));
                print("saved");
                refresh();
              },
            );
          } else {
            return Text('Error: no data');
          }
        }),
      )
    );
  }
}