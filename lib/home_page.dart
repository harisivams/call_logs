

import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'callrecord.dart';

class CallLogPage extends StatefulWidget {
  @override
  _CallLogPageState createState() => _CallLogPageState();
}

class _CallLogPageState extends State<CallLogPage> {
  List<CallLogEntry> callLogs = [];
  Map<String, String> contactNames = {};
  List<FileSystemEntity> recordings = []; // List to store call recordings
  bool isLoading = true;
  AudioPlayer _audioPlayer = AudioPlayer(); // Audio player instance

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
    });

    // Request permissions
    await _requestPermissions();

    // Load data asynchronously
    await Future.wait([
      _fetchContacts(),
      _fetchCallLogs(),
    ]).then((_) {
      // Lazy load recordings
      _fetchRecordings(lazyLoad: true);
    }).whenComplete(() {
      setState(() {
        isLoading = false;
      });
    }).catchError((error) {
      setState(() {
        isLoading = false;
      });
      print("Error during initialization: $error");
    });
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.contacts,
      Permission.phone,
      Permission.manageExternalStorage,
    ].request();

    if (statuses.values.any((status) => status != PermissionStatus.granted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permissions are required for full functionality.')),
      );
    }
  }


  Future<void> _fetchContacts() async {
    if (await Permission.contacts.isGranted) {
      Iterable<Contact> contacts = await ContactsService.getContacts();
      for (var contact in contacts) {
        for (var phone in contact.phones ?? []) {
          String normalizedNumber = _normalizePhoneNumber(phone.value!);
          contactNames[normalizedNumber] = contact.displayName ?? phone.value!;
        }
      }
    }
  }

  Future<void> _fetchCallLogs() async {
    if (await Permission.phone.isGranted) {
      try {
        Iterable<CallLogEntry> entries = await CallLog.get();
        setState(() {
          callLogs = entries.toList();
        });
      } catch (e) {
        print('Error fetching call logs: $e');
      }
    }
  }

  Future<void> _fetchRecordings({bool lazyLoad = false}) async {
    if (lazyLoad) {
      print("Skipping recording load during initialization.");
      return;
    }

    Directory? directory = await getExternalStorageDirectory();
    String path = directory?.path ?? '';

    try {
      List<FileSystemEntity> files = Directory('$path/CallRecordings').listSync();
      setState(() {
        recordings = files;
      });
    } catch (e) {
      print("Error fetching recordings: $e");
    }
  }

  String _normalizePhoneNumber(String number) {
    number = number.replaceAll(RegExp(r'\D'), '');
    if (number.startsWith('91') && number.length > 10) {
      number = number.substring(2);
    } else if (number.startsWith('1') && number.length > 10) {
      number = number.substring(1);
    }
    return number;
  }

  String _getContactName(String? number) {
    if (number == null) return 'Unknown';
    String normalizedNumber = _normalizePhoneNumber(number);
    return contactNames[normalizedNumber] ?? number;
  }

  void _playRecording(String filePath) async {
    try {
      if (filePath.isNotEmpty) {
        await _audioPlayer.play(UrlSource(filePath));
        print("Playing successfully");
      } else {
        print("No valid recording found.");
      }
    } catch (e) {
      print("Error playing: $e");
    }
  }

  String _formatDuration(int? durationInSeconds) {
    if (durationInSeconds == null || durationInSeconds <= 0) return "Didn't connect";

    int minutes = durationInSeconds ~/ 60; // Total minutes
    int seconds = durationInSeconds % 60; // Remaining seconds

    if (minutes > 0) {
      return '${minutes}m ${seconds}sec';
    } else {
      return '${seconds}sec';
    }
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return 'Unknown';

    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('hh:mm a').format(date); // Only show the time (e.g., 10:45 AM)
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Call Logs Viewer'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : callLogs.isEmpty
          ? Center(child: Text('No call logs found.'))
          : ListView.builder(
        itemCount: callLogs.length,
        itemBuilder: (context, index) {
          final log = callLogs[index];
          return Card(
            margin: const EdgeInsets.all(1.0),
            child: ListTile(
              leading: Icon(
                _getCallTypeIcon(log.callType),
                color: _getCallTypeColor(log.callType),
                size: 30,
              ),
              title: Text(_getContactName(log.number)),
              subtitle: Text(
                'Duration: ${_formatDuration(log.duration)} \nDate: ${DateFormat('yyyy-MM-dd').format(DateTime.fromMillisecondsSinceEpoch(log.timestamp ?? 0))} '
                    'Time: ${_formatTime(log.timestamp)}',
              ),
              trailing: Text(
                _getCallTypeText(log.callType),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _getCallTypeColor(log.callType),
                ),
              ),
              onTap: () {
                _showCallRecords(log.number);
              },
            ),
          );
        },
      ),
    );
  }

  void _showCallRecords(String? phoneNumber) {
    List<CallLogEntry> filteredLogs =
    callLogs.where((log) => log.number == phoneNumber).toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallRecordingsScreen(
        ),
      ),
    );
  }

  String _getCallTypeText(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return 'Incoming';
      case CallType.outgoing:
        return 'Outgoing';
      case CallType.missed:
        return 'Missed';
      case CallType.blocked:
        return 'Blocked';
      default:
        return 'Unknown';
    }
  }

  IconData _getCallTypeIcon(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return Icons.call_received;
      case CallType.outgoing:
        return Icons.call_made;
      case CallType.missed:
        return Icons.call_missed;
      case CallType.blocked:
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  Color _getCallTypeColor(CallType? type) {
    switch (type) {
      case CallType.incoming:
        return Colors.green;
      case CallType.outgoing:
        return Colors.blue;
      case CallType.missed:
        return Colors.red;
      case CallType.blocked:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
