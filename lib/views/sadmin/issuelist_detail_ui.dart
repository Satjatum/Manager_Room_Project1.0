import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:manager_room_project/views/widgets/colors.dart';
import '../../services/issue_service.dart';
import '../../services/issue_response_service.dart';
import '../../services/image_service.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_models.dart';

class IssueListDetailUi extends StatefulWidget {
  final String issueId;

  const IssueListDetailUi({
    Key? key,
    required this.issueId,
  }) : super(key: key);

  @override
  State<IssueListDetailUi> createState() => _IssueListDetailUiState();
}

class _ResolvePayload {
  final String? text;
  final List<XFile> images;
  const _ResolvePayload({this.text, required this.images});
}

class _UploadState {
  final int current;
  final int total;
  final String phase; // e.g., 'อัปเดตสถานะ', 'อัปโหลดรูป'
  final String? fileName;
  const _UploadState(
      {required this.current,
      required this.total,
      required this.phase,
      this.fileName});
}

class _IssueListDetailUiState extends State<IssueListDetailUi> {
  bool _isLoading = true;
  UserModel? _currentUser;
  Map<String, dynamic>? _issue;
  List<Map<String, dynamic>> _images = [];
  List<Map<String, dynamic>> _responses = [];
  List<Map<String, dynamic>> _availableUsers = [];

  final _resolutionController = TextEditingController();
  // Images attached when marking as resolved
  final List<XFile> _resolveImages = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadResponses() async {
    try {
      final rows = await IssueResponseService.listResponses(widget.issueId);
      if (mounted) setState(() => _responses = rows);
    } catch (e) {
      _showErrorSnackBar('โหลดการตอบกลับไม่สำเร็จ: $e');
    }
  }

  @override
  void dispose() {
    _resolutionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      _currentUser = await AuthService.getCurrentUser();
      _issue = await IssueService.getIssueById(widget.issueId);

      if (_issue != null) {
        _images = await IssueService.getIssueImages(widget.issueId);
        await _loadResponses();
      }

      if (_currentUser != null &&
          _currentUser!.hasAnyPermission([
            DetailedPermission.all,
            DetailedPermission.manageIssues,
          ])) {
        // Only show assignable users: Admin / Superadmin
        _availableUsers = await UserService.getAssignableUsers();
      }

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        _showErrorSnackBar('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    bool statusUpdated = false;
    if (status == 'resolved') {
      final payload = await _openResolveDialog();
      if (payload == null) return; // cancelled

      try {
        final progress = ValueNotifier<_UploadState>(
          const _UploadState(current: 0, total: 0, phase: 'อัปเดตสถานะ'),
        );
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ValueListenableBuilder<_UploadState>(
                valueListenable: progress,
                builder: (context, state, __) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 50,
                              height: 50,
                              child: CircularProgressIndicator(
                                color: Colors.green.shade600,
                                strokeWidth: 3,
                              ),
                            ),
                            Icon(
                              Icons.cloud_upload_rounded,
                              color: Colors.green.shade600,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'กำลังบันทึก',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.total > 0
                            ? 'อัปโหลดรูป ${state.current}/${state.total}${state.fileName != null ? ' • ' + state.fileName! : ''}'
                            : state.phase,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );

        final updateResult = await IssueService.updateIssueStatus(
          widget.issueId,
          'resolved',
          resolutionNotes: null,
        );

        if (updateResult['success']) {
          statusUpdated = true;
          try {
            final created = await IssueResponseService.createResponse(
              issueId: widget.issueId,
              responseText: (payload.text ?? '').trim().isEmpty
                  ? null
                  : payload.text!.trim(),
              createdBy: _currentUser?.userId ?? '',
            );
            if (created['success'] == true) {
              final responseId = created['data']['response_id'] as String;
              final total = payload.images.length;
              int idx = 0;
              for (final img in payload.images) {
                idx++;
                progress.value = _UploadState(
                  current: idx,
                  total: total,
                  phase: 'อัปโหลดรูป',
                  fileName: kIsWeb ? img.name : _fileDisplayName(img),
                );
                if (kIsWeb) {
                  final ext = img.name.contains('.')
                      ? img.name.split('.').last.toLowerCase()
                      : 'jpg';
                  final bytes = await img.readAsBytes();
                  final seq = await ImageService.generateSequentialFileName(
                    bucket: 'issue_res_images',
                    folder: 'responses/${widget.issueId}',
                    prefix: 'Resp',
                    extension: ext,
                  );
                  final up = await ImageService.uploadImageFromBytes(
                    bytes,
                    img.name,
                    'issue_res_images',
                    folder: 'responses/${widget.issueId}',
                    customFileName: seq,
                  );
                  if (up['success'] == true) {
                    await IssueResponseService.addResponseImage(
                        responseId: responseId, imageUrl: up['url']);
                  } else {
                    _showErrorSnackBar(
                        up['message'] ?? 'อัปโหลดรูปภาพไม่สำเร็จ');
                  }
                } else {
                  final ext = img.path.contains('.')
                      ? img.path.split('.').last.toLowerCase()
                      : 'jpg';
                  final seq = await ImageService.generateSequentialFileName(
                    bucket: 'issue_res_images',
                    folder: 'responses/${widget.issueId}',
                    prefix: 'Resp',
                    extension: ext,
                  );
                  final up = await ImageService.uploadImage(
                    File(img.path),
                    'issue_res_images',
                    folder: 'responses/${widget.issueId}',
                    customFileName: seq,
                  );
                  if (up['success'] == true) {
                    await IssueResponseService.addResponseImage(
                        responseId: responseId, imageUrl: up['url']);
                  } else {
                    _showErrorSnackBar(
                        up['message'] ?? 'อัปโหลดรูปภาพไม่สำเร็จ');
                  }
                }
              }
            }
          } catch (_) {}

          if (mounted) {
            _showSuccessSnackBar(updateResult['message']);
            _resolutionController.clear();
            _resolveImages.clear();
          }
        } else {
          throw Exception(updateResult['message']);
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
        }
      } finally {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (statusUpdated && mounted) {
          Navigator.pop(context, true); // refresh issuelist
        }
      }

      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: _getStatusColor(status),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'เปลี่ยนสถานะเป็น\n${_getStatusText(status)}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ต้องการเปลี่ยนสถานะเป็น ${_getStatusText(status)} ใช่หรือไม่?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'การเปลี่ยนสถานะจะถูกบันทึกในประวัติ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('ยกเลิก', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _getStatusColor(status),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Validate for resolved: must have text or at least 1 image
        if (status == 'resolved') {
          final hasText = _resolutionController.text.trim().isNotEmpty;
          final hasImg = _resolveImages.isNotEmpty;
          if (!hasText && !hasImg) {
            _showErrorSnackBar('กรุณากรอกข้อความหรือแนบรูปอย่างน้อย 1 รายการ');
            return;
          }
        }

        // Show blocking progress while updating and uploading
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(
                            color: Colors.blue.shade600,
                            strokeWidth: 3,
                          ),
                        ),
                        Icon(
                          Icons.autorenew_rounded,
                          color: Colors.blue.shade600,
                          size: 28,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'กำลังบันทึก...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        );

        final updateResult = await IssueService.updateIssueStatus(
          widget.issueId,
          status,
          resolutionNotes: null, // use response_txt instead of resolution_notes
        );

        if (updateResult['success']) {
          statusUpdated = true;
          // When resolved, also create a response entry with images to appear in timeline
          if (status == 'resolved') {
            try {
              final text = _resolutionController.text.trim();
              final created = await IssueResponseService.createResponse(
                issueId: widget.issueId,
                responseText: text.isEmpty ? null : text,
                createdBy: _currentUser?.userId ?? '',
              );
              if (created['success'] == true) {
                final responseId = created['data']['response_id'] as String;
                for (final img in List<XFile>.from(_resolveImages)) {
                  if (kIsWeb) {
                    final ext = img.name.contains('.')
                        ? img.name.split('.').last.toLowerCase()
                        : 'jpg';
                    final bytes = await img.readAsBytes();
                    final seq = await ImageService.generateSequentialFileName(
                      bucket: 'issue_res_images',
                      folder: 'responses/${widget.issueId}',
                      prefix: 'Resp',
                      extension: ext,
                    );
                    final up = await ImageService.uploadImageFromBytes(
                      bytes,
                      img.name,
                      'issue_res_images',
                      folder: 'responses/${widget.issueId}',
                      customFileName: seq,
                    );
                    if (up['success'] == true) {
                      await IssueResponseService.addResponseImage(
                          responseId: responseId, imageUrl: up['url']);
                    } else {
                      _showErrorSnackBar(
                          up['message'] ?? 'อัปโหลดรูปภาพไม่สำเร็จ');
                    }
                  } else {
                    final ext = img.path.contains('.')
                        ? img.path.split('.').last.toLowerCase()
                        : 'jpg';
                    final seq = await ImageService.generateSequentialFileName(
                      bucket: 'issue_res_images',
                      folder: 'responses/${widget.issueId}',
                      prefix: 'Resp',
                      extension: ext,
                    );
                    final up = await ImageService.uploadImage(
                      File(img.path),
                      'issue_res_images',
                      folder: 'responses/${widget.issueId}',
                      customFileName: seq,
                    );
                    if (up['success'] == true) {
                      await IssueResponseService.addResponseImage(
                          responseId: responseId, imageUrl: up['url']);
                    } else {
                      _showErrorSnackBar(
                          up['message'] ?? 'อัปโหลดรูปภาพไม่สำเร็จ');
                    }
                  }
                }
              }
            } catch (_) {}
            _resolveImages.clear();
          }
          if (mounted) {
            _showSuccessSnackBar(updateResult['message']);
            _resolutionController.clear();
          }
        } else {
          throw Exception(updateResult['message']);
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
        }
      } finally {
        if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop(); // close progress
        }
        if (statusUpdated && mounted) {
          Navigator.pop(context, true); // refresh issuelist
        }
      }
    }
  }

  Future<_ResolvePayload?> _openResolveDialog() async {
    final textController = TextEditingController();
    final List<XFile> localImages = [];

    return showDialog<_ResolvePayload>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickImages() async {
              // Check if already have 10 images
              if (localImages.length >= 10) {
                _showErrorSnackBar('สามารถแนบรูปภาพได้สูงสุด 10');
                return;
              }

              try {
                final picker = ImagePicker();
                ImageSource? source;

                // For web, use gallery only
                if (kIsWeb) {
                  source = ImageSource.gallery;
                } else {
                  // For mobile, show bottom sheet to select camera or gallery
                  source = await showModalBottomSheet<ImageSource>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (BuildContext context) {
                      return SafeArea(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'เลือกรูปภาพ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => Navigator.pop(
                                          context, ImageSource.camera),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.camera_alt,
                                                size: 40,
                                                color: Color(0xFF10B981)),
                                            const SizedBox(height: 8),
                                            const Text('ถ่ายรูป',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => Navigator.pop(
                                          context, ImageSource.gallery),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(Icons.photo_library,
                                                size: 40,
                                                color: Color(0xFF10B981)),
                                            const SizedBox(height: 8),
                                            const Text('แกลเลอรี่',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w500)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('ยกเลิก',
                                      style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                if (source != null) {
                  final picked = await picker.pickImage(
                    source: source,
                    maxWidth: 1920,
                    maxHeight: 1080,
                    imageQuality: 85,
                  );

                  if (picked != null) {
                    setLocalState(() {
                      localImages.add(picked);
                    });
                  }
                }
              } catch (e) {
                _showErrorSnackBar('เลือกไฟล์ไม่สำเร็จ: $e');
              }
            }

            Widget imagePreviews() {
              if (localImages.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 110,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < localImages.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: kIsWeb
                                      ? Image.network(
                                          localImages[i].path,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          File(localImages[i].path),
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setLocalState(
                                        () => localImages.removeAt(i)),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          )
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(2),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor('resolved').withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon('resolved'),
                      color: _getStatusColor('resolved'),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child:
                        Text('บันทึกการแก้ไข', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // หมายเหตุ: ไม่บังคับกรอกข้อความหรือแนบรูป
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'รายละเอียดการแก้ไข...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Color(0xFF10B981), width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              BorderSide(color: Colors.grey[300]!, width: 1),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    imagePreviews(),
                    const SizedBox(height: 10),

                    OutlinedButton(
                      onPressed: localImages.length >= 10 ? null : pickImages,
                      child: Text(
                        'แนบรูป (${localImages.length}/10)',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'ยกเลิก',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final text = textController.text.trim();
                          Navigator.pop(
                              context,
                              _ResolvePayload(
                                  text: text.isEmpty ? null : text,
                                  images: List<XFile>.from(localImages)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getStatusColor('resolved'),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'บันทึก',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _assignUser(String userId) async {
    try {
      final result = await IssueService.assignIssue(widget.issueId, userId);
      if (result['success']) {
        // Auto change status to in_progress after assignment
        final statusRes = await IssueService.updateIssueStatus(
          widget.issueId,
          'in_progress',
        );
        if (mounted) {
          final msg = statusRes['success'] == true
              ? 'มอบหมายและเริ่มดำเนินการแล้ว'
              : result['message'];
          _showSuccessSnackBar(msg);
          _loadData();
        }
      } else {
        throw Exception(result['message']);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.pending_outlined;
      case 'in_progress':
        return Icons.autorenew;
      case 'resolved':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'รอดำเนินการ';
      case 'in_progress':
        return 'กำลังดำเนินการ';
      case 'resolved':
        return 'แก้ไขเสร็จสิ้น';
      case 'cancelled':
        return 'ปฏิเสธ';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildWhiteHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _issue == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'ไม่พบข้อมูล',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppTheme.primary,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Actions Card
                                if (_currentUser != null &&
                                    _currentUser!.hasAnyPermission([
                                      DetailedPermission.all,
                                      DetailedPermission.manageIssues,
                                    ])) ...[
                                  _buildActionsCard(),
                                  const SizedBox(height: 16),
                                ],

                                // Header Card
                                _buildHeaderCard(),
                                const SizedBox(height: 16),

                                // Details Card
                                _buildDetailsCard(),
                                const SizedBox(height: 16),

                                // Images Section
                                if (_images.isNotEmpty) ...[
                                  _buildImagesSection(),
                                  const SizedBox(height: 16),
                                ],

                                // Timeline Section
                                _buildTimelineSection(),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Top bar with back button
          Padding(
            padding: EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.black87),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  },
                  tooltip: 'ย้อนกลับ',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'รายละเอียดปัญหา',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'สำหรับดูรายละเอียดปัญหา',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    final status = _issue!['issue_status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getStatusIcon(status),
                  color: _getStatusColor(status),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _issue!['issue_title'] ?? 'ไม่มีหัวข้อ',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Issue #${_issue!['issue_id']?.toString().substring(0, 8) ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 16,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.info_outline,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'รายละเอีดยปัญหา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            icon: Icons.description_outlined,
            label: 'คำอธิบาย',
            value: _issue!['issue_desc'] ?? 'ไม่มีคำอธิบาย',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.person_outline,
            label: 'ผู้แจ้ง',
            value:
                '${_issue!['created_user_name']} | ${_issue!['room_category_name']}เลขที่ ${_issue!['room_number'] ?? 'ไม่ระบุ'}',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.person_add_outlined,
            label: 'ผู้รับผิดชอบ',
            value: _issue!['assigned_user_name'] ?? 'ยังไม่มอบหมาย',
          ),
          const SizedBox(height: 12),
          _buildDetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'วันที่แจ้ง',
            value: _formatDate(_issue!['created_at']),
          ),
          if (_issue!['resolved_date'] != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(
              icon: Icons.check_circle_outline,
              label: 'วันที่แก้ไขเสร็จ',
              value: _formatDate(_issue!['resolved_date']),
            ),
          ],
          // หมายเหตุ: รายละเอียดการแก้ไขจะไปอยู่ในประวัติการดำเนินงานจาก response_txt
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined,
                  color: AppTheme.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'รูปภาพประกอบ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_images.length} รูป',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _images[index]['image_url'],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: Icon(Icons.broken_image,
                        color: Colors.grey[600], size: 32),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard() {
    final status = _issue!['issue_status'] ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.settings_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'การดำเนินการ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (status == 'pending') ...[
            // Single toggle button: Assign -> Start
            _buildActionButton(
              icon: _issue!['assigned_to'] == null
                  ? Icons.person_add_outlined
                  : Icons.autorenew,
              label: _issue!['assigned_to'] == null
                  ? 'มอบหมายงาน'
                  : 'เริ่มดำเนินการ',
              color: Colors.blue,
              onTap: () {
                if (_issue!['assigned_to'] == null) {
                  _showAssignDialog();
                } else {
                  _updateStatus('in_progress');
                }
              },
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              icon: Icons.cancel_outlined,
              label: 'ปฏิเสธ',
              color: Colors.red,
              onTap: () => _updateStatus('cancelled'),
            ),
          ],
          if (status == 'in_progress') ...[
            _buildActionButton(
              icon: Icons.check_circle_outline,
              label: 'แก้ไขเสร็จสิ้น',
              color: Colors.green,
              onTap: () => _updateStatus('resolved'),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              icon: Icons.person_add_outlined,
              label: 'เปลี่ยนผู้รับผิดชอบ',
              color: Colors.blue,
              onTap: () => _showAssignDialog(),
            ),
          ],
          const SizedBox(height: 10),
          _buildActionButton(
            icon: Icons.delete_outline,
            label: 'ลบปัญหา',
            color: Colors.red,
            onTap: () => _confirmDelete(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline_outlined,
                    color: Color(0xFF10B981), size: 20),
              ),
              SizedBox(width: 12),
              Text(
                'ประวัติการดำเนินงาน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    List<Map<String, dynamic>> timeline = [];

    if (_issue!['created_at'] != null) {
      timeline.add({
        'date': _issue!['created_at'],
        'status': 'pending',
        'title': 'รายงานปัญหา',
        'user': _issue!['created_user_name'] ?? 'ระบบ',
        'icon': Icons.report_problem,
        'description': 'สร้างรายการแจ้งปัญหาในระบบ',
      });
    }

    if (_issue!['assigned_user_name'] != null) {
      timeline.add({
        'date': _issue!['updated_at'],
        'status': 'in_progress',
        'title': 'มอบหมายงาน',
        'user': _issue!['assigned_user_name'],
        'icon': Icons.person_add,
        'description': 'ได้รับมอบหมายให้ดำเนินการแก้ไข',
      });
    }

    if (_issue!['resolved_date'] != null) {
      timeline.add({
        'date': _issue!['resolved_date'],
        'status': 'resolved',
        'title': 'แก้ไขเสร็จสิ้น',
        'user': _issue!['assigned_user_name'] ?? 'ระบบ',
        'icon': Icons.check_circle,
        'description': 'ปัญหาได้รับการแก้ไขเรียบร้อย',
      });
    }

    // Add responses as part of timeline (evidence of resolution)
    for (final r in _responses) {
      final List imgs =
          List<Map<String, dynamic>>.from(r['issue_response_images'] ?? []);
      timeline.add({
        'date': r['created_at'],
        'status': 'resolved',
        'title': 'หลักฐานการแก้ไข',
        'user': _issue!['assigned_user_name'] ?? 'ผู้ดูแล',
        'icon': Icons.forum_outlined,
        'description': (r['response_text'] ?? '').toString().isEmpty
            ? 'มีการอัปโหลดรูปภาพหลักฐาน'
            : (r['response_text'] ?? '').toString(),
        'images': imgs.map((e) => e['image_url']).toList(),
      });
    }

    // Sort by date ascending
    timeline.sort((a, b) =>
        DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    if (timeline.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text(
                'ไม่มีข้อมูลประวัติ',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: timeline.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == timeline.length - 1;
        final date = DateTime.parse(item['date']);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(item['status']),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              _getStatusColor(item['status']).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      item['icon'],
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(item['status'])
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _getStatusText(item['status']),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(item['status']),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['description'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                      if ((item['images'] ?? []).isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: (item['images'] as List).length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final url =
                                  (item['images'] as List)[index] as String;
                              return GestureDetector(
                                onTap: () => _showImageViewer(url),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    url,
                                    height: 90,
                                    width: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => Container(
                                      height: 90,
                                      width: 90,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.broken_image,
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            '${date.day}/${date.month}/${date.year + 543} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item['user'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add_outlined,
                  color: Color(0xFF10B981), size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'มอบหมายงาน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        content: SizedBox(
          width: double.maxFinite,
          height: 150,
          child: _availableUsers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('ไม่พบผู้ใช้ในระบบ'),
                  ),
                )
              : Scrollbar(
                  child: ListView.builder(
                    shrinkWrap: false,
                    itemCount: _availableUsers.length,
                    itemBuilder: (context, index) {
                      final user = _availableUsers[index];
                      final isAssigned =
                          user['user_id'] == _issue!['assigned_to'];

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isAssigned
                              ? Colors.blue.shade100
                              : Colors.grey.shade200,
                          child: Icon(
                            Icons.person,
                            color: isAssigned
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        title: Text(
                          user['user_name'] ?? 'ไม่ระบุชื่อ',
                          style: TextStyle(
                            fontWeight: isAssigned
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(user['user_email'] ?? ''),
                        trailing: isAssigned
                            ? Icon(Icons.check_circle,
                                color: Colors.blue.shade700)
                            : null,
                        onTap: () {
                          Navigator.pop(context);
                          _assignUser(user['user_id']);
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'ปิด',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // TextButton(
          //   onPressed: () => Navigator.pop(context),
          //   child: const Text('ปิด'),
          // ),
        ],
      ),
    );
  }

  Future<void> _deleteIssue() async {
    try {
      final result = await IssueService.deleteIssue(widget.issueId);
      if (!mounted) return;
      if (result['success']) {
        _showSuccessSnackBar(result['message']);
        Navigator.pop(context); // Close detail after deletion
      } else {
        _showErrorSnackBar(result['message']);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _confirmDelete() {
    showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ลบหัวข้อแจ้งปัญหาหรือไม่?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        (_issue?['issue_title'] ?? '').toString().isNotEmpty
                            ? (_issue?['issue_title'] ?? '').toString()
                            : 'Issue ${_issue?['issue_id'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_rounded,
                        color: Colors.red.shade600, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ข้อมูลทั้งหมดจะถูกลบอย่างถาวร',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'ลบ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((confirm) async {
      if (confirm == true) {
        try {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              color: Colors.red.shade600,
                              strokeWidth: 3,
                            ),
                          ),
                          Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.red.shade600,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ลบปัญหา',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณารอสักครู่...',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );

          final result = await IssueService.deleteIssue(widget.issueId);

          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(); // close progress
          }

          if (mounted) {
            if (result['success']) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(result['message'] ?? 'ลบสำเร็จ'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
              Navigator.pop(context, true); // Close detail and refresh list
            } else {
              throw Exception(result['message']);
            }
          }
        } catch (e) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.toString().replaceAll('ข้อยกเว้น: ', '')),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'ไม่ระบุ';
    try {
      final date = DateTime.parse(dateStr);
      final beYear = date.year + 543;
      return '${date.day}/${date.month}/$beYear ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'ไม่ระบุ';
    }
  }

  String _fileDisplayName(XFile f) {
    if (kIsWeb) return f.name;
    final p = f.path;
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.isNotEmpty ? parts.last : p;
  }

  void _showImageViewer(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black,
          child: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.broken_image,
                    color: Colors.white, size: 64),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
