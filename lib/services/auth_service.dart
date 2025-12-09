import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/user_models.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _deviceIdKey = 'device_id';
  // Device-wide lockout keys (not per-account)
  static const String _failCountKey = 'login_fail_count';
  static const String _lockUntilKey = 'login_lock_until';
  static const String _lockLevelKey =
      'login_lock_level'; // 0:15m,1:30m,2:60m (cap)

  // Initialize session on app start
  static Future<void> initializeSession() async {
    try {
      final currentSession = _supabase.auth.currentSession;
      if (currentSession != null) {
        final isValid = await validateSession();
        if (!isValid) {
          await signOut();
        }
      }
    } catch (e) {
      debugPrint('Error initializing session: $e');
      await signOut();
    }
  }

  // Sign in with email/username and password
  static Future<Map<String, dynamic>> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      // Check device-wide lockout before any request (server-first, fallback local)
      final lockInfo = await getLockStatus();
      if (lockInfo['locked'] == true) {
        final remaining = lockInfo['remaining'] as Duration?;
        final minutes = (remaining?.inMinutes ?? 0).toString();
        final seconds = (remaining != null)
            ? (remaining.inSeconds % 60).toString().padLeft(2, '0')
            : '00';
        return {
          'success': false,
          'message':
              'คุณล็อคอินผิดครบตามจำนวนแล้ว โปรดลองใหม่ภายหลัง (${minutes}:${seconds})',
        };
      }

      // Query user by email or username to resolve email for Supabase Auth
      final userQuery = await _findActiveUserByEmailOrUsername(emailOrUsername);

      if (userQuery == null) {
        // Always record local fail; also try server update (best-effort)
        await _recordFailedAttempt();
        await _serverUpdateLockout(success: false);
        return {
          'success': false,
          'message': 'ไม่พบผู้ใช้งานนี้ในระบบ',
        };
      }

      // Sign in via Supabase Auth using resolved email
      final authResponse = await _supabase.auth.signInWithPassword(
        email: userQuery['user_email'],
        password: password,
      );

      if (authResponse.session == null) {
        await _recordFailedAttempt();
        await _serverUpdateLockout(success: false);
        return {
          'success': false,
          'message': 'ไม่สามารถเข้าสู่ระบบได้ กรุณาลองใหม่',
        };
      }

      // Update last_login timestamp
      await _supabase.from('users').update({
        'last_login': DateTime.now().toIso8601String(),
      }).eq('user_id', userQuery['user_id']);

      // Get user data and create UserModel
      final userData = await _getUserWithInfo(userQuery['user_id']);
      final user = UserModel.fromDatabase(userData);

      // Reset failures on success (local + server best-effort)
      await _resetFailedAttempts();
      await _serverUpdateLockout(success: true);

      return {
        'success': true,
        'user': user,
        'message': 'เข้าสู่ระบบสำเร็จ',
      };
    } on AuthException catch (e) {
      await _recordFailedAttempt();
      await _serverUpdateLockout(success: false);
      return {
        'success': false,
        'message': e.message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ: $e',
      };
    }
  }

  // Safer user lookup to avoid building raw filter strings
  static Future<Map<String, dynamic>?> _findActiveUserByEmailOrUsername(
      String value) async {
    // Try by email
    final byEmail = await _supabase
        .from('users')
        .select('*')
        .eq('user_email', value)
        .eq('is_active', true)
        .maybeSingle();
    if (byEmail != null) return byEmail;

    // Try by username
    final byUsername = await _supabase
        .from('users')
        .select('*')
        .eq('user_name', value)
        .eq('is_active', true)
        .maybeSingle();
    return byUsername;
  }

  // Get user with additional info
  static Future<Map<String, dynamic>> _getUserWithInfo(String userId) async {
    final userResponse = await _supabase
        .from('users')
        .select('*')
        .eq('user_id', userId)
        .eq('is_active', true)
        .single();

    // If user is tenant, get tenant info
    if (userResponse['role'] == 'tenant') {
      try {
        final tenantResponse = await _supabase
            .from('tenants')
            .select('*')
            .eq('user_id', userId)
            .eq('is_active', true)
            .single();

        return {
          ...userResponse,
          'tenant_info': tenantResponse,
        };
      } catch (e) {
        return userResponse;
      }
    }

    return userResponse;
  }

  // Get current user from session
  static Future<UserModel?> getCurrentUser() async {
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return null;

      final userData = await _getUserWithInfo(authUser.id);

      if (userData['is_active'] != true) {
        await signOut();
        return null;
      }

      return UserModel.fromDatabase(userData);
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Validate current session
  static Future<bool> validateSession() async {
    try {
      var session = _supabase.auth.currentSession;
      if (session == null) return false;

      // Refresh if expired
      if (session.expiresAt != null) {
        final expiry =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (DateTime.now().isAfter(expiry)) {
          final refreshResponse = await _supabase.auth.refreshSession();
          session = refreshResponse.session;
          if (session == null) {
            await signOut();
            return false;
          }
        }
      }

      final authUser = _supabase.auth.currentUser;
      if (authUser == null) return false;

      final userResponse = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_id', authUser.id)
          .eq('is_active', true)
          .maybeSingle();

      if (userResponse == null) {
        await signOut();
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error validating session: $e');
      await signOut();
      return false;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Error during sign out: $e');
    } finally {
      await clearUserSession();
    }
  }

  // Clear user session locally
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Clean up any legacy session keys if they exist
    await prefs.remove('user_session');
    await prefs.remove('current_user_id');
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await validateSession();
  }

  // Update password
  static Future<Map<String, dynamic>> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Get current password hash
      final userQuery = await _supabase
          .from('users')
          .select('user_pass')
          .eq('user_id', currentUser.userId)
          .single();

      // Verify current password
      final passwordCheck = await _supabase.rpc('verify_password', params: {
        'password': currentPassword,
        'hash': userQuery['user_pass'],
      });

      if (!passwordCheck) {
        return {
          'success': false,
          'message': 'รหัสผ่านปัจจุบันไม่ถูกต้อง',
        };
      }

      // Hash new password
      final hashedPassword = await _supabase.rpc('hash_password', params: {
        'password': newPassword,
      });

      // Update password
      await _supabase.from('users').update({'user_pass': hashedPassword}).eq(
          'user_id', currentUser.userId);

      return {
        'success': true,
        'message': 'เปลี่ยนรหัสผ่านสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // Update user permissions (admin function)
  static Future<Map<String, dynamic>> updateUserPermissions({
    required String userId,
    required List<String> permissions,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null ||
          !currentUser.hasPermission(DetailedPermission.manageUsers)) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลผู้ใช้',
        };
      }

      // Update user permissions
      await _supabase.from('users').update({
        'permissions': permissions,
      }).eq('user_id', userId);

      return {
        'success': true,
        'message': 'อัปเดตสิทธิ์การใช้งานสำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }

  // ========== Device-wide lockout helpers ==========
  static Future<Map<String, dynamic>> getLockStatus() async {
    // Try server-based status first
    try {
      final result = await _serverGetLockStatus();
      return result;
    } catch (e) {
      // fallback local
    }
    return await _getLocalLockStatus();
  }

  // Server-first helpers
  static Future<Map<String, dynamic>> _serverGetLockStatus() async {
    final deviceId = await _getOrCreateDeviceId();
    final res = await _supabase.rpc('auth_get_lock_status', params: {
      'p_device_id': deviceId,
    });

    Map<String, dynamic>? row;
    if (res is List && res.isNotEmpty) {
      final first = res.first;
      if (first is Map<String, dynamic>) row = first;
    } else if (res is Map<String, dynamic>) {
      row = res;
    }

    if (row == null) {
      return {'locked': false, 'remaining': Duration.zero};
    }

    final locked = row['locked'] == true;
    final remainingSeconds = (row['remaining_seconds'] as num?)?.toInt() ?? 0;
    // Trust server status when available; only fallback to local when RPC fails upstream
    return {'locked': locked, 'remaining': Duration(seconds: remainingSeconds)};
  }

  static Future<bool> _serverUpdateLockout({required bool success}) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      // ส่งเฉพาะพารามิเตอร์ที่จำเป็น เพื่อหลีกเลี่ยงปัญหาชนิดข้อมูล (inet/text)
      await _supabase.rpc('auth_update_lockout', params: {
        'p_device_id': deviceId,
        'p_success': success,
      });
      return true;
    } catch (e) {
      // debug log เงียบ ๆ และ fallback local
      // debugPrint('auth_update_lockout rpc error: $e');
      return false;
    }
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = const Uuid().v4();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
  }

  // ========== Admin unlock helpers ==========
  static Future<Map<String, dynamic>> adminUnlockDevice({
    required String deviceId,
    bool fullReset = false, // ถ้า true จะรีเซ็ต lock_level = 0 ด้วย
  }) async {
    try {
      await _supabase.rpc('auth_unlock_device', params: {
        'p_device_id': deviceId,
        'p_full_reset': fullReset,
      });

      // ถ้าเป็นอุปกรณ์นี้เอง ให้ล้างสถานะ local ด้วย
      final currentDeviceId = await _getOrCreateDeviceId();
      if (currentDeviceId == deviceId) {
        await _clearLocalLock(fullReset: fullReset);
      }

      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }

  static Future<void> _clearLocalLock({bool fullReset = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lockUntilKey);
    await prefs.setInt(_failCountKey, 0);
    if (fullReset) {
      await prefs.setInt(_lockLevelKey, 0);
    }
  }

  // ========== Local fallback lockout helpers ==========
  static Future<Map<String, dynamic>> _getLocalLockStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final lockUntilIso = prefs.getString(_lockUntilKey);
    if (lockUntilIso == null) {
      return {'locked': false, 'remaining': Duration.zero};
    }
    final lockUntil = DateTime.tryParse(lockUntilIso);
    if (lockUntil == null) {
      await prefs.remove(_lockUntilKey);
      return {'locked': false, 'remaining': Duration.zero};
    }
    final now = DateTime.now();
    if (now.isBefore(lockUntil)) {
      return {'locked': true, 'remaining': lockUntil.difference(now)};
    }
    // expired
    await prefs.remove(_lockUntilKey);
    return {'locked': false, 'remaining': Duration.zero};
  }

  static Future<bool> isDeviceLocked() async {
    final status = await getLockStatus();
    return status['locked'] == true;
  }

  static Future<void> _recordFailedAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_failCountKey) ?? 0;
    final newCount = current + 1;
    await prefs.setInt(_failCountKey, newCount);
    if (newCount >= 3) {
      // apply lock and escalate level
      await _applyLockout();
      await prefs.setInt(_failCountKey, 0);
    }
  }

  static Future<void> _resetFailedAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_failCountKey, 0);
    // Do NOT reset level; requirement doesn't specify demotion
  }

  static Future<void> _applyLockout() async {
    final prefs = await SharedPreferences.getInstance();
    int level = prefs.getInt(_lockLevelKey) ?? 0; // 0,1,2 capped
    Duration duration;
    switch (level) {
      case 0:
        duration = const Duration(minutes: 15);
        break;
      case 1:
        duration = const Duration(minutes: 30);
        break;
      default:
        duration = const Duration(hours: 1);
        break;
    }
    final lockUntil = DateTime.now().add(duration).toIso8601String();
    await prefs.setString(_lockUntilKey, lockUntil);
    // escalate level (cap at 2)
    if (level < 2) {
      await prefs.setInt(_lockLevelKey, level + 1);
    } else {
      await prefs.setInt(_lockLevelKey, 2);
    }
  }
}
