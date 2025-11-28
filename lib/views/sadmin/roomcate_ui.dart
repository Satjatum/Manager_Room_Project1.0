import 'package:flutter/material.dart';
// Services //
import '../../services/room_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

class RoomCateUi extends StatefulWidget {
  const RoomCateUi({Key? key}) : super(key: key);

  @override
  State<RoomCateUi> createState() => _RoomCateUiState();
}

class _RoomCateUiState extends State<RoomCateUi> {
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _filteredCategories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ไอคอนสำหรับหมวดหมู่ห้อง (แนวเดียวกับ amenities/roomtype)
  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'category', 'icon': Icons.category, 'label': 'หมวดหมู่'},
    {'name': 'grid_view', 'icon': Icons.grid_view, 'label': 'กริด'},
    {'name': 'chair', 'icon': Icons.chair, 'label': 'เก้าอี้'},
    {
      'name': 'meeting_room',
      'icon': Icons.meeting_room_outlined,
      'label': 'ห้อง'
    },
    {'name': 'home_work', 'icon': Icons.home_work_outlined, 'label': 'อาคาร'},
    {'name': 'weekend', 'icon': Icons.weekend_outlined, 'label': 'โซฟา'},
    {'name': 'bathtub', 'icon': Icons.bathtub_outlined, 'label': 'ห้องน้ำ'},
    {'name': 'kitchen', 'icon': Icons.kitchen, 'label': 'ครัว'},
    {'name': 'balcony', 'icon': Icons.balcony, 'label': 'ระเบียง'},
    {'name': 'workspace', 'icon': Icons.workspaces_outline, 'label': 'ทำงาน'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final categories = await RoomService.getRoomCategories();
      if (mounted) {
        setState(() {
          _categories = categories;
          _filteredCategories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        debugPrint('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
        SnackMessage.showError(context, 'เกิดข้อผิดพลาดในการโหลดข้อมูล');
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredCategories = _categories.where((category) {
        final name = (category['roomcate_name'] ?? '').toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower);
      }).toList();
    });
  }

  IconData _getIconData(String? iconName) {
    if (iconName == null) return Icons.category;
    final icon = _iconOptions.firstWhere(
      (opt) => opt['name'] == iconName,
      orElse: () => {'icon': Icons.category},
    );
    return icon['icon'] as IconData;
  }

  Future<void> _showIconPicker(
    TextEditingController controller,
    String currentIcon,
  ) async {
    final selectedIcon = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.apps_rounded, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text(
                    'เลือกไอคอน',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _iconOptions.length,
                  itemBuilder: (context, index) {
                    final option = _iconOptions[index];
                    final isSelected = option['name'] == currentIcon;
                    return InkWell(
                      onTap: () => Navigator.pop(context, option['name']),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              option['icon'] as IconData,
                              size: 24,
                              color: isSelected
                                  ? AppTheme.primary
                                  : Colors.grey[700],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'ยกเลิก',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedIcon != null) {
      controller.text = selectedIcon;
    }
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(
      text: isEdit ? category['roomcate_name'] : '',
    );
    final iconController = TextEditingController(
      text: isEdit ? (category['roomcate_icon'] ?? 'category') : 'category',
    );

    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            constraints: BoxConstraints(maxWidth: 460),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit : Icons.add_circle_outline,
                    color: AppTheme.primary,
                    size: 36,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  isEdit ? 'แก้ไขหมวดหมู่ห้อง' : 'เพิ่มหมวดหมู่ห้อง',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                // Icon selector box
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          await _showIconPicker(
                              iconController, iconController.text);
                          setDialogState(() {});
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconData(iconController.text),
                          size: 44,
                          color: AppTheme.primary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'แตะเพื่อเลือกไอคอน',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 14),
                // Name field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'ชื่อหมวดหมู่ห้อง *',
                    labelStyle: TextStyle(
                      color: Colors.grey[700],
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: AppTheme.primary,
                        width: 1.6,
                      ),
                    ),
                  ),
                  autofocus: !isEdit,
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'ยกเลิก',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) {
                                  debugPrint('กรุณากรอกชื่อหมวดหมู่ห้อง');
                                  SnackMessage.showError(
                                      context, 'กรุณากรอกชื่อหมวดหมู่ห้อง');

                                  return;
                                }
                                setDialogState(() => isSubmitting = true);

                                try {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => Center(
                                      child: CircularProgressIndicator(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  );

                                  final payload = {
                                    'roomcate_name': nameController.text.trim(),
                                    'roomcate_icon': iconController.text,
                                  };

                                  Map<String, dynamic> resp;
                                  if (isEdit) {
                                    resp = await RoomService.updateRoomCategory(
                                      category['roomcate_id'],
                                      payload,
                                    );
                                  } else {
                                    resp = await RoomService.createRoomCategory(
                                      payload,
                                    );
                                  }

                                  if (mounted && Navigator.canPop(context)) {
                                    Navigator.of(context)
                                        .pop(); // close spinner
                                  }

                                  if (mounted) {
                                    if (resp['success'] == true) {
                                      debugPrint(resp['message'] ?? 'สำเร็จ');
                                      SnackMessage.showSuccess(
                                          context, 'สำเร็จ');

                                      Navigator.of(context)
                                          .pop(); // close dialog
                                      await _loadCategories();
                                    } else {
                                      debugPrint(
                                          'เกิดข้อผิดพลาด: ${resp['message'] ?? 'ไม่สำเร็จ'}');
                                      throw Exception(
                                          resp['message'] ?? 'ไม่สำเร็จ');
                                    }
                                  }
                                } catch (e) {
                                  if (mounted && Navigator.canPop(context)) {
                                    Navigator.of(context)
                                        .pop(); // ensure closed
                                  }
                                  setDialogState(() => isSubmitting = false);
                                  if (mounted) {
                                    debugPrint('เกิดข้อผิดพลาด: $e');
                                    SnackMessage.showError(
                                        context, 'เกิดข้อผิดพลาด');
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isSubmitting)
                              Icon(isEdit ? Icons.save_outlined : Icons.add),
                            if (!isSubmitting) SizedBox(width: 8),
                            isSubmitting
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    isEdit ? 'บันทึก' : 'เพิ่ม',
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
      ),
    );
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final String name = (category['roomcate_name'] ?? '').toString();
    final String id = (category['roomcate_id'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          constraints: BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16),
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
              SizedBox(height: 20),
              Text(
                'Delete Room Category?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.category, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
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
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100, width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Colors.red.shade600,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'การดำเนินการนี้ไม่สามารถย้อนกลับได้\nข้อมูลทั้งหมดจะถูกลบอย่างถาวร',
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
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
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
    );

    if (confirmed == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
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
                  SizedBox(height: 20),
                  Text(
                    'Deleting Room Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Please wait a moment...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await RoomService.deleteRoomCategory(id);
        if (mounted) Navigator.of(context).pop(); // close overlay

        if (mounted) {
          if (result['success'] == true) {
            debugPrint(result['message'] ?? 'ลบสำเร็จ');
            SnackMessage.showSuccess(
              context,
              result['message'] ?? 'ลบสำเร็จ',
            );
            await _loadCategories();
          } else {
            debugPrint('เกิดข้อผิดพลาด: ${result['message'] ?? 'ลบไม่สำเร็จ'}');
            throw Exception(result['message'] ?? 'ลบไม่สำเร็จ');
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // ensure progress closed
        }
        if (mounted) {
          debugPrint('เกิดข้อผิดพลาด: $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (match amenities)
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop())
                        Navigator.of(context).pop();
                    },
                    tooltip: 'ย้อนกลับ',
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'หมวดหมู่ห้อง',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับจัดการหมวดหมู่ห',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Search (match amenities style)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาหมวดหมู่ห้อง',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search, color: Colors.grey[600], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: Colors.grey[600], size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            // Count
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Showing ${_filteredCategories.length} of ${_categories.length} categories',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _loadCategories,
                child: _isLoading
                    ? ListView(
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120),
                          Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary),
                          ),
                        ],
                      )
                    : _filteredCategories.isEmpty
                        ? ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.category_outlined,
                                        size: 80, color: Colors.grey[400]),
                                    SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'ไม่พบหมวดหมู่ห้องที่ค้นหา'
                                          : 'ยังไม่มีหมวดหมู่ห้อง',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddEditDialog(),
                                      icon: Icon(Icons.add),
                                      label: Text('เพิ่มหมวดหมู่ห้องแรก'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;

                              // คำนวณขนาด Card ตามความกว้างหน้าจอ
                              double cardWidth;
                              if (width < 600) {
                                cardWidth = width - 48; // Full width on mobile
                              } else if (width < 900) {
                                cardWidth = (width - 60) / 2; // 2 columns
                              } else if (width < 1200) {
                                cardWidth = (width - 72) / 3; // 3 columns
                              } else if (width < 1600) {
                                cardWidth = (width - 96) / 4; // 4 columns
                              } else {
                                cardWidth = (width - 120) / 5; // 5 columns
                              }

                              return SingleChildScrollView(
                                physics: AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                                child: Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  children: _filteredCategories.map((category) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () => _showAddEditDialog(
                                            category: category),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Popup menu มุมขวาบน
                                              Align(
                                                alignment: Alignment.topRight,
                                                child: PopupMenuButton<String>(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _showAddEditDialog(
                                                          category: category);
                                                    } else if (value ==
                                                        'delete') {
                                                      _deleteCategory(category);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.edit,
                                                              color:
                                                                  Colors.blue),
                                                          SizedBox(width: 8),
                                                          Text('แก้ไข'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.delete,
                                                              color:
                                                                  Colors.red),
                                                          SizedBox(width: 8),
                                                          Text('ลบ'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey[700],
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              // ไอคอนตรงกลาง
                                              Container(
                                                padding: EdgeInsets.all(24),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  border: Border.all(
                                                    color: Colors.orange
                                                        .withOpacity(0.25),
                                                    width: 1.5,
                                                  ),
                                                ),
                                                child: Icon(
                                                  _getIconData(category[
                                                      'roomcate_icon']),
                                                  color: Colors.orange,
                                                  size: 56,
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              // ชื่ออยู่ใต้ไอคอน
                                              Text(
                                                category['roomcate_name'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.black87,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.add, color: Colors.white),
        tooltip: 'เพิ่มหมวดหมู่ห้อง',
      ),
    );
  }
}
