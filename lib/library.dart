import 'package:flutter/material.dart';
import 'package:launcher/main.dart';
import 'package:launcher/view.dart';
import 'package:localpkg/functions.dart';
import 'package:localpkg/online.dart';
import 'package:localpkg/logger.dart';

class Library extends StatefulWidget {
  const Library({super.key});

  @override
  State<Library> createState() => _LibraryState();
}

class _LibraryState extends State<Library> {
  List? prevData;

  @override
  void initState() {
    super.initState();
  }

  Future<List?> getData() async {
    print("getting data...");
    if (prevData != null) {
      return prevData;
    }
  
    Map data = await getServerData(endpoint: "catalog/query?type=application", method: 'GET');
    List apps = data["catalog"];
    List catalog = [];
  
    for (Map app in apps) {
      String name = app["id"];
      String environment = await getCurrentPlatform();
      List platforms = app["platforms"] ?? [];
      bool supported = platforms.contains(environment);
      print("app $name status: $supported (environment: $environment)");
      if (supported) {
        catalog.add(app);
      }
    }
  
    prevData = catalog;
    return catalog;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Installed"),
      ),
      body: Center(
        child: FutureBuilder(future: getData(), builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasData && !snapshot.data.isEmpty && !snapshot.hasError) {
            List data = snapshot.data!;
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                Map item = data[index];
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(30, 143, 50, 50),
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    child: ListTile(
                      title: Text("${item["name"]} V. ${item["version"]}${item["beta"] ? " Beta" : ""}"),
                      subtitle: Text("${item["summary"]}"),
                      onTap: () {
                        navigate(context: context, page: ViewPage(item: item));
                      },
                    ),
                  ),
                );
              },
            );
          } else {
            String snapshotError = "${snapshot.error ?? "no data"}";
            bool noData = snapshotError.toLowerCase() == "no data";
            print("received data: $noData");

            if (noData) {
              warn("snapshot error: $snapshotError");
            } else {
              error("snapshot error: $snapshotError");
            }

            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(noData ? Icons.question_mark_rounded : Icons.warning_amber_rounded, size: 106, color: noData ? Colors.white : Colors.amber),
                  Text(noData ? 'Sorry, it looks like there\'s nothing available for your platform.' : 'Unable to retrieve the app library. Are you connected to the Internet?'),
                ],
              )),
            );
          }
        }),
      )
    );
  }
}