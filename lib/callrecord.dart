import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';


class CallRecordingsScreen extends StatefulWidget {
  @override
  _CallRecordingsScreenState createState() => _CallRecordingsScreenState();
}

class _CallRecordingsScreenState extends State<CallRecordingsScreen> {
  List<File> callRecordings = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // await _requestPermissions();
    await _fetchRecordings();
  }

  Future<void> _requestPermissions() async {
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Storage permission is required to fetch recordings.")),
      );
    }
  }

  Future<void> _fetchRecordings() async {
    // Replace with the directory where recordings are stored
    Directory directory = Directory("/storage/emulated/0/CallRecordings/");

    if (await directory.exists()) {
      List<FileSystemEntity> files = directory.listSync();
      List<File> audioFiles = files
          .where((file) => file is File && (file.path.endsWith(".mp3") || file.path.endsWith(".wav")))
          .cast<File>()
          .toList();

      setState(() {
        callRecordings = audioFiles;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No recordings directory found.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Call Recordings")),
      body: callRecordings.isEmpty
          ? Center(child: Text("No recordings found"))
          : ListView.builder(
        itemCount: callRecordings.length,
        itemBuilder: (context, index) {
          File file = callRecordings[index];
          return ListTile(
            leading: Icon(Icons.audiotrack),
            title: Text(file.path.split('/').last),
            subtitle: Text("Path: ${file.path}"),
            onTap: () {
              _playRecording(file);
            },
          );
        },
      ),
    );
  }

  void _playRecording(File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Play functionality can be added here for: ${file.path}")),
    );
    // Use audio player
  }
}
