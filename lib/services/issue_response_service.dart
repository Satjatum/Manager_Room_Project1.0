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
      final inserted = await _supabase
          .from('issue_responses')
          .insert({
            'issue_id': issueId,
            'response_text': (responseText ?? '').trim().isEmpty
                ? null
                : responseText!.trim(),
            'created_by': createdBy,
          })
          .select()
          .single();

      return {
        'success': true,
        'data': inserted,
      };
    } on PostgrestException catch (e) {
      return {
        'success': false,
        'message': 'เกิดข้อผิดพลาด: ${e.message}',
      };
    } catch (e) {
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
