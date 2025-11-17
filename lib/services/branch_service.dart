import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';

class BranchService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Get all branches with pagination and filtering - updated to use branches_with_managers view
  static Future<List<Map<String, dynamic>>> getAllBranches({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    bool? isActive,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      // Build query using the view instead of direct table
      var query = _supabase.from('branches_with_managers').select('*');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('branch_name.ilike.%$searchQuery%,'
            'branch_code.ilike.%$searchQuery%,'
            'branch_address.ilike.%$searchQuery%,'
            'owner_name.ilike.%$searchQuery%'); // Added owner_name search
      }

      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  // ============== Global/Test Flags on Branch JSON (branch_desc) ==============
  /// อ่านสถานะโหมดทดสอบ PromptPay จากสาขา (เก็บใน branches.branch_desc -> { pp_test_mode: bool })
  static Future<bool> getPromptPayTestMode(String branchId) async {
    try {
      final row = await _supabase
          .from('branches')
          .select('branch_desc')
          .eq('branch_id', branchId)
          .maybeSingle();
      if (row == null) return false;
      final desc = row['branch_desc'];
      if (desc is Map && desc['pp_test_mode'] == true) return true;
      if (desc is Map<String, dynamic> && desc['pp_test_mode'] == true) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// ตั้งค่าสถานะโหมดทดสอบ PromptPay โดยให้สิทธิ์เฉพาะ Admin เท่านั้น
  /// มีผลทั้งแอป (อ่านได้ทุกบทบาท) ผ่าน branch_desc.pp_test_mode
  static Future<Map<String, dynamic>> setPromptPayTestMode({
    required String branchId,
    required bool enabled,
  }) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }
      // อนุญาตให้ admin และ superadmin สามารถสลับโหมดได้
      if (currentUser.userRole != UserRole.admin &&
          currentUser.userRole != UserRole.superAdmin) {
        return {'success': false, 'message': 'อนุญาตเฉพาะผู้ดูแล (Admin)'};
      }

      // อ่าน desc เดิมแล้ว merge ค่าลงไป
      final current = await _supabase
          .from('branches')
          .select('branch_desc')
          .eq('branch_id', branchId)
          .maybeSingle();
      Map<String, dynamic> desc = {};
      if (current != null && current['branch_desc'] is Map<String, dynamic>) {
        desc = Map<String, dynamic>.from(current['branch_desc']);
      }
      desc['pp_test_mode'] = enabled;

      final res = await _supabase
          .from('branches')
          .update({'branch_desc': desc, 'updated_at': DateTime.now().toIso8601String()})
          .eq('branch_id', branchId)
          .select()
          .single();
      return {
        'success': true,
        'message': enabled ? 'เปิดโหมดทดสอบ PromptPay แล้ว' : 'ปิดโหมดทดสอบ PromptPay แล้ว',
        'data': res,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอัปเดตโหมดทดสอบได้: $e'};
    }
  }

  // Get branches by user - updated for new schema
  static Future<List<Map<String, dynamic>>> getBranchesByUser() async {
    try {
      final currentUser = await AuthService.getCurrentUser();

      // Allow anonymous access - return active branches only
      if (currentUser == null) {
        return await getAllBranches(isActive: true);
      }

      // SuperAdmin can see all branches
      if (currentUser.userRole == UserRole.superAdmin) {
        return getAllBranches(isActive: true);
      }

      // Admin can only see branches they manage
      if (currentUser.userRole == UserRole.admin) {
        final result = await _supabase
            .from('branch_managers')
            .select('branch_id')
            .eq('user_id', currentUser.userId);

        if (result.isEmpty) {
          return []; // Admin ไม่ได้ดูแลสาขาใดเลย
        }

        // Get list of branch IDs that this admin manages
        final branchIds = result.map((item) => item['branch_id']).toList();

        // Fetch full branch data from branches_with_managers view
        final branches = await _supabase
            .from('branches_with_managers')
            .select('*')
            .inFilter('branch_id', branchIds)
            .order('branch_name');

        return List<Map<String, dynamic>>.from(branches);
      }

      // For other users, return branches they have access to
      var query = _supabase
          .from('branches_with_managers')
          .select('*')
          .eq('is_active', true);

      // If user is assigned to specific branches, filter by that
      if (currentUser.branchId != null) {
        query = query.eq('branch_id', currentUser.branchId!);
      }

      final result = await query.order('branch_name');

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  // Get branch by ID - updated to use view
  static Future<Map<String, dynamic>?> getBranchById(String branchId) async {
    try {
      final result = await _supabase
          .from('branches_with_managers')
          .select('*')
          .eq('branch_id', branchId)
          .maybeSingle();

      return result;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }

  // Create new branch - updated for new schema
  static Future<Map<String, dynamic>> createBranch(
      Map<String, dynamic> branchData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions - only superadmin can create branches
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการสร้างสาขาใหม่',
        };
      }

      // Validate required fields
      if (branchData['branch_code'] == null ||
          branchData['branch_code'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกรหัสสาขา',
        };
      }

      if (branchData['branch_name'] == null ||
          branchData['branch_name'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อสาขา',
        };
      }

      if (branchData['branch_phone'] != null &&
          branchData['branch_phone'].toString().trim().isNotEmpty) {
        final phone = branchData['branch_phone'].toString().trim();
        if (!RegExp(r'^[0-9\-\(\)\s]+$').hasMatch(phone)) {
          return {
            'success': false,
            'message': 'รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง',
          };
        }
      }

      // Check for duplicate branch code
      final existingBranch = await _supabase
          .from('branches')
          .select('branch_id')
          .eq('branch_code', branchData['branch_code'].toString().trim())
          .maybeSingle();

      if (existingBranch != null) {
        return {
          'success': false,
          'message': 'รหัสสาขานี้มีอยู่แล้วในระบบ',
        };
      }

      // Validate owner_id if provided
      if (branchData['owner_id'] != null &&
          branchData['owner_id'].toString().isNotEmpty) {
        final ownerData = await _supabase
            .from('users')
            .select('user_name, role, is_active')
            .eq('user_id', branchData['owner_id'])
            .eq('is_active', true)
            .maybeSingle();

        if (ownerData == null) {
          return {
            'success': false,
            'message': 'ไม่พบผู้ใช้ที่เลือกเป็นเจ้าของสาขา',
          };
        }

        // Check if user is admin or superadmin
        if (ownerData['role'] != 'admin' && ownerData['role'] != 'superadmin') {
          return {
            'success': false,
            'message': 'เจ้าของสาขาต้องเป็น Admin หรือ SuperAdmin เท่านั้น',
          };
        }
      }

      final insertData = {
        'branch_code': branchData['branch_code'].toString().trim(),
        'branch_name': branchData['branch_name'].toString().trim(),
        'branch_address': branchData['branch_address']?.toString().trim(),
        'branch_phone': branchData['branch_phone']?.toString().trim(),
        'owner_id': currentUser.userId,
        'branch_image': branchData['branch_image'],
        'branch_desc': branchData['branch_desc'],
        'is_active': branchData['is_active'] ?? true,
        'created_by': currentUser.userId,
      };

      final result =
          await _supabase.from('branches').insert(insertData).select().single();

      return {
        'success': true,
        'message': 'สร้างสาขาสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('branch_code')) {
          message = 'รหัสสาขานี้มีอยู่แล้วในระบบ';
        }
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการสร้างสาขา: $e',
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getBranchesManagedByUser(
      String userId) async {
    try {
      final result = await _supabase.from('branch_managers').select('''
          branches:branch_id (
            *
          )
        ''').eq('user_id', userId);

      return List<Map<String, dynamic>>.from(
          result.map((item) => item['branches']).toList());
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสาขาที่ดูแล: $e');
    }
  }

  // Update branch - updated for new schema
  static Future<Map<String, dynamic>> updateBranch(
    String branchId,
    Map<String, dynamic> branchData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Check permissions: allow superadmin/manageBranches OR admin who manages this branch
      bool isManager = false;
      if (currentUser.userRole == UserRole.admin) {
        final managerRow = await _supabase
            .from('branch_managers')
            .select('id')
            .eq('branch_id', branchId)
            .eq('user_id', currentUser.userId)
            .maybeSingle();
        isManager = managerRow != null;
      }

      final allowed = currentUser.hasAnyPermission([
            DetailedPermission.all,
            DetailedPermission.manageBranches,
          ]) ||
          (currentUser.userRole == UserRole.admin && isManager);

      if (!allowed) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการแก้ไขสาขา',
        };
      }

      // Validate required fields
      if (branchData['branch_code'] == null ||
          branchData['branch_code'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกรหัสสาขา',
        };
      }

      if (branchData['branch_name'] == null ||
          branchData['branch_name'].toString().trim().isEmpty) {
        return {
          'success': false,
          'message': 'กรุณากรอกชื่อสาขา',
        };
      }

      if (branchData['branch_phone'] != null &&
          branchData['branch_phone'].toString().trim().isNotEmpty) {
        final phone = branchData['branch_phone'].toString().trim();
        if (!RegExp(r'^[0-9\-\(\)\s]+$').hasMatch(phone)) {
          return {
            'success': false,
            'message': 'รูปแบบเบอร์โทรศัพท์ไม่ถูกต้อง',
          };
        }
      }

      // Check for duplicate branch code (exclude current branch)
      final existingBranch = await _supabase
          .from('branches')
          .select('branch_id')
          .eq('branch_code', branchData['branch_code'].toString().trim())
          .neq('branch_id', branchId)
          .maybeSingle();

      if (existingBranch != null) {
        return {
          'success': false,
          'message': 'รหัสสาขานี้มีอยู่แล้วในระบบ',
        };
      }

      // Validate owner_id if provided
      if (branchData['owner_id'] != null &&
          branchData['owner_id'].toString().isNotEmpty) {
        final ownerData = await _supabase
            .from('users')
            .select('user_name, role, is_active')
            .eq('user_id', branchData['owner_id'])
            .eq('is_active', true)
            .maybeSingle();

        if (ownerData == null) {
          return {
            'success': false,
            'message': 'ไม่พบผู้ใช้ที่เลือกเป็นเจ้าของสาขา',
          };
        }

        // Check if user is admin or superadmin
        if (ownerData['role'] != 'admin' && ownerData['role'] != 'superadmin') {
          return {
            'success': false,
            'message': 'เจ้าของสาขาต้องเป็น Admin หรือ SuperAdmin เท่านั้น',
          };
        }
      }

      // Prepare data for update - removed owner_name
      final updateData = {
        'branch_code': branchData['branch_code'].toString().trim(),
        'branch_name': branchData['branch_name'].toString().trim(),
        'branch_address': branchData['branch_address']?.toString().trim(),
        'branch_phone': branchData['branch_phone']?.toString().trim(),
        'owner_id': currentUser.userId,
        'branch_image': branchData['branch_image'],
        'branch_desc': branchData['branch_desc'],
        'is_active': branchData['is_active'] ?? true,
      };

      final result = await _supabase
          .from('branches')
          .update(updateData)
          .eq('branch_id', branchId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตสาขาสำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == '23505') {
        // Unique constraint violation
        if (e.message.contains('branch_code')) {
          message = 'รหัสสาขานี้มีอยู่แล้วในระบบ';
        }
      } else if (e.code == 'PGRST116') {
        // Row not found
        message = 'ไม่พบสาขาที่ต้องการแก้ไข';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตสาขา: $e',
      };
    }
  }

  // Soft delete branch (set is_active to false)
  static Future<Map<String, dynamic>> deleteBranch(String branchId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // ตรวจสอบ branchId
      if (branchId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสสาขาที่ต้องการลบ',
        };
      }

      // Check permissions - เฉพาะ superadmin เท่านั้น
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบสาขา',
        };
      }

      // ตรวจสอบว่าสาขานี้มีอยู่จริงหรือไม่
      final existingBranch = await _supabase
          .from('branches')
          .select('branch_id, branch_name, is_active')
          .eq('branch_id', branchId)
          .maybeSingle();

      if (existingBranch == null) {
        return {
          'success': false,
          'message': 'ไม่พบสาขาที่ต้องการลบ',
        };
      }

      // ตรวจสอบว่าสาขาถูกปิดใช้งานแล้วหรือยัง
      if (existingBranch['is_active'] == false) {
        return {
          'success': false,
          'message': 'สาขานี้ถูกปิดใช้งานแล้ว',
        };
      }

      // ตรวจสอบว่ามีห้องเช่าที่ยังใช้งานอยู่หรือไม่
      final activeRooms = await _supabase
          .from('rooms')
          .select('room_id, room_number')
          .eq('branch_id', branchId)
          .eq('is_active', true);

      if (activeRooms.isNotEmpty) {
        return {
          'success': false,
          'message':
              'ไม่สามารถปิดใช้งานสาขาได้ เนื่องจากยังมีห้องเช่าที่ใช้งานอยู่ ${activeRooms.length} ห้อง',
        };
      }

      // ตรวจสอบสัญญาเช่าที่ยังใช้งานอยู่ (ผ่าน rooms table)
      final roomIds = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', branchId);

      if (roomIds.isNotEmpty) {
        final roomIdList = roomIds.map((room) => room['room_id']).toList();

        final activeContracts = await _supabase
            .from('rental_contracts')
            .select('contract_id, contract_num')
            .inFilter('room_id', roomIdList)
            .inFilter('contract_status', ['active', 'pending']);

        if (activeContracts.isNotEmpty) {
          return {
            'success': false,
            'message':
                'ไม่สามารถปิดใช้งานสาขาได้ เนื่องจากยังมีสัญญาเช่าที่ใช้งานอยู่ ${activeContracts.length} สัญญา',
          };
        }
      }

      // ทำการ soft delete
      final result = await _supabase
          .from('branches')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('branch_id', branchId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'ปิดใช้งานสาขา "${existingBranch['branch_name']}" สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบสาขาที่ต้องการลบ';
      } else if (e.code == '23503') {
        // Foreign key constraint
        message = 'ไม่สามารถปิดใช้งานสาขาได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการปิดใช้งานสาขา: ${e.toString()}',
      };
    }
  }

  // Hard delete branch (permanently delete)
  static Future<Map<String, dynamic>> permanentDeleteBranch(
      String branchId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // ตรวจสอบ branchId
      if (branchId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสสาขาที่ต้องการลบ',
        };
      }

      // เฉพาะ superadmin เท่านั้นที่ลบถาวรได้
      if (currentUser.userRole != UserRole.superAdmin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการลบสาขาถาวร',
        };
      }

      // ตรวจสอบว่าสาขานี้มีอยู่จริงหรือไม่
      final existingBranch = await _supabase
          .from('branches')
          .select('branch_id, branch_name, is_active')
          .eq('branch_id', branchId)
          .maybeSingle();

      if (existingBranch == null) {
        return {
          'success': false,
          'message': 'ไม่พบสาขาที่ต้องการลบ',
        };
      }
      // ==========================
      // Begin code-level cascading
      // ==========================
      final List<Map<String, dynamic>> roomRows = List<Map<String, dynamic>>.from(
          await _supabase
              .from('rooms')
              .select('room_id')
              .eq('branch_id', branchId));
      final roomIds = roomRows
          .map((r) => r['room_id'])
          .where((v) => v != null)
          .map<String>((v) => v.toString())
          .toList();

      final List<Map<String, dynamic>> tenantRows = List<Map<String, dynamic>>.from(
          await _supabase
              .from('tenants')
              .select('tenant_id, user_id')
              .eq('branch_id', branchId));
      final tenantIds = tenantRows
          .map((r) => r['tenant_id'])
          .where((v) => v != null)
          .map<String>((v) => v.toString())
          .toList();

      // Collect contract ids (by rooms or tenants)
      List<String> contractIds = [];
      try {
        final List<Map<String, dynamic>> contractsByRoom = roomIds.isEmpty
            ? []
            : List<Map<String, dynamic>>.from(await _supabase
                .from('rental_contracts')
                .select('contract_id')
                .inFilter('room_id', roomIds));
        final List<Map<String, dynamic>> contractsByTenant = tenantIds.isEmpty
            ? []
            : List<Map<String, dynamic>>.from(await _supabase
                .from('rental_contracts')
                .select('contract_id')
                .inFilter('tenant_id', tenantIds));
        contractIds = [
          ...contractsByRoom.map((r) => r['contract_id']).where((v) => v != null).map<String>((v) => v.toString()),
          ...contractsByTenant.map((r) => r['contract_id']).where((v) => v != null).map<String>((v) => v.toString()),
        ].toSet().toList();
      } catch (_) {}

      // 1) Invoices under this branch (via rooms)
      List<String> invoiceIds = [];
      try {
        if (roomIds.isNotEmpty) {
          final invRows = await _supabase
              .from('invoices')
              .select('invoice_id')
              .inFilter('room_id', roomIds);
          invoiceIds = List<Map<String, dynamic>>.from(invRows)
              .map((r) => r['invoice_id'])
              .where((v) => v != null)
              .map<String>((v) => v.toString())
              .toList();
        }
      } catch (_) {}

      // 1.1) Payments for those invoices (and additionally by tenants just in case)
      try {
        if (invoiceIds.isNotEmpty) {
          await _supabase
              .from('payments')
              .delete()
              .inFilter('invoice_id', invoiceIds);
        }
        if (tenantIds.isNotEmpty) {
          await _supabase
              .from('payments')
              .delete()
              .inFilter('tenant_id', tenantIds);
        }
      } catch (_) {}

      // 1.2) Unlink meter_readings from those invoices
      try {
        if (invoiceIds.isNotEmpty) {
          await _supabase
              .from('meter_readings')
              .update({'invoice_id': null, 'reading_status': 'confirmed'})
              .inFilter('invoice_id', invoiceIds);
        }
      } catch (_) {}

      // 1.3) Delete invoice detail tables then invoices
      try {
        if (invoiceIds.isNotEmpty) {
          await _supabase
              .from('invoice_utilities')
              .delete()
              .inFilter('invoice_id', invoiceIds);
          await _supabase
              .from('invoice_other_charges')
              .delete()
              .inFilter('invoice_id', invoiceIds);
          await _supabase
              .from('invoices')
              .delete()
              .inFilter('invoice_id', invoiceIds);
        }
      } catch (_) {}

      // 2) Payment slips and verification history (by invoices/tenants)
      try {
        List<String> slipIds = [];
        if (invoiceIds.isNotEmpty || tenantIds.isNotEmpty) {
          var q = _supabase.from('payment_slips').select('slip_id');
          if (invoiceIds.isNotEmpty) {
            q = q.inFilter('invoice_id', invoiceIds);
          }
          if (tenantIds.isNotEmpty) {
            q = q.or('tenant_id.in.({${tenantIds.join(',')}})');
          }
          final rows = await q;
          slipIds = List<Map<String, dynamic>>.from(rows)
              .map((r) => r['slip_id'])
              .where((v) => v != null)
              .map<String>((v) => v.toString())
              .toList();
        }
        if (slipIds.isNotEmpty) {
          // delete histories first, then slips
          await _supabase
              .from('slip_verification_history')
              .delete()
              .inFilter('slip_id', slipIds);
          await _supabase
              .from('payment_slips')
              .delete()
              .inFilter('slip_id', slipIds);
        }
      } catch (_) {}

      // 3) Meter readings by contracts
      try {
        if (contractIds.isNotEmpty) {
          await _supabase
              .from('meter_readings')
              .delete()
              .inFilter('contract_id', contractIds);
        }
      } catch (_) {}

      // 4) Issues (images then issues) by rooms
      try {
        if (roomIds.isNotEmpty) {
          final issueRows = await _supabase
              .from('issue_reports')
              .select('issue_id')
              .inFilter('room_id', roomIds);
          final issueIds = List<Map<String, dynamic>>.from(issueRows)
              .map((r) => r['issue_id'])
              .where((v) => v != null)
              .map<String>((v) => v.toString())
              .toList();
          if (issueIds.isNotEmpty) {
            await _supabase
                .from('issue_images')
                .delete()
                .inFilter('issue_id', issueIds);
            await _supabase
                .from('issue_reports')
                .delete()
                .inFilter('issue_id', issueIds);
          }
        }
      } catch (_) {}

      // 5) Rental contracts
      try {
        if (contractIds.isNotEmpty) {
          await _supabase
              .from('rental_contracts')
              .delete()
              .inFilter('contract_id', contractIds);
        }
      } catch (_) {}

      // 6) Room auxiliary data then rooms
      try {
        if (roomIds.isNotEmpty) {
          await _supabase
              .from('room_images')
              .delete()
              .inFilter('room_id', roomIds);
          await _supabase
              .from('room_amenities')
              .delete()
              .inFilter('room_id', roomIds);
          await _supabase
              .from('rooms')
              .delete()
              .inFilter('room_id', roomIds);
        }
      } catch (_) {}

      // 7) Branch QR/accounts
      try {
        await _supabase
            .from('branch_payment_qr')
            .delete()
            .eq('branch_id', branchId);
      } catch (_) {}

      // 8) Payment settings and Utility rates
      try {
        await _supabase
            .from('payment_settings')
            .delete()
            .eq('branch_id', branchId);
      } catch (_) {}
      try {
        await _supabase
            .from('utility_rates')
            .delete()
            .eq('branch_id', branchId);
      } catch (_) {}

      // 9) Branch manager links (keep manager users)
      try {
        await _supabase
            .from('branch_managers')
            .delete()
            .eq('branch_id', branchId);
      } catch (_) {}

      // 10) Delete tenants of this branch
      try {
        if (tenantIds.isNotEmpty) {
          await _supabase
              .from('tenants')
              .delete()
              .inFilter('tenant_id', tenantIds);
        }
      } catch (_) {}

      // 11) Delete tenant user accounts (role=tenant) that are not branch managers anywhere
      try {
        // collect user_ids from tenants
        final tenantUserIds = tenantRows
            .map((r) => r['user_id'])
            .where((v) => v != null)
            .map<String>((v) => v.toString())
            .toSet()
            .toList();
        if (tenantUserIds.isNotEmpty) {
          // filter to role=tenant
          final userRows = await _supabase
              .from('users')
              .select('user_id')
              .inFilter('user_id', tenantUserIds)
              .eq('role', 'tenant');
          final candidateUserIds = List<Map<String, dynamic>>.from(userRows)
              .map((r) => r['user_id'])
              .where((v) => v != null)
              .map<String>((v) => v.toString())
              .toSet()
              .toList();
          if (candidateUserIds.isNotEmpty) {
            // exclude any that appear in branch_managers (any branch)
            final bmRows = await _supabase
                .from('branch_managers')
                .select('user_id')
                .inFilter('user_id', candidateUserIds);
            final bmUserIds = List<Map<String, dynamic>>.from(bmRows)
                .map((r) => r['user_id'])
                .where((v) => v != null)
                .map<String>((v) => v.toString())
                .toSet();
            final deleteUserIds = candidateUserIds
                .where((id) => !bmUserIds.contains(id))
                .toList();
            if (deleteUserIds.isNotEmpty) {
              await _supabase
                  .from('user_sessions')
                  .delete()
                  .inFilter('user_id', deleteUserIds);
              await _supabase
                  .from('users')
                  .delete()
                  .inFilter('user_id', deleteUserIds);
            }
          }
        }
      } catch (_) {}

      // 12) Finally delete the branch itself
      await _supabase.from('branches').delete().eq('branch_id', branchId);

      return {
        'success': true,
        'message': 'ลบสาขา "${existingBranch['branch_name']}" ถาวรสำเร็จ',
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบสาขาที่ต้องการลบ';
      } else if (e.code == '23503') {
        // Foreign key constraint
        message = 'ไม่สามารถลบสาขาได้ เนื่องจากยังมีข้อมูลที่เกี่ยวข้อง';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบสาขาถาวร: ${e.toString()}',
      };
    }
  }

  // Toggle branch status
  static Future<Map<String, dynamic>> toggleBranchStatus(
      String branchId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // ตรวจสอบ branchId
      if (branchId.isEmpty) {
        return {
          'success': false,
          'message': 'ไม่พบรหัสสาขา',
        };
      }

      // Check permissions - admin และ superadmin สามารถเปิด/ปิดใช้งานได้
      if (currentUser.userRole != UserRole.superAdmin &&
          currentUser.userRole != UserRole.admin) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการเปลี่ยนสถานะสาขา',
        };
      }

      // ตรวจสอบว่าสาขานี้มีอยู่จริงหรือไม่
      final existingBranch = await _supabase
          .from('branches')
          .select('branch_id, branch_name, is_active')
          .eq('branch_id', branchId)
          .maybeSingle();

      if (existingBranch == null) {
        return {
          'success': false,
          'message': 'ไม่พบสาขาที่ต้องการ',
        };
      }

      final currentStatus = existingBranch['is_active'] ?? false;
      final newStatus = !currentStatus;

      // อัปเดตสถานะ
      final result = await _supabase
          .from('branches')
          .update({
            'is_active': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('branch_id', branchId)
          .select()
          .single();

      return {
        'success': true,
        'message': newStatus
            ? 'เปิดใช้งานสาขา "${existingBranch['branch_name']}" สำเร็จ'
            : 'ปิดใช้งานสาขา "${existingBranch['branch_name']}" สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      String message = 'เกิดข้อผิดพลาด: ${e.message}';

      if (e.code == 'PGRST116') {
        message = 'ไม่พบสาขาที่ต้องการ';
      }

      return {
        'success': false,
        'message': message,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเปลี่ยนสถานะสาขา: ${e.toString()}',
      };
    }
  }

  // Get branch statistics
  static Future<Map<String, dynamic>> getBranchStatistics(
      String branchId) async {
    try {
      // Get total rooms count
      final totalRooms = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', branchId)
          .eq('is_active', true);

      // Get occupied rooms count
      final occupiedRooms = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', branchId)
          .eq('room_status', 'occupied')
          .eq('is_active', true);

      // Get available rooms count
      final availableRooms = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', branchId)
          .eq('room_status', 'available')
          .eq('is_active', true);

      // Get maintenance rooms count
      final maintenanceRooms = await _supabase
          .from('rooms')
          .select('room_id')
          .eq('branch_id', branchId)
          .eq('room_status', 'maintenance')
          .eq('is_active', true);

      // Calculate occupancy rate
      final occupancyRate = totalRooms.length > 0
          ? (occupiedRooms.length / totalRooms.length * 100).round()
          : 0;

      return {
        'total_rooms': totalRooms.length,
        'occupied_rooms': occupiedRooms.length,
        'available_rooms': availableRooms.length,
        'maintenance_rooms': maintenanceRooms.length,
        'occupancy_rate': occupancyRate,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติสาขา: $e');
    }
  }

  // Search branches - updated to use view
  static Future<List<Map<String, dynamic>>> searchBranches(
      String searchQuery) async {
    try {
      if (searchQuery.trim().isEmpty) {
        return [];
      }

      final result = await _supabase
          .from('branches_with_managers')
          .select('*')
          .or('branch_name.ilike.%$searchQuery%,'
              'branch_code.ilike.%$searchQuery%,'
              'primary_manager_name.ilike.%$searchQuery%,'
              'branch_address.ilike.%$searchQuery%')
          .eq('is_active', true)
          .order('branch_name')
          .limit(20);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการค้นหาสาขา: $e');
    }
  }

  // Get active branches for public access
  static Future<List<Map<String, dynamic>>> getActiveBranches() async {
    try {
      final result = await _supabase
          .from('branches_with_managers')
          .select('*')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลสาขา: $e');
    }
  }
}
