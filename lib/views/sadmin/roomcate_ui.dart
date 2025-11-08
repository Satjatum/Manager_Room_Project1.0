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
    {'name': 'meeting_room', 'icon': Icons.meeting_room_outlined, 'label': 'ห้อง'},
    {'name': 'home_work', 'icon': Icons.home_work_outlined, 'label': 'อาคาร'},
    {'name': 'weekend', 'icon': Icons.weekend_outlined, 'label': 'โซฟา'},
    {'name': 'bathtub', 'icon': Icons.bathtub_outlined, 'label': 'ห้องน้ำ'},
    {'name': 'kitchen', 'icon': Icons.kitchen, 'label': 'ครัว'},
    {'name': 'balcony', 'icon': Icons.balcony, 'label': 'ระเบียง'},
    {'name': 'workspace', 'icon': Icons.workspaces_outline, 'label': 'ทำงาน'},
  ];

  IconData _getIconData(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.category;
    final opt = _iconOptions.firstWhere(
      (o) => o['name'] == iconName,
      orElse: () => {'icon': Icons.category},
    );
    return opt['icon'] as IconData;
  }

  Future<void> _showIconPicker(
      TextEditingController controller, String currentIcon) async {
    final selectedIcon = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
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
                  Text('เลือกไอคอน',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, color: Colors.grey[700]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 12),
              GridView.builder(
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
            ],
          ),
        ),
      ),
    );
    if (selectedIcon != null) controller.text = selectedIcon;
  }

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

  Future<void> _showAddEditDialog({Map<String, dynamic>? category}) async {
    final isEdit = category != null;
    final nameController = TextEditingController(
      text: isEdit ? category['roomcate_name'] : '',
    );
    final iconController = TextEditingController(
      text: isEdit ? (category['roomcate_icon'] ?? 'category') : 'category',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isEdit ? Icons.edit : Icons.add_circle_outline,
              color: AppTheme.primary,
            ),
            SizedBox(width: 8),
            Text(isEdit ? 'แก้ไขหมวดหมู่ห้อง' : 'เพิ่มหมวดหมู่ห้อง'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: () async {
                  await _showIconPicker(iconController, iconController.text);
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!, width: 1.2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getIconData(iconController.text),
                          size: 36, color: AppTheme.primary),
                      SizedBox(height: 6),
                      Text('แตะเพื่อเลือกไอคอน',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อหมวดหมู่ห้อง *',
                  hintText: 'เช่น ห้องเดี่ยว, ห้องคู่',
                  prefixIcon: Icon(Icons.grid_view),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('กรุณากรอกชื่อหมวดหมู่ห้อง'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(isEdit ? 'บันทึก' : 'เพิ่ม'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        );

        final data = {
          'roomcate_name': nameController.text.trim(),
          'roomcate_icon': iconController.text,
        };

        Map<String, dynamic> response;
        if (isEdit) {
          response = await RoomService.updateRoomCategory(
            category!['roomcate_id'],
            data,
          );
        } else {
          response = await RoomService.createRoomCategory(data);
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (response['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(response['message']),
                backgroundColor: Colors.green,
              ),
            );
            await _loadCategories();
          } else {
            throw Exception(response['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('ยืนยันการลบ'),
          ],
        ),
        content: Text(
          'คุณต้องการลบหมวดหมู่ห้อง "${category['roomcate_name']}" ใช่หรือไม่?\n\nหากมีห้องที่ใช้หมวดหมู่นี้อยู่ จะไม่สามารถลบได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
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

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (result['success']) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message']),
                backgroundColor: Colors.green,
              ),
            );
            await _loadCategories();
          } else {
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _categoryCard(BuildContext context, Map<String, dynamic> c) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showAddEditDialog(category: c),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            padding: EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(height: 6),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.purple.withOpacity(0.25)),
                  ),
                  child: Icon(
                    _getIconData(c['roomcate_icon']?.toString()),
                    color: Colors.purple,
                    size: 40,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  c['roomcate_name'] ?? '',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: PopupMenuButton<String>(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddEditDialog(category: c);
                } else if (value == 'delete') {
                  _deleteCategory(c);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('แก้ไข'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ลบ'),
                    ],
                  ),
                ),
              ],
              icon: Icon(Icons.more_vert, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (match amenities/roomtype style)
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Colors.black87),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                    },
                    tooltip: 'ย้อนกลับ',
                  ),
                  SizedBox(width: 8),
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
                                    Icon(Icons.grid_view_outlined,
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
                              final bool isMobile = width < 768;

                              if (isMobile) {
                                return SingleChildScrollView(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                                  child: Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: List.generate(
                                      _filteredCategories.length,
                                      (index) {
                                        final c = _filteredCategories[index];
                                        return ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: 160,
                                            maxWidth: 260,
                                          ),
                                          child: _categoryCard(context, c),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }

                              int cols = 2;
                              if (width >= 2560) cols = 5;
                              else if (width >= 1440) cols = 4;
                              else if (width >= 1024) cols = 3;
                              else if (width < 480) cols = 1;

                              return GridView.builder(
                                physics: AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.15,
                                ),
                                itemCount: _filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final c = _filteredCategories[index];
                                  return _categoryCard(context, c);
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
