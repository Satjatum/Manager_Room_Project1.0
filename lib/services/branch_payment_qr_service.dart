import 'package:supabase_flutter/supabase_flutter.dart';

class BranchPaymentQrService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getByBranch(String branchId) async {
    try {
      final res = await _supabase
          .from('branch_payment_qr')
          .select('*')
          .eq('branch_id', branchId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      throw Exception('โหลดบัญชี/QR ไม่ได้: $e');
    }
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    try {
      final res =
          await _supabase.from('branch_payment_qr').insert(data).select().single();
      return {'success': true, 'data': res};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> update(
      String qrId, Map<String, dynamic> data) async {
    try {
      final res = await _supabase
          .from('branch_payment_qr')
          .update(data)
          .eq('qr_id', qrId)
          .select()
          .single();
      return {'success': true, 'data': res};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> toggleActive(String qrId, bool active) async {
    return update(qrId, {'is_active': active});
  }

  // setPrimary has been deprecated because column is_primary was removed from schema
  static Future<Map<String, dynamic>> setPrimary(
      {required String qrId, required String branchId}) async {
    return {
      'success': false,
      'message': 'คุณลบคอลัมน์ is_primary ออกแล้ว — ฟังก์ชันตั้งบัญชีหลักถูกยกเลิก',
    };
  }

  static Future<Map<String, dynamic>> delete(String qrId) async {
    try {
      await _supabase.from('branch_payment_qr').delete().eq('qr_id', qrId);
      return {'success': true};
    } on PostgrestException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
