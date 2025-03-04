import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:launcher/util.dart';
import 'package:localpkg/dialogue.dart';
import 'package:localpkg/functions.dart';
import 'package:localpkg/online.dart';
import 'package:localpkg/logger.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViewPage extends StatefulWidget {
  final Map item;

  const ViewPage({
    super.key,
    required this.item,
  });

  @override
  State<ViewPage> createState() => _ViewPageState();
}

class _ViewPageState extends State<ViewPage> {
  Map? prevData;
  bool loading = false;
  int loadingPercent = 0;

  void refresh({bool mini = false}) {
    setState(() {});
  }

  Future<Map?> getData() async {
    print("getting cloud data...");
    Map? cloud = prevData ?? await getCloud();

    if (cloud == null) {
      return null;
    }

    bool isInstalled = await checkInstalled(widget.item["id"]);
    Map data = {
      "isInstalled": isInstalled,
      "data": cloud,
      "installedVer": getInstalledVer(widget.item),
    };

    prevData = cloud;
    return data;
  }

  Future<void> install({required int mode, required Map data}) async {
    Map response = await installAction(item: widget.item, version: data["version"], mode: mode, path: getPath(widget.item["id"]), url: widget.item["url"]["${Environment.get()}"]);
    if (response["success"] == false) {
      String e = response["error"];
      print("error (${e.runtimeType}): $e");
      showDialogue(context: context, title: "Whoops!", content: Text("There was an error installing this app: $e"), copy: true, copyText: e);
    } else {
      showSnackBar(context, "App installed!");
    }
  }

  Future<void> start() async {
    if (loading == true) {
      print("session already going");
    }

    loading = true;
    refresh(mini: true);
          
    String path = getPath(widget.item["id"]);
    Map result = await playApp(name: widget.item["id"], path: path);

    if (result["success"] == false) {
      Object e = result["error"];
      print("error (${e.runtimeType}): $e");
      showDialogue(context: context, title: "Whoops!", content: Text("There was an error launching this app: $e"));
    }

    loading = false;
    refresh(mini: true);
  }

  void updateLoading(int percent) {
    loadingPercent = percent;
    if (percent < 0 || percent >= 100) {
      loading = false;
    } else {
      loading = true;
    }
    print("loading: $loading:$percent");
    refresh(mini: true);
  }

  @override
  void initState() {
    super.initState();
    print("state initialized");
  }

  @override
  Widget build(BuildContext context) {
    print("building scaffold... (loading: $loading)");
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.item["name"]),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Center(
        child: Column(
          children: [
            Text(widget.item["name"] ?? "null", style: TextStyle(fontSize: 24)),
            if (widget.item["url"]["website"] != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  iconSize: 30,
                  icon: Icon(Icons.public),
                  color: Colors.blue,
                  onPressed: () {
                    openUrlConf(context, Uri.parse(widget.item["url"]["website"]));
                  },
                ),
                IconButton(
                  iconSize: 30,
                  icon: Icon(Icons.share),
                  color: Colors.blue,
                  onPressed: () {
                    sharePlainText(content: widget.item["url"]["website"], subject: "${widget.item["name"]} by Calebh101");
                  },
                ),
              ],
            ),
            if (widget.item["summary"] != null)
            Column(
              children: [
                SizedBox(height: 10),
                Text(widget.item["summary"], style: TextStyle(fontSize: 14)),
              ],
            ),
            if (widget.item["description"] != null)
            Column(
              children: [
                SizedBox(height: 10),
                Text(widget.item["description"], style: TextStyle(fontSize: 16)),
              ],
            ),
            if (widget.item["platforms"] != null)
            Column(
              children: [
                SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    List platforms = widget.item["platforms"];
                    List environments = [];

                    for (String platform in platforms) {
                      environments.add(platform);
                    }

                    String data = environments.join(', ');
                    return Text(data, style: TextStyle(fontSize: 16));
                  }
                ),
              ],
            ),
            SizedBox(height: 10),
            FutureBuilder(future: getData(), builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return CircularProgressIndicator();
              } else if (snapshot.hasError || snapshot.data == null) {
                print("snapshot error: ${snapshot.error}");
                return TextButton(onPressed: () async {
                  start();
                }, child: Text("Start"));
              } else if (snapshot.hasData) {
                bool isInstalled = snapshot.data!["isInstalled"];
                Map data = snapshot.data!["data"];
                String? installedVer = data["installedVer"];
                print("update: comparing ${data["version"]} != $installedVer");
                bool update = isInstalled == false ? false : isNewerVersion(current: installedVer ?? "0.0.0A", latest: data["version"]);
                print("checking installed: $isInstalled ($installedVer)");
                return Column(
                  children: [
                    if (installedVer != null)
                    Text("Installed: $installedVer", style: TextStyle(fontSize: 14)),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(onPressed: () async {
                          if (isInstalled) {
                            showModalBottomSheet(
                              context: context,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                              ),
                              builder: (BuildContext context) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: Icon(Icons.play_arrow_rounded),
                                        title: Text("Start"),
                                        onTap: () {
                                          Navigator.pop(context);
                                          start();
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(update ? Icons.download : Icons.refresh),
                                        title: Text(update ? "Update" : "Check for Updates"),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          if (update) {
                                            install(mode: 2, data: data);
                                          } else {
                                            prevData = null;
                                            refresh();
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.delete),
                                        title: Text("Uninstall"),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          if (await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to uninstall ${widget.item["name"]}? This will delete all saved data.\n\nPlease note: This may not delete all data. If not all data is deleted, then you will need to do that in the app.") ?? false) {
                                            Map response = await installAction(path: getPath(widget.item["id"]), item: widget.item, version: data["version"], mode: 3);
                                            if (response["success"] == false) {
                                              String e = response["error"];
                                              print("error (${e.runtimeType}): $e");
                                              showDialogue(context: context, title: "Whoops!", content: Text("There was an error uninstalling ${widget.item["name"]}: $e"), copy: true, copyText: e);
                                            } else {
                                              showSnackBar(context, "App uninstalled!");
                                            }
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: Icon(Icons.cancel),
                                        title: Text("Cancel"),
                                        onTap: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          } else {
                            String path = getPath(widget.item["id"]);
                            if (await showConfirmDialogue(context: context, title: "Install ${widget.item["name"]}?", description: "This will install ${widget.item["name"]} to $path?") ?? false) {
                              install(mode: 1, data: data);
                            }
                          }
                        }, child: Text(isInstalled ? "Installed" : "Install")),
                        if (isInstalled)
                        TextButton(onPressed: () async {
                          start();
                        }, child: Text("Start")),
                      ],
                    ),
                    if (update)
                    Column(
                      children: [
                        SizedBox(height: 10),
                        Text("Update Available: ${data["version"]}", style: TextStyle(fontSize: 18)),
                      ],
                    ),
                  ],
                );
              } else {
                return Text('Error: no data');
              }
            }),
            SizedBox(height: 20),
            if (loading)
            CircularProgressIndicator(value: loadingPercent < 0 || loadingPercent >= 100 ? null : loadingPercent / 100),
          ],
        ),
      ),
    );
  }

  Future<Map?> getCloud() async {
    print("getting cloud data...");
    refresh(mini: true);
    List data = (await getServerData(endpoint: 'catalog/apps', method: 'GET'))["catalog"];
    return data.firstWhere((element) => element["id"] == widget.item["id"]);
  }

  Future<Map> installAction({required Map item, required int mode, required String path, String url = '', required String version}) async {
    if (loading == true || (loadingPercent > 0 && loadingPercent < 100)) {
      print("session already going");
      return {"success": false, "error": "Already installing"};
    }
    updateLoading(0);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? data = prefs.getString("installed");
      List json = data != null ? jsonDecode(data) : [];
      var directory = Directory(path);
      updateLoading(10);
      if (await directory.exists()) {
        print("directory exists: $directory");
      } else {
        print("creating directory: $directory");
        updateLoading(20);
        await directory.create(recursive: true);
      }
      updateLoading(30);
      if (mode == 1 || mode == 2) {
        print("fetching response from $url...");
        var response = await getWebResponse(url: Uri.parse(url), method: 'GET');
        print('response fetched: ${response.runtimeType}');
        updateLoading(50);

        Uint8List bytes = response.bodyBytes;
        var archive = ZipDecoder().decodeBytes(bytes);

        print("writing files...");
        for (final file in archive) {
          final filePath = '$path/${file.name}';

          if (file.isFile) {
            await File(filePath).parent.create(recursive: true);
            await File(filePath).writeAsBytes(file.content as List<int>);
          } else {
            await Directory(filePath).create(recursive: true);
          }
        }

        if (mode == 1) {
          print("setting prefs...");
          json.add({"name": item["name"], "id": item["id"], 'path': path, 'version': version});
          prefs.setString('installed', jsonEncode(json));
        }

        updateLoading(100);
        return {"success": true};
      } else if (mode == 3) {
        print("deleting directory $directory...");
        json.removeWhere((element) => element["id"] == item["id"]);
        prefs.setString('installed', jsonEncode(json));
        await directory.delete();
        updateLoading(100);
        return {"success": true};
      } else {
        throw Exception('Unknown mode: $mode');
      }
    } catch (e) {
      print("error with installAction: $e");
      updateLoading(-1);
      return {"success": false, "error": "$e"};
    }
  }
}