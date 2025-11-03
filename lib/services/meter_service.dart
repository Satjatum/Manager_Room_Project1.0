import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/user_models.dart';
// Images no longer used for meter readings per new requirements

class MeterReadingService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================
  // READ OPERATIONS
  // ============================================

  /// ดึงรายการบันทึกค่ามิเตอร์ตามสิทธิ์ผู้ใช้
  static Future<List<Map<String, dynamic>>> getMeterReadingsByUser({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    String? roomId,
    String? tenantId,
    String? status,
    int? readingMonth,
    int? readingYear,
    bool? includeInitial,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    final currentUser = await AuthService.getCurrentUser();
    if (currentUser == null) return [];

    // SuperAdmin เห็นทุกสาขา
    if (currentUser.userRole == UserRole.superAdmin) {
      return getAllMeterReadings(
        offset: offset,
        limit: limit,
        searchQuery: searchQuery,
        branchId: branchId,
        roomId: roomId,
        tenantId: tenantId,
        status: status,
        readingMonth: readingMonth,
        readingYear: readingYear,
        includeInitial: includeInitial,
        orderBy: orderBy,
        ascending: ascending,
      );
    }

    // Admin: จำกัดเฉพาะสาขาที่ตนดูแล
    if (currentUser.userRole == UserRole.admin) {
      // ดึงสาขาที่ดูแลจาก branch_managers
      final managedRows = await _supabase
          .from('branch_managers')
          .select('branch_id')
          .eq('user_id', currentUser.userId);
      final managedIds = List<Map<String, dynamic>>.from(managedRows)
          .map((r) => r['branch_id'])
          .where((id) => id != null)
          .map<String>((id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList();

      if (managedIds.isEmpty) return [];

      // ถ้าเลือกสาขามาและไม่ใช่สาขาที่ดูแล → ไม่คืนข้อมูล
      if (branchId != null &&
          branchId.isNotEmpty &&
          !managedIds.contains(branchId)) {
        return [];
      }

      // หากระบุ branchId ที่อยู่ในสิทธิ์ก็ให้ส่งต่อ filter นั้น
      if (branchId != null && branchId.isNotEmpty) {
        return getAllMeterReadings(
          offset: offset,
          limit: limit,
          searchQuery: searchQuery,
          branchId: branchId,
          roomId: roomId,
          tenantId: tenantId,
          status: status,
          readingMonth: readingMonth,
          readingYear: readingYear,
          includeInitial: includeInitial,
          orderBy: orderBy,
          ascending: ascending,
        );
      }

      // ไม่ได้ระบุสาขา: โหลดทั้งหมดแล้วกรองด้วย managedIds ในหน่วยความจำ
      final all = await getAllMeterReadings(
        offset: offset,
        limit: limit,
        searchQuery: searchQuery,
        branchId: null,
        roomId: roomId,
        tenantId: tenantId,
        status: status,
        readingMonth: readingMonth,
        readingYear: readingYear,
        includeInitial: includeInitial,
        orderBy: orderBy,
        ascending: ascending,
      );
      return all.where((r) => managedIds.contains(r['branch_id'])).toList();
    }

    // บทบาทอื่นๆ ให้เห็นตาม branchId ที่ระบุเท่านั้น (ถ้ามี)
    return getAllMeterReadings(
      offset: offset,
      limit: limit,
      searchQuery: searchQuery,
      branchId: branchId ?? currentUser.branchId,
      roomId: roomId,
      tenantId: tenantId,
      status: status,
      readingMonth: readingMonth,
      readingYear: readingYear,
      includeInitial: includeInitial,
      orderBy: orderBy,
      ascending: ascending,
    );
  }

  /// ดึงรายการบันทึกค่ามิเตอร์ทั้งหมด
  static Future<List<Map<String, dynamic>>> getAllMeterReadings({
    int offset = 0,
    int limit = 100,
    String? searchQuery,
    String? branchId,
    String? roomId,
    String? tenantId,
    String? status,
    int? readingMonth,
    int? readingYear,
    bool? includeInitial, // เพิ่ม filter สำหรับ initial reading
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    try {
      var query = _supabase.from('meter_readings').select('''
        *,
        rooms!inner(room_id, room_number, branch_id, 
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone),
        rental_contracts!inner(contract_id, contract_num)
      ''');

      // Add filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('reading_number.ilike.%$searchQuery%');
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      if (roomId != null && roomId.isNotEmpty) {
        query = query.eq('room_id', roomId);
      }

      if (tenantId != null && tenantId.isNotEmpty) {
        query = query.eq('tenant_id', tenantId);
      }

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('reading_status', status);
      }

      if (readingMonth != null) {
        query = query.eq('reading_month', readingMonth);
      }

      if (readingYear != null) {
        query = query.eq('reading_year', readingYear);
      }

      // Filter initial readings
      if (includeInitial != null) {
        query = query.eq('is_initial_reading', includeInitial);
      }

      // Add ordering and pagination
      final result = await query
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(result).map((reading) {
        return {
          ...reading,
          'branch_id': reading['rooms']?['branch_id'],
          'tenant_name': reading['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': reading['tenants']?['tenant_phone'] ?? '-',
          'room_number': reading['rooms']?['room_number'] ?? '-',
          'branch_name': reading['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': reading['rental_contracts']?['contract_num'] ?? '-',
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  /// ดึงข้อมูลค่ามิเตอร์ตาม ID
  static Future<Map<String, dynamic>?> getMeterReadingById(
      String readingId) async {
    try {
      final result = await _supabase.from('meter_readings').select('''
        *,
        rooms!inner(room_id, room_number, room_price, branch_id,
          branches!inner(branch_name, branch_code)),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone, tenant_idcard),
        rental_contracts!inner(contract_id, contract_num, contract_price)
      ''').eq('reading_id', readingId).maybeSingle();

      if (result != null) {
        return {
          ...result,
          'branch_id': result['rooms']?['branch_id'],
          'tenant_name': result['tenants']?['tenant_fullname'] ?? '-',
          'tenant_phone': result['tenants']?['tenant_phone'] ?? '-',
          'room_number': result['rooms']?['room_number'] ?? '-',
          'branch_name': result['rooms']?['branches']?['branch_name'] ?? '-',
          'contract_num': result['rental_contracts']?['contract_num'] ?? '-',
        };
      }

      return null;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูลค่ามิเตอร์: $e');
    }
  }

  /// ดึงค่ามิเตอร์ล่าสุดของห้อง (ไม่รวม Initial Reading)
  static Future<Map<String, dynamic>?> getLastMeterReading(
      String roomId) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false) // ไม่เอา initial reading
          .eq('reading_status', 'confirmed')
          .order('reading_year', ascending: false)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดค่ามิเตอร์ล่าสุด: $e');
    }
  }

  /// ดึงค่ามิเตอร์ล่าสุดที่ "ออกบิลแล้ว" ของห้อง
  static Future<Map<String, dynamic>?> getLastBilledMeterReading(
      String roomId) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .eq('reading_status', 'billed')
          .order('reading_year', ascending: false)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดค่ามิเตอร์ที่ออกบิลล่าสุด: $e');
    }
  }

  /// ดึง Initial Reading ของห้อง (ถ้ามี)
  static Future<Map<String, dynamic>?> getInitialReading(String roomId) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', true)
          .maybeSingle();

      return result;
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดค่าฐานเริ่มต้น: $e');
    }
  }

  /// ตรวจสอบว่ามีการบันทึกค่ามิเตอร์สำหรับเดือนและปีนี้แล้วหรือไม่
  static Future<bool> hasReadingForMonth(
      String roomId, int month, int year,
      {List<String>? statuses}) async {
    try {
      // Build filters first, then apply limit at the end (to keep filter builder type)
      var query = _supabase
          .from('meter_readings')
          .select('reading_id')
          .eq('room_id', roomId)
          .eq('reading_month', month)
          .eq('reading_year', year)
          .eq('is_initial_reading', false); // ไม่นับ initial reading

      if (statuses != null && statuses.isNotEmpty) {
        query = query.inFilter('reading_status', statuses);
      }

      final result = await query.limit(1);
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // CREATE OPERATION
  // ============================================

  /// สร้างบันทึกค่ามิเตอร์ใหม่ (รองรับ Initial Reading)
  static Future<Map<String, dynamic>> createMeterReading(
      Map<String, dynamic> readingData) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // ตรวจสอบสิทธิ์
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการบันทึกค่ามิเตอร์'
        };
      }

      // Validate required fields
      if (readingData['room_id'] == null || readingData['room_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกห้อง'};
      }

      if (readingData['tenant_id'] == null ||
          readingData['tenant_id'].isEmpty) {
        return {'success': false, 'message': 'กรุณาเลือกผู้เช่า'};
      }

      final isInitialReading = readingData['is_initial_reading'] ?? false;

      // Validation ตามประเภท
      if (isInitialReading) {
        // Initial Reading - ตรวจสอบว่าไม่มีค่าเริ่มต้นอยู่แล้ว
        final existingInitial = await getInitialReading(readingData['room_id']);
        if (existingInitial != null) {
          return {
            'success': false,
            'message': 'ห้องนี้มีค่าฐานเริ่มต้นอยู่แล้ว'
          };
        }
      } else {
        // Normal Reading - ต้องมีเดือน/ปี
        if (readingData['reading_month'] == null) {
          return {'success': false, 'message': 'กรุณาระบุเดือนที่บันทึก'};
        }

        if (readingData['reading_year'] == null) {
          return {'success': false, 'message': 'กรุณาระบุปีที่บันทึก'};
        }

        // ตรวจสอบว่ามีการบันทึกสำหรับเดือนนี้แล้วหรือไม่ (นับเฉพาะที่ยืนยันแล้ว/ออกบิลแล้ว)
        final hasExistingConfirmed = await hasReadingForMonth(
          readingData['room_id'],
          readingData['reading_month'],
          readingData['reading_year'],
          statuses: ['confirmed', 'billed'],
        );

        if (hasExistingConfirmed) {
          return {
            'success': false,
            'message': 'มีการบันทึกค่ามิเตอร์สำหรับเดือนนี้แล้ว'
          };
        }
      }

      // สร้างเลขที่บันทึก
      final readingNumber = await _generateReadingNumber(isInitialReading);

      // เตรียมข้อมูลสำหรับบันทึก
      Map<String, dynamic> insertData;

      if (isInitialReading) {
        // Initial Reading - ไม่มีเดือน/ปี, usage = 0
        final waterCurrent = readingData['water_current_reading'] ?? 0.0;
        final electricCurrent = readingData['electric_current_reading'] ?? 0.0;

        insertData = {
          'reading_number': readingNumber,
          'room_id': readingData['room_id'],
          'tenant_id': readingData['tenant_id'],
          'contract_id': readingData['contract_id'],
          'is_initial_reading': true,
          'reading_month': null, // ไม่มีเดือน
          'reading_year': null, // ไม่มีปี
          'water_previous_reading': waterCurrent,
          'water_current_reading': waterCurrent,
          'water_usage': 0.0,
          'electric_previous_reading': electricCurrent,
          'electric_current_reading': electricCurrent,
          'electric_usage': 0.0,
          'reading_status': 'confirmed', // Auto-confirm
          'reading_date': readingData['reading_date'] ??
              DateTime.now().toIso8601String().split('T')[0],
          'reading_notes': readingData['reading_notes'],
          'created_by': currentUser.userId,
          'confirmed_by': currentUser.userId,
          'confirmed_at': DateTime.now().toIso8601String(),
        };
      } else {
        // Normal Reading - มีเดือน/ปี, คำนวณ usage
        int targetMonth = readingData['reading_month'];
        int targetYear = readingData['reading_year'];

        // ใช้ค่าก่อนหน้าจากรายการก่อนหน้า (เดือนก่อนหน้า/รายการล่าสุดก่อนเดือนนี้)
        // เพื่อให้ความต่อเนื่อง: ค่าปัจจุบันของเดือนก่อนหน้า = ค่าก่อนหน้าของเดือนนี้
        final prev = await _getPrevReading(
            readingData['room_id'], targetMonth, targetYear);
        final waterPrevious = prev != null
            ? (prev['water_current_reading'] ?? 0.0).toDouble()
            : (readingData['water_previous_reading'] ?? 0.0);
        final electricPrevious = prev != null
            ? (prev['electric_current_reading'] ?? 0.0).toDouble()
            : (readingData['electric_previous_reading'] ?? 0.0);
        final waterCurrent = readingData['water_current_reading'] ?? 0.0;
        final electricCurrent = readingData['electric_current_reading'] ?? 0.0;

        final waterUsage = waterCurrent - waterPrevious;
        final electricUsage = electricCurrent - electricPrevious;

        // Validation
        if (waterUsage <= 0) {
          return {
            'success': false,
            'message': 'ค่ามิเตอร์น้ำปัจจุบันต้องมากกว่าค่าก่อนหน้า'
          };
        }

        if (electricUsage <= 0) {
          return {
            'success': false,
            'message': 'ค่ามิเตอร์ไฟปัจจุบันต้องมากกว่าค่าก่อนหน้า'
          };
        }

        insertData = {
          'reading_number': readingNumber,
          'room_id': readingData['room_id'],
          'tenant_id': readingData['tenant_id'],
          'contract_id': readingData['contract_id'],
          'is_initial_reading': false,
          'reading_month': targetMonth,
          'reading_year': targetYear,
          'water_previous_reading': waterPrevious,
          'water_current_reading': waterCurrent,
          'water_usage': waterUsage,
          'electric_previous_reading': electricPrevious,
          'electric_current_reading': electricCurrent,
          'electric_usage': electricUsage,
          // สร้างแล้วเป็นสถานะยืนยันทันทีตามข้อกำหนดใหม่
          'reading_status': 'confirmed',
          'reading_date': readingData['reading_date'] ??
              DateTime.now().toIso8601String().split('T')[0],
          'reading_notes': readingData['reading_notes'],
          'created_by': currentUser.userId,
          'confirmed_by': currentUser.userId,
          'confirmed_at': DateTime.now().toIso8601String(),
        };
      }

      final result = await _supabase
          .from('meter_readings')
          .insert(insertData)
          .select()
          .single();

      return {
        'success': true,
        'message': isInitialReading
            ? 'บันทึกค่าฐานเริ่มต้นสำเร็จ'
            : 'บันทึกค่ามิเตอร์สำเร็จ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการบันทึกค่ามิเตอร์: $e',
      };
    }
  }

  // ============================================
  // UPDATE OPERATIONS
  // ============================================

  /// อัปเดตค่ามิเตอร์
  static Future<Map<String, dynamic>> updateMeterReading(
    String readingId,
    Map<String, dynamic> readingData,
  ) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการแก้ไขค่ามิเตอร์'};
      }

      // ตรวจสอบสถานะ
      final existing = await getMeterReadingById(readingId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลค่ามิเตอร์'};
      }

      // อนุญาตให้แก้ไขได้ตลอดตามข้อกำหนดใหม่
      final isInitialReading = existing['is_initial_reading'] ?? false;

      Map<String, dynamic> updateData;
      // เตรียม warnings ให้ใช้ได้ทุกกรณี (ทั้ง initial และ normal)
      final List<Map<String, dynamic>> warnings = [];

      if (isInitialReading) {
        // Initial Reading - อัปเดตค่าเดียวกัน
        final waterCurrent = readingData['water_current_reading'] ??
            existing['water_current_reading'] ??
            0.0;
        final electricCurrent = readingData['electric_current_reading'] ??
            existing['electric_current_reading'] ??
            0.0;

        updateData = {
          'water_previous_reading': waterCurrent,
          'water_current_reading': waterCurrent,
          'water_usage': 0.0,
          'electric_previous_reading': electricCurrent,
          'electric_current_reading': electricCurrent,
          'electric_usage': 0.0,
          'reading_date': readingData['reading_date'],
          'reading_notes': readingData['reading_notes'],
        };
      } else {
        // Normal Reading - คำนวณใหม่
        final waterPrevious = readingData['water_previous_reading'] ??
            existing['water_previous_reading'] ??
            0.0;
        final waterCurrent = readingData['water_current_reading'] ??
            existing['water_current_reading'] ??
            0.0;
        final electricPrevious = readingData['electric_previous_reading'] ??
            existing['electric_previous_reading'] ??
            0.0;
        final electricCurrent = readingData['electric_current_reading'] ??
            existing['electric_current_reading'] ??
            0.0;

        final waterUsage = waterCurrent - waterPrevious;
        final electricUsage = electricCurrent - electricPrevious;

        if (waterUsage <= 0) {
          return {
            'success': false,
            'message': 'ค่ามิเตอร์น้ำปัจจุบันต้องมากกว่าค่าก่อนหน้า'
          };
        }

        if (electricUsage <= 0) {
          return {
            'success': false,
            'message': 'ค่ามิเตอร์ไฟปัจจุบันต้องมากกว่าค่าก่อนหน้า'
          };
        }

        // แก้ไขย้อนหลัง: ลบข้อมูลเดือนถัดไปอัตโนมัติถ้าสามารถลบได้ (ไม่ใช่ billed)
        final int? month = existing['reading_month'];
        final int? year = existing['reading_year'];
        final String roomId = existing['room_id'];
        if (month != null && year != null && roomId.isNotEmpty) {
          final nextList = await _getNextReadings(roomId, month, year);
          for (final r in nextList) {
            if (r['reading_status'] == 'billed') {
              // ไม่สามารถลบได้ → แจ้งเตือนข้อมูลอาจไม่ต่อเนื่องแล้ว
              warnings.add({
                'type': 'locked_conflict',
                'reading_id': r['reading_id'],
                'message': 'พบข้อมูลเดือนถัดไปที่ออกบิลแล้ว ไม่สามารถลบเพื่อให้ค่าต่อเนื่องได้'
              });
              break; // หยุดที่ตัวแรกที่ลบไม่ได้
            }
            // ลบรายการถัดไปที่ยังไม่ billed
            await _supabase
                .from('meter_readings')
                .delete()
                .eq('reading_id', r['reading_id']);
          }
        }

        updateData = {
          'water_previous_reading': waterPrevious,
          'water_current_reading': waterCurrent,
          'water_usage': waterUsage,
          'electric_previous_reading': electricPrevious,
          'electric_current_reading': electricCurrent,
          'electric_usage': electricUsage,
          'reading_date': readingData['reading_date'],
          'reading_notes': readingData['reading_notes'],
        };
      }

      updateData.removeWhere((key, value) => value == null);

      final result = await _supabase
          .from('meter_readings')
          .update(updateData)
          .eq('reading_id', readingId)
          .select()
          .single();

      return {
        'success': true,
        'message': 'อัปเดตค่ามิเตอร์สำเร็จ',
        'data': result,
        'warnings': warnings,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการอัปเดตค่ามิเตอร์: $e',
      };
    }
  }

  /// ยืนยันค่ามิเตอร์
  static Future<Map<String, dynamic>> confirmMeterReading(
      String readingId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการยืนยันค่ามิเตอร์'
        };
      }

      // ตรวจสอบว่าเป็น Initial Reading หรือไม่
      final reading = await getMeterReadingById(readingId);
      if (reading != null && reading['is_initial_reading'] == true) {
        return {
          'success': false,
          'message': 'ค่าฐานเริ่มต้นถูกยืนยันอัตโนมัติแล้ว'
        };
      }

      await _supabase.from('meter_readings').update({
        'reading_status': 'confirmed',
        'confirmed_by': currentUser.userId,
        'confirmed_at': DateTime.now().toIso8601String(),
      }).eq('reading_id', readingId);

      return {
        'success': true,
        'message': 'ยืนยันค่ามิเตอร์สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการยืนยันค่ามิเตอร์: $e',
      };
    }
  }

  /// ยกเลิกค่ามิเตอร์
  static Future<Map<String, dynamic>> cancelMeterReading(
      String readingId, String reason) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {
          'success': false,
          'message': 'ไม่มีสิทธิ์ในการยกเลิกค่ามิเตอร์'
        };
      }

      await _supabase.from('meter_readings').update({
        'reading_status': 'cancelled',
        'reading_notes': reason,
      }).eq('reading_id', readingId);

      return {
        'success': true,
        'message': 'ยกเลิกค่ามิเตอร์สำเร็จ',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการยกเลิกค่ามิเตอร์: $e',
      };
    }
  }

  // ============================================
  // DELETE OPERATION
  // ============================================

  /// ลบค่ามิเตอร์
  static Future<Map<String, dynamic>> deleteMeterReading(
      String readingId) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // อนุญาตให้ผู้ใช้ที่มีสิทธิ์จัดการค่ามิเตอร์ หรือ SuperAdmin สามารถลบได้
      if (!currentUser.hasAnyPermission([
        DetailedPermission.all,
        DetailedPermission.manageMeterReadings,
      ])) {
        return {'success': false, 'message': 'ไม่มีสิทธิ์ในการลบค่ามิเตอร์'};
      }

      final existing = await getMeterReadingById(readingId);
      if (existing == null) {
        return {'success': false, 'message': 'ไม่พบข้อมูลค่ามิเตอร์'};
      }

      // Initial Reading สามารถลบได้เสมอ
      final isInitialReading = existing['is_initial_reading'] ?? false;

      if (!isInitialReading) {
        // Normal Reading - อนุญาตให้ลบที่ confirmed/draft/cancelled ได้ แต่ไม่อนุญาตลบที่ออกบิลแล้ว
        if (existing['reading_status'] == 'billed') {
          return {
            'success': false,
            'message': 'ไม่สามารถลบค่ามิเตอร์ที่ออกบิลแล้ว'
          };
        }
      }

      // ลบข้อมูล
      await _supabase
          .from('meter_readings')
          .delete()
          .eq('reading_id', readingId);

      // ลบเดือนถัดไปทั้งหมดที่ยังไม่ billed เพื่อให้ความต่อเนื่อง
      final int? month = existing['reading_month'];
      final int? year = existing['reading_year'];
      final String roomId = existing['room_id'];
      final List<Map<String, dynamic>> warnings = [];
      if (!isInitialReading && month != null && year != null && roomId.isNotEmpty) {
        final nextList = await _getNextReadings(roomId, month, year);
        for (final r in nextList) {
          if (r['reading_status'] == 'billed') {
            // ไม่สามารถลบได้ ให้เตือน
            warnings.add({
              'type': 'locked_conflict',
              'reading_id': r['reading_id'],
              'message': 'พบข้อมูลเดือนถัดไปที่ออกบิลแล้ว ไม่สามารถลบเพื่อให้ค่าต่อเนื่องได้'
            });
            break;
          }
          await _supabase
              .from('meter_readings')
              .delete()
              .eq('reading_id', r['reading_id']);
        }
      }

      return {
        'success': true,
        'message':
            isInitialReading ? 'ลบค่าฐานเริ่มต้นสำเร็จ' : 'ลบค่ามิเตอร์สำเร็จ',
        'warnings': warnings,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการลบค่ามิเตอร์: $e',
      };
    }
  }

  // ============================================
  // UTILITY FUNCTIONS
  // ============================================

  /// สร้างเลขที่บันทึกอัตโนมัติ
  static Future<String> _generateReadingNumber(bool isInitialReading) async {
    if (isInitialReading) {
      // Initial Reading ใช้ prefix พิเศษ
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'INIT${timestamp.toString().substring(timestamp.toString().length - 8)}';
    }

    // Normal Reading
    final now = DateTime.now();
    final prefix = 'MR${now.year}${now.month.toString().padLeft(2, '0')}';

    final lastReading = await _supabase
        .from('meter_readings')
        .select('reading_number')
        .like('reading_number', '$prefix%')
        .order('reading_number', ascending: false)
        .limit(1)
        .maybeSingle();

    int nextNumber = 1;
    if (lastReading != null) {
      final lastNum = lastReading['reading_number'].toString();
      final numPart = lastNum.substring(prefix.length);
      nextNumber = (int.tryParse(numPart) ?? 0) + 1;
    }

    return '$prefix${nextNumber.toString().padLeft(4, '0')}';
  }

  /// ดึงห้องที่มีสัญญาเช่าใช้งานอยู่
  static Future<List<Map<String, dynamic>>> getActiveRoomsForMeterReading({
    String? branchId,
  }) async {
    try {
      var query = _supabase.from('rental_contracts').select('''
        contract_id,
        rooms!inner(room_id, room_number, branch_id,
          branches!inner(branch_name),
          room_categories!inner(roomcate_id, roomcate_name)
        ),
        tenants!inner(tenant_id, tenant_fullname, tenant_phone)
      ''').eq('contract_status', 'active');

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('rooms.branch_id', branchId);
      }

      final result = await query;

      final sortedResult = List<Map<String, dynamic>>.from(result);
      sortedResult.sort((a, b) {
        final roomNumberA = a['rooms']?['room_number']?.toString() ?? '';
        final roomNumberB = b['rooms']?['room_number']?.toString() ?? '';
        return roomNumberA.compareTo(roomNumberB);
      });

      return sortedResult.map((contract) {
        return {
          'contract_id': contract['contract_id'],
          'room_id': contract['rooms']['room_id'],
          'room_number': contract['rooms']['room_number'],
          'branch_name': contract['rooms']['branches']['branch_name'],
          'room_category_name': contract['rooms']?['room_categories']?['roomcate_name'],
          'tenant_id': contract['tenants']['tenant_id'],
          'tenant_name': contract['tenants']['tenant_fullname'],
          'tenant_phone': contract['tenants']['tenant_phone'],
        };
      }).toList();
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดห้องที่ใช้งาน: $e');
    }
  }

  /// ดึงสถิติค่ามิเตอร์
  static Future<Map<String, dynamic>> getMeterReadingStats({
    String? branchId,
    int? month,
    int? year,
    bool includeInitial = false,
  }) async {
    try {
      var query = _supabase
          .from('meter_readings')
          .select('reading_status, is_initial_reading');

      if (branchId != null) {
        query = _supabase.from('meter_readings').select('''
          reading_status,
          is_initial_reading,
          rooms!inner(branch_id)
        ''').eq('rooms.branch_id', branchId);
      }

      if (month != null) {
        query = query.eq('reading_month', month);
      }

      if (year != null) {
        query = query.eq('reading_year', year);
      }

      if (!includeInitial) {
        query = query.eq('is_initial_reading', false);
      }

      final result = await query;

      final total = result.length;
      final initial =
          result.where((r) => r['is_initial_reading'] == true).length;
      final draft = result
          .where((r) =>
              r['is_initial_reading'] == false &&
              r['reading_status'] == 'draft')
          .length;
      final confirmed = result
          .where((r) =>
              r['is_initial_reading'] == false &&
              r['reading_status'] == 'confirmed')
          .length;
      final billed =
          result.where((r) => r['reading_status'] == 'billed').length;
      final cancelled =
          result.where((r) => r['reading_status'] == 'cancelled').length;

      return {
        'total': total,
        'initial': initial,
        'draft': draft,
        'confirmed': confirmed,
        'billed': billed,
        'cancelled': cancelled,
      };
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดสถิติ: $e');
    }
  }

  /// ตรวจสอบว่าค่ามิเตอร์ปัจจุบันมากกว่าค่าก่อนหน้าหรือไม่
  static bool validateMeterReading({
    required double previousReading,
    required double currentReading,
  }) {
    return currentReading > previousReading;
  }

  /// คำนวณการใช้งาน
  static double calculateUsage({
    required double previousReading,
    required double currentReading,
  }) {
    return currentReading - previousReading;
  }

  /// แนะนำค่าก่อนหน้าจากการบันทึกล่าสุด หรือจาก Initial Reading
  static Future<Map<String, dynamic>?> getSuggestedPreviousReadings(
      String roomId) async {
    try {
      // ลองหาค่าจากบันทึกล่าสุด
      final lastReading = await getLastMeterReading(roomId);

      if (lastReading != null) {
        return {
          'water_previous': lastReading['water_current_reading'] ?? 0.0,
          'electric_previous': lastReading['electric_current_reading'] ?? 0.0,
          'last_reading_date': lastReading['reading_date'],
          'last_reading_month': lastReading['reading_month'],
          'last_reading_year': lastReading['reading_year'],
          'source': 'last_reading',
        };
      }

      // ถ้าไม่มี ลองหาจาก Initial Reading
      final initialReading = await getInitialReading(roomId);
      if (initialReading != null) {
        return {
          'water_previous': initialReading['water_current_reading'] ?? 0.0,
          'electric_previous':
              initialReading['electric_current_reading'] ?? 0.0,
          'last_reading_date': initialReading['reading_date'],
          'source': 'initial_reading',
        };
      }

      return null;
    } catch (e) {
      print('Error getting suggested previous readings: $e');
      return null;
    }
  }

  /// ค่าก่อนหน้าสำหรับเดือน/ปีที่เลือก: คืนค่าปัจจุบันของเดือนก่อนหน้าเป็น "ก่อนหน้า"
  /// กรณีหาไม่เจอ ให้ fallback เป็น Initial Reading ถ้ามี
  static Future<Map<String, dynamic>?> getPreviousForMonth(
      String roomId, int targetMonth, int targetYear) async {
    try {
      // หาในปีเดียวกัน ที่เดือนน้อยกว่า (เฉพาะที่ยืนยันแล้ว/ออกบิลแล้ว)
      final sameYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .inFilter('reading_status', ['confirmed', 'billed'])
          .eq('reading_year', targetYear)
          .lt('reading_month', targetMonth)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();
      if (sameYear != null) {
        return {
          'water_previous': (sameYear['water_current_reading'] ?? 0.0).toDouble(),
          'electric_previous':
              (sameYear['electric_current_reading'] ?? 0.0).toDouble(),
          'source': 'prev_month_same_year',
        };
      }

      // หาในปีก่อนหน้า (เฉพาะที่ยืนยันแล้ว/ออกบิลแล้ว)
      final prevYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .inFilter('reading_status', ['confirmed', 'billed'])
          .lt('reading_year', targetYear)
          .order('reading_year', ascending: false)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();
      if (prevYear != null) {
        return {
          'water_previous': (prevYear['water_current_reading'] ?? 0.0).toDouble(),
          'electric_previous':
              (prevYear['electric_current_reading'] ?? 0.0).toDouble(),
          'source': 'prev_month_prev_year',
        };
      }

      // Fallback: ใช้ Initial Reading ถ้ามี
      final initial = await getInitialReading(roomId);
      if (initial != null) {
        return {
          'water_previous': (initial['water_current_reading'] ?? 0.0).toDouble(),
          'electric_previous':
              (initial['electric_current_reading'] ?? 0.0).toDouble(),
          'source': 'initial_reading',
        };
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// หาเดือนถัดไปของห้องเดียวกัน (ไม่นับ Initial)
  static Future<Map<String, dynamic>?> _getNextReading(
      String roomId, int month, int year) async {
    try {
      // ลองหาในปีเดียวกัน เดือนที่มากกว่า
      final sameYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .eq('reading_year', year)
          .gt('reading_month', month)
          .order('reading_month', ascending: true)
          .limit(1)
          .maybeSingle();
      if (sameYear != null) return sameYear;

      // ถ้าไม่มี ให้หาในปีถัดไป
      final nextYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .gt('reading_year', year)
          .order('reading_year', ascending: true)
          .order('reading_month', ascending: true)
          .limit(1)
          .maybeSingle();
      return nextYear;
    } catch (e) {
      return null;
    }
  }

  /// หาเดือนก่อนหน้าของห้องเดียวกันที่อยู่ก่อน (ไม่นับ Initial)
  static Future<Map<String, dynamic>?> _getPrevReading(
      String roomId, int month, int year) async {
    try {
      // หาในปีเดียวกัน ที่เดือนน้อยกว่า
      final sameYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .inFilter('reading_status', ['confirmed', 'billed'])
          .eq('reading_year', year)
          .lt('reading_month', month)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();
      if (sameYear != null) return sameYear;

      // หาในปีก่อนหน้า
      final prevYear = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .inFilter('reading_status', ['confirmed', 'billed'])
          .lt('reading_year', year)
          .order('reading_year', ascending: false)
          .order('reading_month', ascending: false)
          .limit(1)
          .maybeSingle();
      return prevYear;
    } catch (e) {
      return null;
    }
  }

  /// ลิสต์เดือนถัดไปทั้งหมดเรียงตามเวลา (ไม่นับ Initial)
  static Future<List<Map<String, dynamic>>> _getNextReadings(
      String roomId, int month, int year) async {
    try {
      final result = await _supabase
          .from('meter_readings')
          .select('*')
          .eq('room_id', roomId)
          .eq('is_initial_reading', false)
          .or('reading_year.gt.$year,reading_year.eq.$year')
          .order('reading_year', ascending: true)
          .order('reading_month', ascending: true);
      // กรองให้เหลือจริงๆ เฉพาะที่มากกว่าคู่เดือน/ปี
      return List<Map<String, dynamic>>.from(result).where((r) {
        final y = (r['reading_year'] ?? 0) as int;
        final m = (r['reading_month'] ?? 0) as int;
        return (y > year) || (y == year && m > month);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
