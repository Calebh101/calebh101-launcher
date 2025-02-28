import 'dart:convert';
import 'dart:io';
import 'package:flutter_environments_plus/flutter_environments_plus.dart';
import 'package:localpkg/error.dart';
import 'package:localpkg/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

String divider = Environment.isWindows ? "\\" : "/";
Map processes = {};

String getExtension(String type) {
  switch (type) {
    case 'app':
      if (Environment.isWindows) {
        return 'exe';
      } else if (Environment.isMacos) {
        return 'app';
      } else if (Environment.isLinux) {
        return 'app';
      } else {
        throw ManualError("Invalid environment");
      }
    default:
      throw ManualError('Unknown extension type: $type');
  }
}

String getPath(String name) {
  if (Environment.isLinux) {
    return "/etc/calebh101/$name";
  } else if (Environment.isWindows) {
    return "C:\\Program Files\\Calebh101\\$name";
  } else if (Environment.isMacos) {
    return "/usr/local/calebh101/$name";
  } else {
    throw ManualError("Invalid environment");
  }
}

Future<bool> checkInstalled(String name) async {
  print("checking if $name is installed...");
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? data = prefs.getString("installed");
  List json = data != null ? jsonDecode(data) : [];
  for (Map map in json) {
    print("scanning map...");
    if (map.containsKey("name")) {
      if (map["name"] == name) {
        print("map matched name: $name");
        if (map["path"] != null && await getExec(name: name, path: map["path"]) != null) {
          return true;
        }
      }
    }
  }
  return false;
}

Future<String?> getExec({required String name, required String path}) async {
  List exec = ["program.${getExtension('app')}", "program", "app.${getExtension('app')}", "app", "$name.${getExtension('app')}", name];
  for (String file in exec) {
    String pathS = "$path/$file";
    print("scanning $name in $pathS...");
    if (await File(pathS).exists()) {
      print("success: $file found in $path for $name");
      return file;
    }
  }
  return null;
}

Future<Map?> getConfig(Map item) async {
  String name = item["id"];
  String? path = item['path'] ?? getPath(name);
  print("getting config for $name ($path)...");
  if (await checkInstalled(name) && path != null) {
    String pathS = "$path/config.json";
    print("getting config at $pathS for $name...");
    try {
      final file = File(pathS);
      String contents = await file.readAsString();
      Map data = json.decode(contents);
      print("config: $data");
      return data;
    } catch (e) {
      print("config: error reading $path: $e");
      return null;
    }
  } else {
    return null;
  }
}

Future<String?> getInstalledVer(Map item) async {
  print("getting installed version of ${item["id"]}...");
  Map? config = await getConfig(item);
  if (config != null) {
    String version = config["version"];
    print("config returned version: $version");
    return version;
  } else {
    print("config returned null");
    return null;
  }
}

Future<Map> runProcess(String command, {List<String>? args}) async {
  args ??= [];
  String cmd = "$command ${args.join(' ')}";
  print("running process: $cmd");
  Process process = await Process.start(command, args);
  return {"process": process, "command": cmd};
}

Future<Map> playApp({required String name, required String path}) async {
  String? command;
  List commands = [];
  String file = '$path/${await getExec(name: name, path: path)}';
  List<String> args = ['--launcher=true'];
  FileStat stat = await FileStat.stat(file);

  Map end(bool success, {Object? error}) {
    Map response = {"success": success, 'file': file, 'commands': commands};
    if (success == false && error != null) {
      response["error"] = error;
    }
    if (command != null) {
      response["command"] = command;
    }
    return response;
  }

  if (stat.mode & 0x49 != 0) {
    print("executable: $file");
  } else {
    print("not executable: $file");
    commands.add((await runProcess('chmod', args: ['+x', file]))["command"]);
  }

  try {
    Map response = await runProcess(file, args: args);
    command = response["command"];
    commands.add(command);
    processes[name] = response["process"];
    return end(true);
  } catch (e) {
    print("playApp($path) error: $e");
    return end(false, error: e);
  }
}