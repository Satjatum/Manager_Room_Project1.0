import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_models.dart';

/// AuthService - Supabase Auth Integration
///
/// Features:
/// - Email/Username login via Supabase Auth
/// - Auto-generate password for admin-created users
/// - Session management via Supabase Auth
/// - No custom lockout system (relies on Supabase)
class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // Initialize Session
  // ============================================

  /// Initialize session on app start
  /// Check if there's an existing Supabase Auth session
  static Future<void> initializeSession() async {
    try {
      // Supabase Auth automatically manages session persistence
      // No manual initialization needed
      debugPrint('Auth session initialized');
    } catch (e) {
      debugPrint('Error initializing session: $e');
    }
  }

  // ============================================
  // Sign In with Email or Username
  // ============================================

  /// Sign in with email or username + password
  /// Supports both email and username login
  static Future<Map<String, dynamic>> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      String? email;

      // Check if input is email (contains @)
      if (emailOrUsername.contains('@')) {
        email = emailOrUsername.trim();
      } else {
        // Convert username to email via database function
        email = await _getUsernameToEmail(emailOrUsername.trim());

        if (email == null) {
          return {
            'success': false,
            'message': 'ไม่พบผู้ใช้งานนี้ในระบบ',
          };
        }
      }

      // Sign in with Supabase Auth
      final authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'message': 'เข้าสู่ระบบไม่สำเร็จ',
        };
      }

      // Get user data from public.users
      final userData = await _getUserWithInfo(authResponse.user!.id);

      if (userData == null) {
        // User not found in public.users (should not happen with trigger)
        await _supabase.auth.signOut();
        return {
          'success': false,
          'message': 'ไม่พบข้อมูลผู้ใช้ในระบบ',
        };
      }

      // Check if user is active
      if (userData['is_active'] != true) {
        await _supabase.auth.signOut();
        return {
          'success': false,
          'message': 'บัญชีของคุณถูกปิดการใช้งาน',
        };
      }

      final user = UserModel.fromDatabase(userData);

      return {
        'success': true,
        'user': user,
        'message': 'เข้าสู่ระบบสำเร็จ',
      };
    } on AuthException catch (e) {
      // Handle Supabase Auth errors
      String message = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';

      if (e.message.contains('Invalid login credentials')) {
        message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      } else if (e.message.contains('Email not confirmed')) {
        message = 'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ';
      } else if (e.message.contains('Too many requests')) {
        message = 'พยายามเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      debugPrint('Login error: $e');
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // ============================================
  // Sign Out
  // ============================================

  /// Sign out current user
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error during sign out: $e');
    }
  }

  // ============================================
  // Get Current User
  // ============================================

  /// Get current authenticated user
  static Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;

      if (authUser == null) {
        debugPrint('⚠️ No authenticated user found');
        return null;
      }

      debugPrint('✅ Auth User ID: ${authUser.id}');
      final userData = await _getUserWithInfo(authUser.id);

      if (userData == null) {
        debugPrint('⚠️ User data not found in database');
        return null;
      }

      debugPrint(
          '✅ User data: ${userData['user_name']} - Role: ${userData['role']}');

      if (userData['is_active'] != true) {
        debugPrint('⚠️ User is not active');
        return null;
      }

      final userModel = UserModel.fromDatabase(userData);
      debugPrint(
          '✅ UserModel created: ${userModel.userName} - ${userModel.userRole}');

      return userModel;
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  // ============================================
  // Check Authentication
  // ============================================

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) return false;

      // Check if user exists and is active
      final user = await getCurrentUser();
      return user != null;
    } catch (e) {
      debugPrint('Error checking authentication: $e');
      return false;
    }
  }

  // ============================================
  // Password Management
  // ============================================

  /// Update password (for logged-in user)
  static Future<Map<String, dynamic>> updatePassword({
    required String newPassword,
  }) async {
    try {
      final authUser = _supabase.auth.currentUser;

      if (authUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      return {
        'success': true,
        'message': 'เปลี่ยนรหัสผ่านสำเร็จ',
      };
    } on AuthException catch (e) {
      String message = 'เกิดข้อผิดพลาดในการเปลี่ยนรหัสผ่าน';

      if (e.message.contains('Password should be at least')) {
        message = 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร และมีตัวพิมพ์เล็กและใหญ่';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  /// Send password reset email
  static Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      // For Web: redirect to current origin + /reset-password
      // For Mobile: use deep link manager-room://reset-password
      final redirectUrl = Uri.base.origin.contains('localhost') || 
                          Uri.base.origin.contains('http')
          ? '${Uri.base.origin}/reset-password' // Web URL
          : 'manager-room://reset-password'; // Deep Link for Mobile

      debugPrint('🔗 Reset password redirect URL: $redirectUrl');

      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectUrl,
      );

      return {
        'success': true,
        'message': 'ส่งอีเมลรีเซ็ตรหัสผ่านแล้ว กรุณาตรวจสอบอีเมลของคุณ',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // ============================================
  // Helper Functions
  // ============================================

  /// Convert username to email using database function
  static Future<String?> _getUsernameToEmail(String username) async {
    try {
      final result = await _supabase.rpc(
        'get_email_from_username',
        params: {'p_username': username},
      );
      return result as String?;
    } catch (e) {
      debugPrint('Error converting username to email: $e');
      return null;
    }
  }

  /// Get user data with additional info from public.users
  static Future<Map<String, dynamic>?> _getUserWithInfo(String authUid) async {
    try {
      final userResponse = await _supabase
          .from('users')
          .select('*')
          .eq('auth_uid', authUid)
          .maybeSingle();

      if (userResponse == null) {
        return null;
      }

      // If user is tenant, get tenant info
      if (userResponse['role'] == 'tenant') {
        try {
          final tenantResponse = await _supabase
              .from('tenants')
              .select('*')
              .eq('user_id', userResponse['user_id'])
              .eq('is_active', true)
              .maybeSingle();

          if (tenantResponse != null) {
            return {
              ...userResponse,
              'tenant_info': tenantResponse,
            };
          }
        } catch (e) {
          debugPrint('Error getting tenant info: $e');
        }
      }

      return userResponse;
    } catch (e) {
      debugPrint('Error getting user info: $e');
      return null;
    }
  }

  // ============================================
  // Auth State Stream
  // ============================================

  /// Listen to auth state changes
  static Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
