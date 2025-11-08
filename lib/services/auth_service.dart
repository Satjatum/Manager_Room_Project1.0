import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_models.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _sessionKey = 'user_session';
  static const String _userIdKey = 'current_user_id';
  static const String _deviceIdKey = 'device_id';
  // Device-wide lockout keys (not per-account)
  static const String _failCountKey = 'login_fail_count';
  static const String _lockUntilKey = 'login_lock_until';
  static const String _lockLevelKey = 'login_lock_level'; // 0:15m,1:30m,2:60m (cap)

  // Initialize session on app start
  static Future<void> initializeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString(_sessionKey);

      if (sessionData != null) {
        final isValid = await validateSession();
        if (!isValid) {
          await clearUserSession();
        }
      }

      // Do not attempt anonymous sign-in; follow the same flow as admin/superadmin
      // Any required storage access should be handled by existing RLS/policies
    } catch (e) {
      print('Error initializing session: $e');
      await clearUserSession();
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

      // Query user by email or username
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

      // Verify password using database function
      final passwordCheck = await _supabase.rpc('verify_password', params: {
        'password': password,
        'hash': userQuery['user_pass'],
      });

      if (!passwordCheck) {
        // Always record local fail; also try server update (best-effort)
        await _recordFailedAttempt();
        await _serverUpdateLockout(success: false);
        return {
          'success': false,
          'message': 'รหัสผ่านไม่ถูกต้อง',
        };
      }

      // Update last_login timestamp
      await _supabase.from('users').update({
        'last_login': DateTime.now().toIso8601String(),
      }).eq('user_id', userQuery['user_id']);

      // Generate new session token
      final sessionToken = await _generateSessionToken();
      final expiresAt = DateTime.now().add(const Duration(days: 7));

      // Create session in database with additional tracking info
      await _supabase.from('user_sessions').insert({
        'user_id': userQuery['user_id'],
        'token': sessionToken,
        'expires_at': expiresAt.toIso8601String(),
        'last_activity': DateTime.now().toIso8601String(),
        'user_agent': await _getUserAgent(),
        'ip_address': await _getClientIP(),
      });

      // Get user data and create UserModel
      final userData = await _getUserWithInfo(userQuery['user_id']);
      final user = UserModel.fromDatabase(userData);

      // Store session locally
      await _storeUserSession(user.userId, sessionToken);

      // Reset failures on success (local + server best-effort)
      await _resetFailedAttempts();
      await _serverUpdateLockout(success: true);

      return {
        'success': true,
        'user': user,
        'message': 'เข้าสู่ระบบสำเร็จ',
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

  // Generate session token
  static Future<String> _generateSessionToken() async {
    final result = await _supabase.rpc('generate_token');
    return result as String;
  }

  // Get user agent (simplified for Flutter)
  static Future<String> _getUserAgent() async {
    try {
      // You can implement device info here
      return 'Flutter App';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get client IP (placeholder - would need proper implementation)
  static Future<String?> _getClientIP() async {
    try {
      // This would require proper IP detection implementation
      return null;
    } catch (e) {
      return null;
    }
  }

  // Store session locally
  static Future<void> _storeUserSession(
      String userId, String sessionToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionToken);
    await prefs.setString(_userIdKey, userId);
  }

  // Get current user from session
  static Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_userIdKey);

      if (userId == null) return null;

      final userData = await _getUserWithInfo(userId);
      return UserModel.fromDatabase(userData);
    } catch (e) {
      print('Error getting current user: $e');
      return null;
    }
  }

  // Validate current session
  static Future<bool> validateSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString(_sessionKey);
      final userId = prefs.getString(_userIdKey);

      if (sessionToken == null || userId == null) return false;

      // Check session in database
      final sessionResponse = await _supabase
          .from('user_sessions')
          .select('*')
          .eq('token', sessionToken)
          .eq('user_id', userId)
          .gte('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (sessionResponse == null) {
        await clearUserSession();
        return false;
      }

      // Update last activity
      await _supabase.from('user_sessions').update({
        'last_activity': DateTime.now().toIso8601String(),
      }).eq('token', sessionToken);

      // Check if user is still active
      final userResponse = await _supabase
          .from('users')
          .select('is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (userResponse == null) {
        await clearUserSession();
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating session: $e');
      await clearUserSession();
      return false;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString(_sessionKey);

      if (sessionToken != null) {
        await _supabase
            .from('user_sessions')
            .delete()
            .eq('token', sessionToken);
      }
    } catch (e) {
      print('Error during sign out: $e');
    } finally {
      await clearUserSession();
    }
  }

  // Clear user session locally
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_userIdKey);
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

  // Get user login history
  static Future<List<Map<String, dynamic>>> getUserLoginHistory({
    String? userId,
    int limit = 10,
  }) async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return [];

      final targetUserId = userId ?? currentUser.userId;

      // Only allow users to see their own history unless they're admin
      if (targetUserId != currentUser.userId &&
          !currentUser.hasPermission(DetailedPermission.manageUsers)) {
        return [];
      }

      final sessions = await _supabase
          .from('user_sessions')
          .select('created_at, last_activity, user_agent, ip_address')
          .eq('user_id', targetUserId)
          .order('created_at', ascending: false)
          .limit(limit);

      return sessions;
    } catch (e) {
      print('Error getting login history: $e');
      return [];
    }
  }

  // Clean expired sessions
  static Future<void> cleanExpiredSessions() async {
    try {
      await _supabase
          .from('user_sessions')
          .delete()
          .lt('expires_at', DateTime.now().toIso8601String());
    } catch (e) {
      print('Error cleaning expired sessions: $e');
    }
  }

  // Get active sessions count for current user
  static Future<int> getActiveSessionsCount() async {
    try {
      final currentUser = await getCurrentUser();
      if (currentUser == null) return 0;

      final sessions = await _supabase
          .from('user_sessions')
          .select('session_id')
          .eq('user_id', currentUser.userId)
          .gte('expires_at', DateTime.now().toIso8601String());

      return sessions.length;
    } catch (e) {
      print('Error getting active sessions count: $e');
      return 0;
    }
  }

  // Terminate all other sessions (keep current one)
  static Future<Map<String, dynamic>> terminateOtherSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentSessionToken = prefs.getString(_sessionKey);
      final currentUser = await getCurrentUser();

      if (currentUser == null || currentSessionToken == null) {
        return {
          'success': false,
          'message': 'ไม่พบเซสชันปัจจุบัน',
        };
      }

      await _supabase
          .from('user_sessions')
          .delete()
          .eq('user_id', currentUser.userId)
          .neq('token', currentSessionToken);

      return {
        'success': true,
        'message': 'ยกเลิกเซสชันอื่นทั้งหมดสำเร็จ',
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
    // If server says unlocked, still check local lock
    if (!locked) {
      final local = await _getLocalLockStatus();
      if (local['locked'] == true) return local;
    }

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
      // print('auth_update_lockout rpc error: $e');
      return false;
    }
  }

  static Future<String> _getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    // generate from server to avoid adding deps
    final generated = await _generateSessionToken();
    await prefs.setString(_deviceIdKey, generated);
    return generated;
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
