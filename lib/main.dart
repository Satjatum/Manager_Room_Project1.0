import 'package:flutter/material.dart';
import 'package:manager_room_project/views/splash_ui.dart';
// import 'config/superbase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hhbqmrtpvqdmkscagkqi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoYnFtcnRwdnFkbWtzY2Fna3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MjAwODIsImV4cCI6MjA3MTI5NjA4Mn0.nfWJ3MCf5PyVw-Bf4ztauSS9vCD7UViVLZmAg6ilkHc',
  );

  runApp(const ManagerRoomProject());
}

class ManagerRoomProject extends StatelessWidget {
  const ManagerRoomProject({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ระบบจัดการห้องเช่า',
      theme: ThemeData(),
      home: SplashUi(),
      debugShowCheckedModeBanner: false,
    );
  }
}
