import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'invoice_service.dart';
import 'branch_service.dart';

class PaymentService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Load active payment QR/accounts of a branch for tenant display
  static Future<List<Map<String, dynamic>>> getBranchQRCodes(
      String branchId) async {
    try {
      final result = await _supabase
          .from('branch_payment_qr')
          .select('*')
          .eq('branch_id', branchId)
          .eq('is_active', true)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('ไม่สามารถโหลดข้อมูลช่องทางชำระเงินของสาขาได้: $e');
    }
  }

  // Simulate PromptPay success (test mode): create payment directly and update invoice
  static Future<Map<String, dynamic>> createPromptPayTestPayment({
    required String invoiceId,
    required double paidAmount,
    String? qrId,
    String? notes,
  }) async {
    try {
      if (paidAmount <= 0) {
        return {'success': false, 'message': 'จำนวนเงินต้องมากกว่า 0'};
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // Load invoice to get tenant_id and branch_id
      final invoice = await InvoiceService.getInvoiceById(invoiceId);
      if (invoice == null) {
        return {'success': false, 'message': 'ไม่พบบิล'};
      }
      final tenantId =
          (invoice['tenant_id'] ?? invoice['tenants']?['tenant_id'])
              ?.toString();
      if (tenantId == null || tenantId.isEmpty) {
        return {'success': false, 'message': 'ไม่พบข้อมูลผู้เช่าในบิล'};
      }

      // Check global test mode flag from branch (affects all roles)
      final branchId = invoice['rooms']?['branch_id']?.toString();
      if (branchId == null || branchId.isEmpty) {
        return {'success': false, 'message': 'ไม่พบข้อมูลสาขาของบิล'};
      }
      final testEnabled = await BranchService.getPromptPayTestMode(branchId);
      if (!testEnabled) {
        return {'success': false, 'message': 'โหมดทดสอบ PromptPay ถูกปิดอยู่'};
      }

      final paymentNumber = await _generatePaymentNumber();
      final now = DateTime.now();

      final payment = await _supabase
          .from('payments')
          .insert({
            'payment_number': paymentNumber,
            'invoice_id': invoiceId,
            'tenant_id': tenantId,
            'payment_date': now.toIso8601String(),
            'payment_amount': paidAmount,
            // ใช้ค่า "promptpay" ให้สอดคล้องกับ CHECK constraint ในตาราง payments
            'payment_method': 'promptpay',
            'payment_slip_image': '', // เผื่อคอลัมน์เป็น NOT NULL
            'payment_status': 'verified',
            'verified_by': currentUser.userId,
            'verified_date': now.toIso8601String(),
            'payment_notes': notes,
            'created_by': currentUser.userId,
            // ไม่บันทึก qr_id ในตาราง payments เพราะไม่มีคอลัมน์นี้ในสคีมา
          })
          .select()
          .single();

      // Update invoice paid amount/status
      final invUpdate = await InvoiceService.updateInvoicePaymentStatus(
          invoiceId, paidAmount);
      if (invUpdate['success'] != true) {
        // continue but include message in response
      }

      return {
        'success': true,
        'message': 'ทดสอบโอนสำเร็จและบันทึกการชำระเงินแล้ว',
        'payment': payment,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {
        'success': false,
        'message': 'ไม่สามารถบันทึกการชำระ (ทดสอบ) ได้: $e'
      };
    }
  }

  // Submit payment slip for verification (no invoice status change here)
  static Future<Map<String, dynamic>> submitPaymentSlip({
    required String invoiceId,
    required String tenantId,
    String? qrId, // optional selected branch account/QR
    required double paidAmount,
    required DateTime paymentDateTime,
    required String slipImageUrl,
    String? tenantNotes,
  }) async {
    try {
      // Basic validations
      if (paidAmount <= 0) {
        return {
          'success': false,
          'message': 'จำนวนเงินต้องมากกว่า 0',
        };
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      // Insert payment_slips (no slip_status; invoice-level verification)
      final data = {
        'invoice_id': invoiceId,
        'tenant_id': tenantId,
        'qr_id': qrId,
        'slip_image': slipImageUrl,
        'paid_amount': paidAmount,
        // payment_date is DATE in schema
        'payment_date': paymentDateTime.toIso8601String().split('T').first,
        'payment_time':
            '${paymentDateTime.hour.toString().padLeft(2, '0')}:${paymentDateTime.minute.toString().padLeft(2, '0')}:00',
        'tenant_notes': tenantNotes,
        'slip_type': 'manual',
      };

      final result =
          await _supabase.from('payment_slips').insert(data).select().single();

      // Also store the uploaded file into payment_slip_files for multi-file support
      try {
        final slipId = (result['slip_id'] ?? '').toString();
        final fileUrl = (slipImageUrl).toString();
        if (slipId.isNotEmpty && fileUrl.isNotEmpty) {
          await _supabase.from('payment_slip_files').insert({
            'slip_id': slipId,
            'file_url': fileUrl,
          });
        }
      } catch (_) {
        // Non-fatal: keep slip record even if file table insert fails
      }

      return {
        'success': true,
        'message': 'ส่งสลิปเรียบร้อย รอผู้ดูแลตรวจสอบ',
        'data': result,
      };
    } on PostgrestException catch (e) {
      final msg = (e.message ?? '').toString();
      if (msg.contains('ERR_MAX_5_SLIPS')) {
        return {
          'success': false,
          'message': 'บิลนี้แนบสลิปได้ไม่เกิน 5 ใบ',
        };
      }
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'ไม่สามารถส่งสลิปได้: $e',
      };
    }
  }

  // ======================
  // ADMIN: Slip Review APIs
  // ======================

  // List payment slips for admin review (no DB joins to avoid schema-cache relationship issues)
  static Future<List<Map<String, dynamic>>> listPaymentSlips({
    String status = 'all',
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
    String? search, // invoice_number or tenant name/phone
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // If branch filter is present, prefetch invoices of rooms in that branch
      List<String>? invoiceIdFilter;
      Map<String, Map<String, dynamic>> invoicesById = {};
      Map<String, Map<String, dynamic>> roomsById = {};
      Map<String, Map<String, dynamic>> tenantsById = {};
      Map<String, Map<String, dynamic>> branchesById = {};

      if (branchId != null && branchId.isNotEmpty) {
        final roomRows = await _supabase
            .from('rooms')
            .select(
                'room_id, room_number, branch_id, room_categories ( roomcate_name )')
            .eq('branch_id', branchId);
        final roomIds = List<Map<String, dynamic>>.from(roomRows)
            .map((r) => r['room_id'])
            .where((id) => id != null)
            .map<String>((id) => id.toString())
            .toList();
        if (roomIds.isEmpty) {
          return [];
        }

        final invRows = await _supabase
            .from('invoices')
            .select(
                'invoice_id, invoice_number, total_amount, paid_amount, invoice_status, room_id, tenant_id, due_date')
            .inFilter('room_id', roomIds);
        final invList = List<Map<String, dynamic>>.from(invRows);
        invoiceIdFilter =
            invList.map((r) => r['invoice_id'].toString()).toList();
        invoicesById = {for (final r in invList) r['invoice_id'].toString(): r};

        // batch fetch rooms, tenants, branches for enrichment
        final roomMap = {for (final r in roomRows) r['room_id'].toString(): r};
        roomsById = Map<String, Map<String, dynamic>>.from(roomMap);

        final tenantIds = invList
            .map((r) => r['tenant_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toSet()
            .toList();
        if (tenantIds.isNotEmpty) {
          final tenRows = await _supabase
              .from('tenants')
              .select('tenant_id, tenant_fullname, tenant_phone')
              .inFilter('tenant_id', tenantIds);
          tenantsById = {
            for (final r in List<Map<String, dynamic>>.from(tenRows))
              r['tenant_id'].toString(): r
          };
        }

        final brIds = roomRows
            .map((r) => r['branch_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toSet()
            .toList();
        if (brIds.isNotEmpty) {
          final brRows = await _supabase
              .from('branches')
              .select('branch_id, branch_name, branch_code')
              .inFilter('branch_id', brIds);
          branchesById = {
            for (final r in List<Map<String, dynamic>>.from(brRows))
              r['branch_id'].toString(): r
          };
        }
      }

      var query = _supabase.from('payment_slips').select('*');

      // status filter removed (slip_status dropped); rely on invoice_status in enrichment
      if (invoiceIdFilter != null) {
        query = query.inFilter('invoice_id', invoiceIdFilter);
      }
      if (startDate != null) {
        query = query.gte('payment_date', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('payment_date', endDate.toIso8601String());
      }
      if (search != null && search.isNotEmpty) {
        // Filter by paid_amount text; invoice_number handled client-side after enrichment
        query = query.or('paid_amount::text.ilike.%$search%');
      }

      final res = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      var slips = List<Map<String, dynamic>>.from(res);

      // If no branch prefetch, batch-fetch all needed invoice/room/tenant/branch/qr data
      if (invoiceIdFilter == null) {
        final invIds = slips
            .map((r) => r['invoice_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toSet()
            .toList();
        if (invIds.isNotEmpty) {
          final invRows = await _supabase
              .from('invoices')
              .select(
                  'invoice_id, invoice_number, total_amount, paid_amount, invoice_status, room_id, tenant_id, due_date')
              .inFilter('invoice_id', invIds);
          invoicesById = {
            for (final r in List<Map<String, dynamic>>.from(invRows))
              r['invoice_id'].toString(): r
          };

          final roomIds = invoicesById.values
              .map((r) => r['room_id'])
              .where((v) => v != null)
              .map((v) => v.toString())
              .toSet()
              .toList();
          if (roomIds.isNotEmpty) {
            final roomRows2 = await _supabase
                .from('rooms')
                .select(
                    'room_id, room_number, branch_id, room_categories ( roomcate_name )')
                .inFilter('room_id', roomIds);
            roomsById = {
              for (final r in List<Map<String, dynamic>>.from(roomRows2))
                r['room_id'].toString(): r
            };

            final brIds2 = roomsById.values
                .map((r) => r['branch_id'])
                .where((v) => v != null)
                .map((v) => v.toString())
                .toSet()
                .toList();
            if (brIds2.isNotEmpty) {
              final brRows2 = await _supabase
                  .from('branches')
                  .select('branch_id, branch_name, branch_code')
                  .inFilter('branch_id', brIds2);
              branchesById = {
                for (final r in List<Map<String, dynamic>>.from(brRows2))
                  r['branch_id'].toString(): r
              };
            }
          }

          final tenantIds2 = invoicesById.values
              .map((r) => r['tenant_id'])
              .where((v) => v != null)
              .map((v) => v.toString())
              .toSet()
              .toList();
          if (tenantIds2.isNotEmpty) {
            final tenRows2 = await _supabase
                .from('tenants')
                .select('tenant_id, tenant_fullname, tenant_phone')
                .inFilter('tenant_id', tenantIds2);
            tenantsById = {
              for (final r in List<Map<String, dynamic>>.from(tenRows2))
                r['tenant_id'].toString(): r
            };
          }
        }
      }

      // Classify method via branch_payment_qr for those with qr_id
      final qrIds = slips
          .map((r) => r['qr_id'])
          .where((v) => v != null)
          .map((v) => v.toString())
          .toSet()
          .toList();
      Map<String, Map<String, dynamic>> qrsById = {};
      if (qrIds.isNotEmpty) {
        final qrRows = await _supabase
            .from('branch_payment_qr')
            .select('qr_id,promptpay_id,bank_name,account_name,account_number')
            .inFilter('qr_id', qrIds);
        qrsById = {
          for (final r in List<Map<String, dynamic>>.from(qrRows))
            r['qr_id'].toString(): r
        };
      }

      var list = slips.map((row) {
        final inv = invoicesById[row['invoice_id']?.toString()] ?? {};
        final room = roomsById[inv['room_id']?.toString()] ?? {};
        final br = branchesById[room['branch_id']?.toString()] ?? {};
        final tenant = tenantsById[inv['tenant_id']?.toString()] ?? {};
        final qr = row['qr_id'] != null
            ? (qrsById[row['qr_id']?.toString()] ?? {})
            : {};
        final isPromptPay = ((qr['promptpay_id'] ?? '').toString().isNotEmpty);
        return {
          ...row,
          'invoice_number': inv['invoice_number'],
          'invoice_total': inv['total_amount'],
          'invoice_paid': inv['paid_amount'],
          'invoice_status': inv['invoice_status'],
          'room_number': room['room_number'],
          'roomcate_name': (room['room_categories'] is Map
                  ? (room['room_categories']['roomcate_name'])
                  : room['roomcate_name']) ??
              null,
          'branch_id': room['branch_id'],
          'branch_name': br['branch_name'],
          'tenant_name': tenant['tenant_fullname'],
          'tenant_phone': tenant['tenant_phone'],
          // convenience fields
          'is_promptpay': isPromptPay,
          'payment_method': isPromptPay ? 'promptpay' : 'transfer',
        };
      }).toList();

      // Client-side search across tenant fields to avoid deep filter errors
      if (search != null && search.isNotEmpty) {
        final s = search.toLowerCase();
        list = list.where((row) {
          final invNum = (row['invoice_number'] ?? '').toString().toLowerCase();
          final name = (row['tenant_name'] ?? '').toString().toLowerCase();
          final phone = (row['tenant_phone'] ?? '').toString().toLowerCase();
          return invNum.contains(s) || name.contains(s) || phone.contains(s);
        }).toList();
      }

      return list;
    } catch (e) {
      throw Exception('โหลดรายการสลิปไม่สำเร็จ: $e');
    }
  }

  // List verified PromptPay payments (no slips) for "ชำระแล้ว" tab
  static Future<List<Map<String, dynamic>>> listPromptPayVerifiedPayments({
    String? branchId,
    String? search,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      // Optional branch filter via invoices of rooms in branch
      List<String>? invoiceFilter;
      if (branchId != null && branchId.isNotEmpty) {
        final roomRows = await _supabase
            .from('rooms')
            .select('room_id')
            .eq('branch_id', branchId);
        final roomIds = List<Map<String, dynamic>>.from(roomRows)
            .map((r) => r['room_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toList();
        if (roomIds.isEmpty) return [];
        final invRows = await _supabase
            .from('invoices')
            .select('invoice_id')
            .inFilter('room_id', roomIds);
        invoiceFilter = List<Map<String, dynamic>>.from(invRows)
            .map((r) => r['invoice_id'].toString())
            .toList();
        if (invoiceFilter.isEmpty) return [];
      }

      var q = _supabase
          .from('payments')
          .select('*')
          .eq('payment_status', 'verified')
          .eq('payment_method', 'promptpay');
      if (invoiceFilter != null) {
        q = q.inFilter('invoice_id', invoiceFilter);
      }
      if (search != null && search.isNotEmpty) {
        q = q.or('payment_number.ilike.%$search%');
      }
      final rows = await q
          .order('payment_date', ascending: false)
          .range(offset, offset + limit - 1);

      // Enrich like slips list
      final payments = List<Map<String, dynamic>>.from(rows);
      final invIds = payments
          .map((r) => r['invoice_id'])
          .where((v) => v != null)
          .map((v) => v.toString())
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> invById = {};
      Map<String, Map<String, dynamic>> roomById = {};
      Map<String, Map<String, dynamic>> brById = {};
      Map<String, Map<String, dynamic>> tenById = {};

      if (invIds.isNotEmpty) {
        final invRows2 = await _supabase
            .from('invoices')
            .select(
                'invoice_id, invoice_number, total_amount, paid_amount, room_id, tenant_id, due_date')
            .inFilter('invoice_id', invIds);
        invById = {
          for (final r in List<Map<String, dynamic>>.from(invRows2))
            r['invoice_id'].toString(): r
        };
        final roomIds = invById.values
            .map((r) => r['room_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toSet()
            .toList();
        if (roomIds.isNotEmpty) {
          final rRows = await _supabase
              .from('rooms')
              .select('room_id, room_number, branch_id')
              .inFilter('room_id', roomIds);
          roomById = {
            for (final r in List<Map<String, dynamic>>.from(rRows))
              r['room_id'].toString(): r
          };
          final brIds = roomById.values
              .map((r) => r['branch_id'])
              .where((v) => v != null)
              .map((v) => v.toString())
              .toSet()
              .toList();
          if (brIds.isNotEmpty) {
            final bRows = await _supabase
                .from('branches')
                .select('branch_id, branch_name, branch_code')
                .inFilter('branch_id', brIds);
            brById = {
              for (final r in List<Map<String, dynamic>>.from(bRows))
                r['branch_id'].toString(): r
            };
          }
        }
        final tenIds = invById.values
            .map((r) => r['tenant_id'])
            .where((v) => v != null)
            .map((v) => v.toString())
            .toSet()
            .toList();
        if (tenIds.isNotEmpty) {
          final tRows = await _supabase
              .from('tenants')
              .select('tenant_id, tenant_fullname, tenant_phone')
              .inFilter('tenant_id', tenIds);
          tenById = {
            for (final r in List<Map<String, dynamic>>.from(tRows))
              r['tenant_id'].toString(): r
          };
        }
      }

      final list = payments.map((p) {
        final inv = invById[p['invoice_id']?.toString()] ?? {};
        final room = roomById[inv['room_id']?.toString()] ?? {};
        final br = brById[room['branch_id']?.toString()] ?? {};
        final ten = tenById[inv['tenant_id']?.toString()] ?? {};
        return {
          // pseudo slip row
          'slip_id': null,
          'slip_image': '',
          'paid_amount': p['payment_amount'],
          'payment_date': p['payment_date'],
          'created_at': p['payment_date'],
          'invoice_id': p['invoice_id'],
          'tenant_id': p['tenant_id'],
          'payment_id': p['payment_id'],
          'payment_method': 'promptpay',
          // enrichment
          'invoice_number': inv['invoice_number'],
          'invoice_total': inv['total_amount'],
          'invoice_paid': inv['paid_amount'],
          'room_number': room['room_number'],
          'branch_id': room['branch_id'],
          'branch_name': br['branch_name'],
          'tenant_name': ten['tenant_fullname'],
          'tenant_phone': ten['tenant_phone'],
          'is_promptpay': true,
        };
      }).toList();

      return list;
    } catch (e) {
      throw Exception('โหลดรายการชำระ PromptPay ไม่สำเร็จ: $e');
    }
  }

  static Future<Map<String, dynamic>?> getSlipById(String slipId) async {
    try {
      // 1) Load slip only — avoid deep joins (schema cache relationships may be missing)
      final slip = await _supabase
          .from('payment_slips')
          .select('*')
          .eq('slip_id', slipId)
          .maybeSingle();
      if (slip == null) return null;

      Map<String, dynamic>? inv;
      Map<String, dynamic>? room;
      Map<String, dynamic>? br;
      Map<String, dynamic>? tenant;

      // 2) Load invoice (flat)
      final invoiceId = (slip['invoice_id'] ?? '').toString();
      if (invoiceId.isNotEmpty) {
        inv = await _supabase
            .from('invoices')
            .select(
                'invoice_id, invoice_number, total_amount, paid_amount, invoice_status, room_id, tenant_id, due_date')
            .eq('invoice_id', invoiceId)
            .maybeSingle();
      }

      // 3) Load room + branch
      final roomId = inv?['room_id']?.toString();
      if (roomId != null && roomId.isNotEmpty) {
        room = await _supabase
            .from('rooms')
            .select('room_id, room_number, branch_id')
            .eq('room_id', roomId)
            .maybeSingle();
        final branchId = room?['branch_id']?.toString();
        if (branchId != null && branchId.isNotEmpty) {
          br = await _supabase
              .from('branches')
              .select('branch_id, branch_name, branch_code')
              .eq('branch_id', branchId)
              .maybeSingle();
        }
      }

      // 4) Load tenant
      final tenantId = inv?['tenant_id']?.toString();
      if (tenantId != null && tenantId.isNotEmpty) {
        tenant = await _supabase
            .from('tenants')
            .select('tenant_id, tenant_fullname, tenant_phone')
            .eq('tenant_id', tenantId)
            .maybeSingle();
      }

      // 5) Load slip files (multi-file support)
      List<Map<String, dynamic>> files = const [];
      try {
        final rows = await _supabase
            .from('payment_slip_files')
            .select('slip_file_id, file_url, created_at, updated_at')
            .eq('slip_id', slipId)
            .order('created_at', ascending: true);
        files = List<Map<String, dynamic>>.from(rows);
      } catch (_) {}

      // 6) Build enriched response (flat fields + optional nested for compatibility)
      final Map<String, dynamic> data = {
        ...slip,
        'files': files,
      };

      if (inv != null) {
        data.addAll({
          'invoice_number': inv['invoice_number'],
          'invoice_total': inv['total_amount'],
          'invoice_paid': inv['paid_amount'],
          'invoice_status': inv['invoice_status'],
        });
      }
      if (room != null) {
        data.addAll({
          'room_number': room['room_number'],
          'branch_id': room['branch_id'],
        });
      }
      if (br != null) {
        data['branch_name'] = br['branch_name'];
      }
      if (tenant != null) {
        data.addAll({
          'tenant_name': tenant['tenant_fullname'],
          'tenant_phone': tenant['tenant_phone'],
        });
      }

      // Optional nested block to preserve existing UI access paths
      if (inv != null) {
        final invNested = Map<String, dynamic>.from(inv);
        if (room != null) {
          final roomNested = Map<String, dynamic>.from(room);
          if (br != null) roomNested['branches'] = br;
          invNested['rooms'] = roomNested;
        }
        if (tenant != null) invNested['tenants'] = tenant;
        data['invoices'] = invNested;
      }

      return data;
    } catch (e) {
      throw Exception('ไม่พบสลิป: $e');
    }
  }

  static Future<String> _generatePaymentNumber() async {
    final now = DateTime.now();
    final prefix = 'PAY${now.year}${now.month.toString().padLeft(2, '0')}';
    final last = await _supabase
        .from('payments')
        .select('payment_number')
        .like('payment_number', '$prefix%')
        .order('payment_number', ascending: false)
        .limit(1)
        .maybeSingle();
    int next = 1;
    if (last != null) {
      final s = (last['payment_number'] ?? '').toString();
      final n = int.tryParse(s.substring(prefix.length)) ?? 0;
      next = n + 1;
    }
    return '$prefix${next.toString().padLeft(4, '0')}';
  }

  // Approve and create payment, update invoice, mark slip verified
  static Future<Map<String, dynamic>> verifySlip({
    required String slipId,
    required double approvedAmount,
    String paymentMethod = 'transfer',
    String? adminNotes,
  }) async {
    try {
      if (approvedAmount <= 0) {
        return {'success': false, 'message': 'จำนวนเงินต้องมากกว่า 0'};
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      final slip = await getSlipById(slipId);
      if (slip == null) {
        return {'success': false, 'message': 'ไม่พบสลิป'};
      }
      // No slip_status anymore; proceed based on invoice-level rules

      final invoiceId = slip['invoice_id'] as String;
      final tenantId = slip['tenant_id'] as String;

      // Create payment record
      final paymentNumber = await _generatePaymentNumber();
      final payment = await _supabase
          .from('payments')
          .insert({
            'payment_number': paymentNumber,
            'invoice_id': invoiceId,
            'tenant_id': tenantId,
            'payment_date': DateTime.now().toIso8601String(),
            'payment_amount': approvedAmount,
            'payment_method': paymentMethod,
            'payment_slip_image': slip['slip_image'],
            'payment_status': 'verified',
            'verified_by': currentUser.userId,
            'verified_date': DateTime.now().toIso8601String(),
            'payment_notes': adminNotes,
            'created_by': currentUser.userId,
            'slip_id': slipId,
          })
          .select()
          .single();

      // Link slip to payment and audit (no slip_status update)
      await _supabase.from('payment_slips').update({
        'verified_by': currentUser.userId,
        'verified_at': DateTime.now().toIso8601String(),
        'admin_notes': adminNotes,
        'payment_id': payment['payment_id'],
      }).eq('slip_id', slipId);

      // Update invoice paid amount/status
      final invUpdate = await InvoiceService.updateInvoicePaymentStatus(
          invoiceId, approvedAmount);
      if (invUpdate['success'] != true) {
        // Not fatal, but include message
      }

      // Add verification history
      await _supabase.from('slip_verification_history').insert({
        'slip_id': slipId,
        'action': 'verify',
        'action_by': currentUser.userId,
        'new_status': 'verified',
        'notes': adminNotes,
      });

      return {
        'success': true,
        'message': 'อนุมัติสลิปและบันทึกการชำระเงินเรียบร้อย',
        'payment': payment,
      };
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถอนุมัติสลิปได้: $e'};
    }
  }

  static Future<Map<String, dynamic>> rejectSlip({
    required String slipId,
    required String reason,
  }) async {
    try {
      if (reason.trim().isEmpty) {
        return {'success': false, 'message': 'กรุณาระบุเหตุผลในการปฏิเสธ'};
      }

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        return {'success': false, 'message': 'กรุณาเข้าสู่ระบบใหม่'};
      }

      final slip = await getSlipById(slipId);
      if (slip == null) {
        return {'success': false, 'message': 'ไม่พบสลิป'};
      }
      // Update audit fields only (no slip_status)
      await _supabase.from('payment_slips').update({
        'rejection_reason': reason,
        'verified_by': currentUser.userId,
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('slip_id', slipId);

      await _supabase.from('slip_verification_history').insert({
        'slip_id': slipId,
        'action': 'reject',
        'action_by': currentUser.userId,
        'new_status': 'rejected',
        'notes': reason,
      });

      return {'success': true, 'message': 'ปฏิเสธสลิปเรียบร้อย'};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': 'เกิดข้อผิดพลาด: ${e.message}'};
    } catch (e) {
      return {'success': false, 'message': 'ไม่สามารถปฏิเสธสลิปได้: $e'};
    }
  }

  // ======================
  // TENANT/COMMON HELPERS
  // ======================

  // ดึงสลิปล่าสุดของบิล (สำหรับเทนแนนท์/หน้ารายละเอียดบิล)
  static Future<Map<String, dynamic>?> getLatestSlipForInvoice(
    String invoiceId, {
    String? tenantId,
  }) async {
    try {
      // สร้าง query แบบ FilterBuilder ก่อน แล้วค่อยแปลงเป็น Transform ด้วย order/limit ตอนท้าย
      var q = _supabase
          .from('payment_slips')
          .select('*')
          .eq('invoice_id', invoiceId);

      if (tenantId != null && tenantId.isNotEmpty) {
        q = q.eq('tenant_id', tenantId);
      }

      final row =
          await q.order('created_at', ascending: false).limit(1).maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw Exception('โหลดสลิปล่าสุดไม่สำเร็จ: $e');
    }
  }

  // คืนชุด invoice_id ที่มีสลิปสถานะ pending (ใช้เพื่อแสดงป้าย "รอตรวจสอบ")
  static Future<Set<String>> getInvoicesWithPendingSlip({
    List<String>? invoiceIds,
    String? tenantId,
  }) async {
    try {
      var q = _supabase.from('payment_slips').select('invoice_id');

      if (tenantId != null && tenantId.isNotEmpty) {
        q = q.eq('tenant_id', tenantId);
      }
      if (invoiceIds != null && invoiceIds.isNotEmpty) {
        q = q.inFilter('invoice_id', invoiceIds);
      }

      // ถือเป็น "รอตรวจสอบ" หากยังไม่มีการผูกกับ payment
      q = q.isFilter('payment_id', null);

      final rows = await q;
      final list = List<Map<String, dynamic>>.from(rows);
      return list
          .map((r) => (r['invoice_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      throw Exception('โหลดสถานะสลิปที่รอตรวจสอบไม่สำเร็จ: $e');
    }
  }
}
