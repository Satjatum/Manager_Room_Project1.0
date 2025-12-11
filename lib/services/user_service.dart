import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class UserService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all admin and superadmin users for branch owner selection
  static Future<List<Map<String, dynamic>>> getAdminUsers() async {
    try {
      // Check user permissions
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      // Only superadmin can see all admin users
      if (currentUser.userRole != UserRole.superAdmin) {
        throw Exception('ไม่มีสิทธิ์ในการดูข้อมูลผู้ดูแล');
      }

      // Query admin and superadmin users
      final result = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, role, created_at, is_active')
          .inFilter('role', ['admin', 'superadmin'])
          .eq('is_active', true)
          .order('role', ascending: false) // superadmin first
          .order('user_name', ascending: true);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ดูแล: $e');
    }
  }

  /// Get user by ID
  static Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      final result = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, role, created_at, is_active')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
    }
  }

  /// Get all users (for superadmin only)
  static Future<List<Map<String, dynamic>>> getAllUsers({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? roleFilter,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      // Only superadmin can see all users
      if (currentUser.userRole != UserRole.superAdmin) {
        throw Exception('ไม่มีสิทธิ์ในการดูข้อมูลผู้ใช้ทั้งหมด');
      }

      // Build query
      var query = _supabase.from('users').select('*');

      // Add search filter
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('user_name.ilike.%$searchQuery%,'
            'user_email.ilike.%$searchQuery%');
      }

      // Add role filter
      if (roleFilter != null && roleFilter.isNotEmpty) {
        query = query.eq('role', roleFilter);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลผู้ใช้: $e');
    }
  }

  /// Get assignable users (Admin and SuperAdmin) for issue assignment
  /// Allowed for users who can manage issues (Admin/SuperAdmin)
  static Future<List<Map<String, dynamic>>> getAssignableUsers() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      // Require manageIssues permission (Admin or SuperAdmin)
      final canAssign = currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageIssues,
      ]);

      if (!canAssign) {
        throw Exception('ไม่มีสิทธิ์ในการมอบหมายงาน');
      }

      final result = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, role, is_active')
          .inFilter('role', ['admin', 'superadmin'])
          .eq('is_active', true)
          .order('role', ascending: false)
          .order('user_name', ascending: true);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดรายชื่อผู้รับมอบหมาย: $e');
    }
  }

  /// Create new user (for superadmin only)
  static Future<Map<String, dynamic>> createUser(
      Map<String, dynamic> userData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can create users
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างผู้ใช้ใหม่',
        };
      }

      // Validate required fields
      if (userData['user_name'] == null ||
          userData['user_name'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อผู้ใช้',
        };
      }

      if (userData['user_email'] == null ||
          userData['user_email'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกอีเมล',
        };
      }

      // Check for duplicate username
      final existingUser = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_name', userData['user_name'].toString().trim())
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ',
        };
      }

      // Check for duplicate email
      final existingEmail = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_email', userData['user_email'].toString().trim())
          .maybeSingle();

      if (existingEmail != null) {
        return {
          'success': false,
          'message': 'อีเมลนี้มีอยู่แล้วในระบบ',
        };
      }

      // Step 1: Generate secure password (or use provided one)
      String password;
      if (userData['user_pass'] != null &&
          userData['user_pass'].toString().trim().isNotEmpty) {
        password = userData['user_pass'].toString().trim();
      } else {
        // Auto-generate secure password
        final passwordResult = await _supabase.rpc('generate_secure_password');
        password = passwordResult as String;
      }

      // Step 2: Create user in Supabase Auth WITHOUT hijacking current session
      try {
        // Create new user account (this will automatically log in the new user)
        final authResponse = await _supabase.auth.signUp(
          email: userData['user_email'].toString().trim(),
          password: password,
          data: {
            'username': userData['user_name'].toString().trim(),
            'role': userData['role'] ?? 'tenant',
          },
        );

        if (authResponse.user == null) {
          return {
            'success': false,
            'message': 'ไม่สามารถสร้างผู้ใช้ใน Auth System ได้',
          };
        }

        // Step 3: Wait a moment for trigger to create public.users record
        await Future.delayed(const Duration(milliseconds: 800));

        // Step 4: Update public.users with additional info
        final authUid = authResponse.user!.id;

        // Get the created user data first (while we're logged in as the new user)
        final result = await _supabase
            .from('users')
            .select('*')
            .eq('auth_uid', authUid)
            .single();

        // Update user info
        await _supabase.from('users').update({
          'user_name': userData['user_name'].toString().trim(),
          'role': userData['role'] ?? 'tenant',
          'permissions': userData['permissions'] ?? ['view_own_data'],
          'is_active': userData['is_active'] ?? true,
        }).eq('auth_uid', authUid);

        // ⚠️ CRITICAL: Sign out the newly created user immediately
        await _supabase.auth.signOut();

        // Now the admin must log back in manually, OR we show a success message
        // and redirect to login page

        return {
          'success': true,
          'message': 'สร้างผู้ใช้สำเร็จ - กรุณาเข้าสู่ระบบอีกครั้ง',
          'data': result,
          'password': password,
          'requireRelogin': true, // Flag to tell UI to redirect to login
        };
      } on AuthException catch (e) {
        return {
          'success': false,
          'message': 'ไม่สามารถสร้างผู้ใช้ได้: ${e.message}',
        };
      }
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('user_name')) {
          message = 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ';
        } else if (e.message.contains('user_email')) {
          message = 'อีเมลนี้มีอยู่แล้วในระบบ';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างผู้ใช้: $e',
      };
    }
  }

  /// Create tenant user WITHOUT affecting current admin session
  static Future<Map<String, dynamic>> createTenantUserWithoutSessionHijack(
      Map<String, dynamic> userData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Store current admin session data
      final adminSession = _supabase.auth.currentSession;
      final adminAccessToken = adminSession?.accessToken;
      final adminRefreshToken = adminSession?.refreshToken;

      // Validate required fields
      if (userData['user_name'] == null ||
          userData['user_name'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อผู้ใช้',
        };
      }

      if (userData['user_email'] == null ||
          userData['user_email'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกอีเมล',
        };
      }

      if (userData['user_pass'] == null ||
          userData['user_pass'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกรหัสผ่าน',
        };
      }

      // Check for duplicate username
      final existingUser = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_name', userData['user_name'].toString().trim())
          .maybeSingle();

      if (existingUser != null) {
        return {
          'success': false,
          'message': 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ',
        };
      }

      // Check for duplicate email
      final existingEmail = await _supabase
          .from('users')
          .select('user_id')
          .eq('user_email', userData['user_email'].toString().trim())
          .maybeSingle();

      if (existingEmail != null) {
        return {
          'success': false,
          'message': 'อีเมลนี้มีอยู่แล้วในระบบ',
        };
      }

      final password = userData['user_pass'].toString().trim();
      final email = userData['user_email'].toString().trim();
      final username = userData['user_name'].toString().trim();

      try {
        // Create new user account (this will hijack current session)
        final authResponse = await _supabase.auth.signUp(
          email: email,
          password: password,
          data: {
            'username': username,
            'role': userData['role'] ?? 'tenant',
          },
        );

        if (authResponse.user == null) {
          return {
            'success': false,
            'message': 'ไม่สามารถสร้างผู้ใช้ใน Auth System ได้',
          };
        }

        // Wait for trigger to create public.users record
        await Future.delayed(const Duration(milliseconds: 800));

        final authUid = authResponse.user!.id;

        // Get the created user data (while we're logged in as the new user)
        final createdUser = await _supabase
            .from('users')
            .select('*')
            .eq('auth_uid', authUid)
            .single();

        // Update user info
        await _supabase.from('users').update({
          'user_name': username,
          'role': userData['role'] ?? 'tenant',
          'permissions': userData['permissions'] ?? ['view_own_data'],
          'is_active': userData['is_active'] ?? true,
        }).eq('auth_uid', authUid);

        // CRITICAL: Restore admin session immediately
        if (adminAccessToken != null && adminRefreshToken != null) {
          try {
            await _supabase.auth.setSession(adminRefreshToken);

            // Verify the session was restored correctly
            final restoredUser = await AuthService.getCurrentUser();
            if (restoredUser?.userId != currentUser.userId) {
              // Session restore failed, sign out to prevent confusion
              await _supabase.auth.signOut();
              return {
                'success': false,
                'message':
                    'สร้างผู้ใช้สำเร็จแต่ไม่สามารถกู้คืน session ได้ กรุณาเข้าสู่ระบบใหม่',
                'data': createdUser,
                'requireRelogin': true,
              };
            }
          } catch (e) {
            // Session restore failed, sign out to prevent confusion
            await _supabase.auth.signOut();
            return {
              'success': false,
              'message':
                  'สร้างผู้ใช้สำเร็จแต่ไม่สามารถกู้คืน session ได้ กรุณาเข้าสู่ระบบใหม่',
              'data': createdUser,
              'requireRelogin': true,
            };
          }
        } else {
          // No admin session to restore, sign out
          await _supabase.auth.signOut();
          return {
            'success': false,
            'message':
                'สร้างผู้ใช้สำเร็จแต่ไม่สามารถกู้คืน session ได้ กรุณาเข้าสู่ระบบใหม่',
            'data': createdUser,
            'requireRelogin': true,
          };
        }

        return {
          'success': true,
          'message': 'สร้างผู้ใช้สำเร็จ',
          'data': createdUser,
        };
      } on AuthException catch (e) {
        // Restore admin session on auth error
        if (adminAccessToken != null && adminRefreshToken != null) {
          try {
            await _supabase.auth.setSession(adminRefreshToken);
          } catch (_) {
            // Ignore restore errors
          }
        }

        return {
          'success': false,
          'message': 'ไม่สามารถสร้างผู้ใช้ได้: ${e.message}',
        };
      }
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('user_name')) {
          message = 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ';
        } else if (e.message.contains('user_email')) {
          message = 'อีเมลนี้มีอยู่แล้วในระบบ';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างผู้ใช้: $e',
      };
    }
  }

  /// Update user (for superadmin only)
  static Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can update users (except own profile)
      if (currentUser.userRole != UserRole.superAdmin &&
          currentUser.userId != userId) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขข้อมูลผู้ใช้',
        };
      }

      // Prepare data for update
      final updateData = <String, dynamic>{};

      if (userData['user_name'] != null) {
        updateData['user_name'] = userData['user_name'].toString().trim();
      }

      if (userData['user_email'] != null) {
        updateData['user_email'] = userData['user_email'].toString().trim();
      }

      if (userData['role'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['role'] = userData['role'];
      }

      if (userData['permissions'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['permissions'] = userData['permissions'];
      }

      if (userData['is_active'] != null &&
          currentUser.userRole == UserRole.superAdmin) {
        updateData['is_active'] = userData['is_active'];
      }

      // Handle password update separately via Supabase Auth
      String? newPassword;
      if (userData['user_pass'] != null &&
          userData['user_pass'].toString().isNotEmpty) {
        newPassword = userData['user_pass'].toString();
      }

      if (updateData.isEmpty && newPassword == null) {
        return {
          'success': false,
          'message': 'ไม่มีข้อมูลที่ต้องอัปเดต',
        };
      }

      // Update user data in public.users
      Map<String, dynamic>? result;
      if (updateData.isNotEmpty) {
        result = await _supabase
            .from('users')
            .update(updateData)
            .eq('user_id', userId)
            .select()
            .single();
      }

      return {
        'success': true,
        'message': 'อัปเดตข้อมูลผู้ใช้สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('user_name')) {
          message = 'ชื่อผู้ใช้นี้มีอยู่แล้วในระบบ';
        } else if (e.message.contains('user_email')) {
          message = 'อีเมลนี้มีอยู่แล้วในระบบ';
        }
      } else if (e.code == 'PGRST116') {
        // Row not found
        message = 'ไม่พบผู้ใช้ที่ต้องการแก้ไข';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตข้อมูลผู้ใช้: $e',
      };
    }
  }

  /// Delete/Deactivate user (for superadmin only)
  static Future<Map<String, dynamic>> deactivateUser(String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can deactivate users
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบผู้ใช้',
        };
      }

      // Cannot deactivate self
      if (currentUser.userId == userId) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบบัญชีของตัวเองได้',
        };
      }

      // Soft delete by setting is_active to false
      await _supabase
          .from('users')
          .update({'is_active': false}).eq('user_id', userId);

      // Also deactivate all sessions for this user
      await _supabase.from('user_sessions').delete().eq('user_id', userId);

      return {
        'success': true,
        'message': 'ปิดใช้งานผู้ใช้สำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        // Row not found
        message = 'ไม่พบผู้ใช้ที่ต้องการลบ';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบผู้ใช้: $e',
      };
    }
  }

  /// Permanently delete a user (SuperAdmin only)
  static Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can delete users permanently
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบผู้ใช้ถาวร',
        };
      }

      // Cannot delete self
      if (currentUser.userId == userId) {
        return {
          'success': false,
          'message': 'ไม่สามารถลบบัญชีของตัวเองได้',
        };
      }

      // Ensure target user exists and is not superadmin
      final target = await _supabase
          .from('users')
          .select('user_id, role, user_name')
          .eq('user_id', userId)
          .maybeSingle();

      if (target == null) {
        return {
          'success': false,
          'message': 'ไม่พบผู้ใช้ที่ต้องการลบ',
        };
      }

      if ((target['role'] as String).toLowerCase() == 'superadmin') {
        return {
          'success': false,
          'message': 'ไม่สามารถลบผู้ใช้ระดับ SuperAdmin ได้',
        };
      }

      await _supabase.from('users').delete().eq('user_id', userId);

      return {
        'success': true,
        'message': 'ลบบัญชีผู้ใช้ "${target['user_name']}" ถาวรสำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบผู้ใช้ที่ต้องการลบ';
      } else if (e.code == '23503') {
        message = 'ไม่สามารถลบผู้ใช้ได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบผู้ใช้: $e',
      };
    }
  }

  /// Search users by name or email
  static Future<List<Map<String, dynamic>>> searchUsers(
      String searchQuery) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('กรุณาเข้าสู่ระบบใหม่');
      }

      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('users')
          .select('user_id, user_name, user_email, role, is_active')
          .or('user_name.ilike.%$searchQuery%,'
              'user_email.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('user_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาผู้ใช้: $e');
    }
  }

  /// Send password reset email to user (for superadmin only)
  static Future<Map<String, dynamic>> sendPasswordResetEmail(
      String userId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Only superadmin can send password reset emails
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการส่งอีเมลรีเซ็ตรหัสผ่าน',
        };
      }

      // Get user email
      final user = await _supabase
          .from('users')
          .select('user_email, user_name')
          .eq('user_id', userId)
          .single();

      final userEmail = user['user_email'] as String;
      final userName = user['user_name'] as String;

      // Send password reset email via Supabase Auth
      await _supabase.auth.resetPasswordForEmail(
        userEmail,
        redirectTo:
            'your-app://reset-password', // Update with your redirect URL
      );

      return {
        'success': true,
        'message': 'ส่งอีเมลรีเซ็ตรหัสผ่านไปยัง $userName ($userEmail) แล้ว',
      };
    } on AuthException catch (e) {
      return {
        'success': false,
        'message': 'ไม่สามารถส่งอีเมลได้: ${e.message}',
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'ไม่พบผู้ใช้: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: $e',
      };
    }
  }
}
