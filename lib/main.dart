import 'package:flutter/material.dart';
import 'package:manager_room_project/views/reset_password_ui.dart';
import 'package:manager_room_project/views/splash_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

final navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hhbqmrtpvqdmkscagkqi.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhoYnFtcnRwdnFkbWtzY2Fna3FpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU3MjAwODIsImV4cCI6MjA3MTI5NjA4Mn0.nfWJ3MCf5PyVw-Bf4ztauSS9vCD7UViVLZmAg6ilkHc',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  runApp(const ManagerRoomProject());
}

class ManagerRoomProject extends StatefulWidget {
  const ManagerRoomProject({super.key});

  @override
  State<ManagerRoomProject> createState() => _ManagerRoomProjectState();
}

class _ManagerRoomProjectState extends State<ManagerRoomProject> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupDeepLinkListener();
  }

  void _setupDeepLinkListener() {
    // Listen for auth state changes (including password recovery)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint('เหตุการณ์การตรวจสอบสิทธิ์: $event');

      // Handle password recovery event
      if (event == AuthChangeEvent.passwordRecovery) {
        debugPrint('ตรวจพบการกู้คืนรหัสผ่าน กำลังนำไปยังหน้ารีเซ็ตรหัสผ่าน');
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const ResetPasswordUi()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ระบบจัดการห้องเช่า',
      theme: ThemeData(
        textTheme: GoogleFonts.kanitTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: SplashUi(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/reset-password': (context) => const ResetPasswordUi(),
      },
    );
  }
}
