import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
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
  bool loadScreenshots = false;

  void refresh({bool mini = false}) {
    setState(() {});
  }

  Future<Map?> getData({required Map item}) async {
    print("getting cloud data...");
    Map? cloud = prevData ?? await getCloud(item);

    if (cloud == null) {
      return null;
    }

    bool isInstalled = await checkInstalled(item["id"]);
    Map data = {
      "isInstalled": isInstalled,
      "data": cloud,
      "installedVer": getInstalledVer(item),
    };

    prevData = cloud;
    return data;
  }

  Future<void> install({required int mode, required Map data, required Map item}) async {
    String env() {
      switch (Environment.get()) {
        case EnvironmentType.web:
          return 'web';
        case EnvironmentType.android:
          return 'android';
        case EnvironmentType.ios:
          return 'ios';
        case EnvironmentType.linux:
          return 'linux';
        case EnvironmentType.macos:
          return 'macos';
        case EnvironmentType.windows:
          return 'windows';
        default:
          return "fuchsia";
      }
    }

    print("installing for: ${Environment.get()}");
    Map response = await installAction(item: item, version: data["version"], mode: mode, path: getPath(item["id"]), url: item["releases"][0][env()]["url"]);
    if (response["success"] == false) {
      String e = response["error"];
      print("error (${e.runtimeType}): $e");
      showDialogue(context: context, title: "Whoops!", content: Text("There was an error installing this app: $e"), copy: true, copyText: e);
    } else {
      showSnackBar(context, "App installed!");
    }
  }

  Future<void> start(Map item) async {
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
    Map item = widget.item;
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(item["name"]),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  width: 96,
                  height: 96,
                  child: ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    child: Image.network(
                      item["icon"],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1) : null));
                      },
                      errorBuilder: (context, e, stackTrace) {
                        error("icon load error: $e\n$stackTrace", trace: false);
                        return Text('Failed to load image');
                      },
                    ),
                  ),
                ),
              ),
              Text("${item["name"]} V. ${item["version"]}${item["beta"] ? " Beta" : ""}", style: TextStyle(fontSize: 24)),
              if (item["website"] != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 30,
                    icon: Icon(Icons.public),
                    color: Colors.blue,
                    onPressed: () {
                      openUrlConf(context, Uri.parse(item["website"]));
                    },
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: Icon(Icons.person),
                    color: Colors.blue,
                    onPressed: () {
                      openUrlConf(context, Uri.parse(item["support"]));
                    },
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: SvgPicture.asset(
                      'assets/icons/github.svg',
                      colorFilter: ColorFilter.mode(Colors.blue, BlendMode.srcIn),
                      width: 27,
                      height: 27,
                    ),
                    color: Colors.blue,
                    onPressed: () {
                      openUrlConf(context, Uri.parse(item["github"]));
                    },
                  ),
                  IconButton(
                    iconSize: 30,
                    icon: Icon(Icons.share),
                    color: Colors.blue,
                    onPressed: () {
                      sharePlainText(content: item["website"], subject: "${item["name"]} by ${item["author"]["name"]}");
                    },
                  ),
                ],
              ),
              Text("${item["author"]["name"]}"),
              Text(item["summary"], style: TextStyle(fontSize: 14)),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: installerButton(item: item),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      List generateList(String key, {required IconData icon}) {
                        return List.generate(item[key].length, (int index) {
                          String capitalizeFirstLetter(String text) {
                            if (text.isEmpty) return text;
                            return text[0].toUpperCase() + text.substring(1);
                          }
                      
                          return ListTile(
                            leading: Icon(icon, size: 24),
                            title: Text(capitalizeFirstLetter(item[key][index]), style: TextStyle(fontSize: 14)),
                          );
                        });
                      }
          
                      return ExpansionTile(title: Text("About"), expandedCrossAxisAlignment: CrossAxisAlignment.center, children: [
                        Text(item["description"], textAlign: TextAlign.start),
                        ...generateList("categories", icon: Icons.folder),
                        ...generateList("tags", icon: Icons.tag),
                      ]);
                    }
                  ),
                  if (item["platforms"] != null)
                  Column(
                    children: [
                      Builder(
                        builder: (context) {
                          List platforms = item["platforms"];
                          List environments = [];
          
                          String getVersionString(String platform) {
                            print(item["releases"][0]);
                            Map release = item["releases"][0][platform];
                            return "${release["minimum"]}${release["maximum"] != null ? "-" : "+"}${release["maximum"] ?? ""}";
                          }
          
                          String format(String platform) {
                            switch (platform) {
                              case 'ios':
                                return 'iOS ${getVersionString("ios")}';
                              case 'android':
                                return 'Android ${getVersionString("android")}';
                              case 'win-x64':
                                return 'Windows ${getVersionString("windows")} x64';
                              case 'win-arm64':
                                return 'Windows ${getVersionString("windows")} ARM';
                              case 'linux-x64':
                                return 'Linux ${getVersionString("linux")} x64';
                              case 'darwin-arm64':
                                return 'macOS ${getVersionString("macos")} Apple Silicon';
                              case 'web':
                                return 'Web: ${item["releases"][0][platform]["url"]}';
                              default:
                                return 'Fuchsia';
                            }
                          }
          
                          for (String platform in platforms) {
                            environments.add(format(platform));
                          }
          
                          return ExpansionTile(title: Text("Supported Platforms"), expandedCrossAxisAlignment: CrossAxisAlignment.start, children: List.generate(environments.length, (int index) {
                            return Text(environments[index]);
                          }));
                        }
                      ),
                    ],
                  ),
                  ExpansionTile(title: Text("Permissions"), children: [
                    ...List.generate(item["permissions"].length, (int index) {
                      Map permission = item["permissions"][index];
                      return ListTile(
                        leading: Icon(Icons.lock),
                        title: Text(permission["title"]),
                        subtitle: Text(permission["description"]),
                      );
                    }),
                  ]),
                  ExpansionTile(title: Text("Version History"), children: [
                    ...List.generate(item["releases"].length, (int index) {
                      Map release = item["releases"][index];
                      bool current = index == 0;
                      return ExpansionTile(title: Text("${release["version"]}${current ? " (Current)" : ""} - ${DateFormat("M/dd/yyyy h:mm a").format(DateTime.parse(release["date"]).toLocal())}"), initiallyExpanded: current, children: [
                        Text("Changelog", style: TextStyle(fontSize: 24)),
                        ...List.generate(release["changelog"].length, (int index) {
                          Map change = release["changelog"][index];
                          return Text("- ${change["text"]}");
                        }),
                      ], expandedCrossAxisAlignment: CrossAxisAlignment.start);
                    }),
                  ]),
                  loadScreenshots ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...List.generate(item["screenshots"].length, (int index) {
                          Map screenshot = item["screenshots"][index];
                          Widget image = Image.network(
                            screenshot["url"],
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              } else {
                                return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? (loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 0)) : null));
                              }
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Center(child: Icon(Icons.error));
                            },
                          );

                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              width: 196,
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(Radius.circular(12)),
                                child: InkWell(
                                  child: image,
                                  onTap: () {
                                    showDialogue(context: context, title: screenshot["title"], content: Container(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.all(Radius.circular(12)),
                                        child: image,
                                      ),
                                    ), fullscreen: true);
                                  },
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ) : TextButton(onPressed: () {
                    loadScreenshots = true;
                    refresh();
                  }, child: Text("Load Screenshots")),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map?> getCloud(item) async {
    print("getting cloud data...");
    refresh(mini: true);
    List data = (await getServerData(endpoint: 'catalog/query?type=application', method: 'GET'))["catalog"];
    return data.firstWhere((element) => element["id"] == item["id"]);
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
        HttpClient client = HttpClient();
        client.connectionTimeout = Duration(hours: 3);

        HttpClientRequest request = await client.getUrl(Uri.parse(url));
        HttpClientResponse response = await request.close();
        print('response fetched: ${response.runtimeType}');
        updateLoading(50);

        Uint8List bytes = await consolidateHttpClientResponseBytes(response);
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

  Widget installerButton({required Map item}) {
    return Column(
      children: [
        if (loading)
        CircularProgressIndicator(value: loadingPercent < 0 || loadingPercent >= 100 ? null : loadingPercent / 100),
        FutureBuilder(future: getData(item: item), builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError || snapshot.data == null) {
            error("snapshot error: ${snapshot.error}:\n${snapshot.stackTrace}");
            return TextButton(onPressed: () async {
              start(item);
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
                                      start(item);
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(update ? Icons.download : Icons.refresh),
                                    title: Text(update ? "Update" : "Check for Updates"),
                                    onTap: () async {
                                      Navigator.pop(context);
                                      if (update) {
                                        install(mode: 2, data: data, item: item);
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
                                      if (await showConfirmDialogue(context: context, title: "Are you sure?", description: "Are you sure you want to uninstall ${item["name"]}? This will delete all saved data.\n\nPlease note: This may not delete all data. If not all data is deleted, then you will need to do that in the app.") ?? false) {
                                        Map response = await installAction(path: getPath(item["id"]), item: item, version: data["version"], mode: 3);
                                        if (response["success"] == false) {
                                          String e = response["error"];
                                          print("error (${e.runtimeType}): $e");
                                          showDialogue(context: context, title: "Whoops!", content: Text("There was an error uninstalling ${item["name"]}: $e"), copy: true, copyText: e);
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
                        String path = getPath(item["id"]);
                        if (await showConfirmDialogue(context: context, title: "Install ${item["name"]}?", description: "This will install ${item["name"]} to $path.") ?? false) {
                          install(mode: 1, data: data, item: item);
                        }
                      }
                    }, child: Text(isInstalled ? "Installed" : "Install")),
                    if (isInstalled)
                    TextButton(onPressed: () async {
                      start(item);
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
      ],
    );
  }
}