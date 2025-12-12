import 'package:supabase_flutter/supabase_flutter.dart';

class IssueResponseService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// List responses for an issue (newest first) with images
  static Future<List<Map<String, dynamic>>> listResponses(
    String issueId,
  ) async {
    try {
      final result = await _supabase
          .from('issue_responses')
          .select('*, issue_response_images(*)')
          .eq('issue_id', issueId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      throw Exception('เกิดข้อผิดพลาดในการโหลดการตอบกลับ: $e');
    }
  }

  /// Create response (text) then return created row
  static Future<Map<String, dynamic>> createResponse({
    required String issueId,
    String? responseText,
    required String createdBy,
  }) async {
    try {
      // Debug information
      print('🔍 Creating issue response:');
      print('   Issue ID: $issueId');
      print('   Created By: $createdBy');
      print(
          '   Response Text: ${responseText?.substring(0, responseText.length > 50 ? 50 : responseText.length)}...');
      print('   Auth User: ${_supabase.auth.currentUser?.id}');

      // Validate current user authentication
      final currentUser = _supabase.auth.currentUser;
      if (currentUser == null) {
        return {
          'success': false,
          'message': 'ไม่มีการเข้าสู่ระบบ กรุณาเข้าสู่ระบบใหม่',
        };
      }

      // Verify user exists in users table
      final userCheck = await _supabase
          .from('users')
          .select('user_id, user_name, role')
          .eq('user_id', createdBy)
          .maybeSingle();

      if (userCheck == null) {
        print('❌ User not found in database: $createdBy');
        return {
          'success': false,
          'message': 'ไม่พบข้อมูลผู้ใช้ในระบบ',
        };
      }

      print('✅ User found: ${userCheck['user_name']} (${userCheck['role']})');

      // Verify issue exists
      final issueCheck = await _supabase
          .from('issue_reports')
          .select('issue_id')
          .eq('issue_id', issueId)
          .maybeSingle();

      if (issueCheck == null) {
        print('❌ Issue not found: $issueId');
        return {
          'success': false,
          'message': 'ไม่พบข้อมูลปัญหาในระบบ',
        };
      }

      final insertData = {
        'issue_id': issueId,
        'response_text':
            (responseText ?? '').trim().isEmpty ? null : responseText!.trim(),
        'created_by': createdBy,
      };

      print('📤 Inserting data: $insertData');

      final inserted = await _supabase
          .from('issue_responses')
          .insert(insertData)
          .select()
          .single();

      print('✅ Response created successfully: ${inserted['response_id']}');

      return {
        'success': true,
        'data': inserted,
      };
    } on PostgrestException catch (e) {
      print('❌ PostgrestException: ${e.code} - ${e.message}');
      print('❌ Details: ${e.details}');
      print('❌ Hint: ${e.hint}');

      String message = 'เกิดข้อผิดพลาด';

      if (e.code == '42501' ||
          e.message.contains('permission denied') ||
          e.message.contains('insufficient_privilege')) {
        message = 'ไม่มีสิทธิ์ในการบันทึกข้อมูล กรุณาติดต่อผู้ดูแลระบบ';
      } else if (e.code == '23503') {
        message = 'ข้อมูลอ้างอิงไม่ถูกต้อง';
      } else if (e.code == '23505') {
        message = 'ข้อมูลซ้ำในระบบ';
      }

      return {
        'success': false,
        'message': '$message (${e.code})',
        'error_code': e.code,
        'error_details': e.message,
      };
    } catch (e) {
      print('❌ General Exception: $e');
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการบันทึกการตอบกลับ: $e',
      };
    }
  }

  /// Attach image URL to a response
  static Future<Map<String, dynamic>> addResponseImage({
    required String responseId,
    required String imageUrl,
  }) async {
    try {
      await _supabase.from('issue_response_images').insert({
        'response_id': responseId,
        'image_url': imageUrl,
      });

      return {'success': true};
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาดในการเพิ่มรูปภาพ: $e',
      };
    }
  }
}
