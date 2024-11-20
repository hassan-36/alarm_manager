import 'dart:async'; // For Timer
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:ui'; // For platform detection
import 'dart:html' as html;  // For Web audio playback
import 'package:flutter/foundation.dart'; // For platform detection
import 'package:intl/intl.dart'; // For formatting time

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local notifications for Android
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('app_icon'); // Ensure 'app_icon' exists in res/drawable folder.

  final InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Initialize AlarmManager only on Android
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await AndroidAlarmManager.initialize();
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove the debug banner
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      home: AlarmHomePage(),
    );
  }
}

class AlarmHomePage extends StatefulWidget {
  @override
  _AlarmHomePageState createState() => _AlarmHomePageState();
}

class _AlarmHomePageState extends State<AlarmHomePage> {
  TimeOfDay selectedTime = TimeOfDay.now();
  DateTime? alarmTime;

  // Timer for current time and remaining time
  late Timer _timer;
  String currentTime = ''; // To store the formatted current time
  String remainingTime = ''; // To store the remaining time until alarm

  @override
  void initState() {
    super.initState();
    // Set up a timer to update the clock every second
    _updateClock();
  }

  // Update the clock every second
  void _updateClock() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) {
      setState(() {
        currentTime = DateFormat('HH:mm:ss').format(DateTime.now());

        if (alarmTime != null) {
          remainingTime = _calculateRemainingTime(alarmTime!);
        }
      });
    });
  }

  // Dispose the timer when the widget is disposed
  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  // Android Alarm using AlarmManager
  void _setAndroidAlarm() async {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (scheduledTime.isBefore(now)) {
      print("Cannot set alarm for a past time.");
      return;
    }

    await AndroidAlarmManager.oneShotAt(
      scheduledTime,
      0, // Alarm ID
      _alarmCallback, // Callback function to execute when the alarm triggers
      exact: true,
      wakeup: true,
    );

    setState(() {
      alarmTime = scheduledTime;
    });

    print("Android alarm set for: $scheduledTime");
  }

  // Callback for AlarmManager
  static void _alarmCallback() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      'Alarm Notifications',
      channelDescription: 'This channel is used for alarm notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      'Alarm',
      'Time to Wake Up!',
      platformDetails,
    );
  }

  // Web Alarm using Modal and Sound
  void _setWebAlarm() {
    final now = DateTime.now();
    final scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    if (scheduledTime.isBefore(now)) {
      print("Cannot set alarm for a past time.");
      return;
    }

    Future.delayed(
      scheduledTime.difference(now),
          () {
        _showWebAlarmModal(context);
        _playWebAlarmSound();  // Play sound when alarm triggers
      },
    );

    setState(() {
      alarmTime = scheduledTime;
    });

    print("Web alarm set for: $scheduledTime");
  }

  // Modal Display Function
  void _showWebAlarmModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alarm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          content: Text('Time to Wake Up!', style: TextStyle(fontSize: 20)),
          actions: [
            TextButton(
              onPressed: () {
                // Dismiss the dialog and clear the alarm and remaining time
                Navigator.of(context).pop();
                setState(() {
                  alarmTime = null; // Reset the alarm time
                  remainingTime = ''; // Clear the remaining time
                });
              },
              child: Text('OK', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }


  // Web Sound Playback
  void _playWebAlarmSound() {
    final audio = html.AudioElement('assets/alarm_ringtone.mp3'); // Ensure you have this file in your assets
    audio.play();
  }

  // Common Alarm Setter
  void _setAlarm() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _setAndroidAlarm();
    } else {
      _setWebAlarm();
    }
  }

  // Format time to hh:mm:ss
  String formatTime(DateTime time) {
    return DateFormat('HH:mm:ss').format(time);
  }

  // Calculate remaining time and format it to hh:mm:ss
  String _calculateRemainingTime(DateTime targetTime) {
    final now = DateTime.now();
    final difference = targetTime.difference(now);
    final hours = difference.inHours;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Alarm App', style: TextStyle(fontSize: 24)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Clock Display with formatted time
            Text(
              'Current Time: $currentTime',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),

            // Alarm Time Selection
            Text(
              "Set Alarm Time",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListTile(
              title: Text(
                "${selectedTime.format(context)}",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              trailing: Icon(Icons.access_time, size: 30),
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                );
                if (picked != null && picked != selectedTime) {
                  setState(() {
                    selectedTime = picked;
                  });
                }
              },
            ),
            SizedBox(height: 32),

            // Set Alarm Button with updated styles
            ElevatedButton(
              onPressed: _setAlarm,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                textStyle: TextStyle(fontSize: 20),
                backgroundColor: Colors.black, // Black background color
                foregroundColor: Colors.white, // White text color
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // Rounded corners
                ),
                minimumSize: Size(double.infinity, 60), // Full width and taller height
              ),
              child: Text("Set Alarm", style: TextStyle(fontSize: 20)),
            ),
            SizedBox(height: 32),

            // Time remaining for alarm with formatted remaining time
            if (alarmTime != null)
              Text(
                "Time remaining for alarm: $remainingTime",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
    );
  }
}
