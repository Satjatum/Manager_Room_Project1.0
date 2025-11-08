import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../widgets/colors.dart';

class RoomCategoriesUI extends StatefulWidget {
  const RoomCategoriesUI({Key? key}) : super(key: key);

  @override
  State<RoomCategoriesUI> createState() => _RoomCategoriesUIState();
}

class _RoomCategoriesUIState extends State<RoomCategoriesUI> {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
                            SizedBox(height: 6),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                option['label'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey[700],
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
      text: isEdit ? category['roomcate_icon'] ?? 'category' : 'category',
    );

    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit : Icons.add,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'แก้ไขหมวดหมู่ห้อง' : 'เพิ่มหมวดหมู่ห้อง',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            isEdit
                                ? 'แก้ไขข้อมูลหมวดหมู่ห้อง'
                                : 'กรอกข้อมูลหมวดหมู่ห้องใหม่',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.grey[700]),
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 24),

                // Name field
                Text(
                  'ชื่อหมวดหมู่ห้อง',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: nameController,
                    enabled: !isSubmitting,
                    decoration: InputDecoration(
                      hintText: 'กรอกชื่อหมวดหมู่ห้อง',
                      hintStyle:
                          TextStyle(color: Colors.grey[500], fontSize: 14),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                SizedBox(height: 20),

                // Icon field
                Text(
                  'ไอคอน',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                InkWell(
                  onTap: isSubmitting
                      ? null
                      : () =>
                          _showIconPicker(iconController, iconController.text),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          _getIconData(iconController.text),
                          color: AppTheme.primary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'เลือกไอคอน',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (nameController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('กรุณากรอกชื่อหมวดหมู่ห้อง'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              setDialogState(() => isSubmitting = true);

                              try {
                                // Show progress overlay similar to amenities_ui
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

                                if (mounted) Navigator.of(context).pop(); // close progress

                                if (mounted) {
                                  if ((resp['success'] == true)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            resp['message'] ?? 'ดำเนินการสำเร็จ'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    Navigator.of(context).pop(); // close add/edit dialog
                                    await _loadCategories();
                                  } else {
                                    throw Exception(resp['message'] ?? 'ดำเนินการไม่สำเร็จ');
                                  }
                                }
                              } catch (e) {
                                if (mounted && Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop(); // ensure progress closed
                                }
                                setDialogState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        e.toString().replaceAll('Exception: ', ''),
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: isSubmitting
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
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete, color: Colors.red, size: 20),
            ),
            SizedBox(width: 12),
            Text(
              'ลบหมวดหมู่ห้อง',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการลบหมวดหมู่ห้อง "${category['roomcate_name']}" ใช่หรือไม่?\n\nการดำเนินการนี้ไม่สามารถย้อนกลับได้',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                  color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'ลบ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Progress overlay similar to amenities_ui
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final result = await RoomService.deleteRoomCategory(
          category['roomcate_id'],
        );

        if (mounted) Navigator.of(context).pop(); // close progress

        if (mounted) {
          if (result['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'ลบสำเร็จ'),
                backgroundColor: Colors.green,
              ),
            );
            await _loadCategories();
          } else {
            throw Exception(result['message'] ?? 'ลบไม่สำเร็จ');
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // ensure progress closed
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.toString().replaceAll('Exception: ', ''),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.category,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Room Category Management',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage room categories and icons',
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
            // Search
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
                    filled: true,
                    fillColor: Colors.white,
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

                              return GridView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                                gridDelegate:
                                    SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: isMobile ? 160 : 200,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.85,
                                ),
                                itemCount: _filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final category = _filteredCategories[index];

                                  if (isMobile) {
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => _showAddEditDialog(
                                          category: category),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[300]!,
                                          ),
                                        ),
                                        padding: EdgeInsets.all(12),
                                        child: Column(
                                          children: [
                                            Align(
                                              alignment: Alignment.topRight,
                                              child: PopupMenuButton<String>(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                onSelected: (value) {
                                                  if (value == 'edit') {
                                                    _showAddEditDialog(
                                                      category: category,
                                                    );
                                                  } else if (value ==
                                                      'delete') {
                                                    _deleteCategory(category);
                                                  }
                                                },
                                                itemBuilder: (context) =>
                                                    const [
                                                  PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('แก้ไข'),
                                                      ],
                                                    ),
                                                  ),
                                                  PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('ลบ'),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                icon: Icon(
                                                  Icons.more_vert,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () =>
                                        _showAddEditDialog(category: category),
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          padding: EdgeInsets.all(12),
                                          child: Column(
                                            children: [
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
                                                        category: category,
                                                      );
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
                                                          Icon(
                                                            Icons.edit,
                                                            color: Colors.blue,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('แก้ไข'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.delete,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text('ลบ'),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Container(
                                                padding: EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Colors.blue.withOpacity(
                                                    0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: Colors.blue
                                                        .withOpacity(0.25),
                                                  ),
                                                ),
                                                child: Icon(
                                                  _getIconData(
                                                    category['roomcate_icon'],
                                                  ),
                                                  color: Colors.blue,
                                                  size: 40,
                                                ),
                                              ),
                                              SizedBox(height: 12),
                                              Text(
                                                category['roomcate_name'] ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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
