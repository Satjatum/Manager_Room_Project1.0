import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../widgets/colors.dart';

class RoomTypesUI extends StatefulWidget {
  const RoomTypesUI({Key? key}) : super(key: key);

  @override
  State<RoomTypesUI> createState() => _RoomTypesUIState();
}

class _RoomTypesUIState extends State<RoomTypesUI> {
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _filteredRoomTypes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Icon options for room types (similar style to amenities)
  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'category', 'icon': Icons.category, 'label': 'หมวดหมู่'},
    {'name': 'hotel', 'icon': Icons.hotel, 'label': 'เตียง'},
    {'name': 'apartment', 'icon': Icons.apartment, 'label': 'อพาร์ตเมนต์'},
    {'name': 'home', 'icon': Icons.home_outlined, 'label': 'บ้าน'},
    {'name': 'door_front', 'icon': Icons.door_front_door, 'label': 'ประตูหน้า'},
    {'name': 'meeting', 'icon': Icons.meeting_room_outlined, 'label': 'ห้อง'},
    {'name': 'king_bed', 'icon': Icons.king_bed_outlined, 'label': 'King'},
    {'name': 'single_bed', 'icon': Icons.single_bed_outlined, 'label': 'Single'},
    {'name': 'workspace', 'icon': Icons.workspaces_outline, 'label': 'ทำงาน'},
    {'name': 'weekend', 'icon': Icons.weekend_outlined, 'label': 'โซฟา'},
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
                              option['name'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? AppTheme.primary
                                    : Colors.grey[700],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side:
                            BorderSide(color: Colors.grey[300]!, width: 1.2),
                        foregroundColor: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text('ยกเลิก'),
                    ),
                  ),
                ],
              )
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
    _loadRoomTypes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoomTypes() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final roomTypes = await RoomService.getRoomTypes();
      if (mounted) {
        setState(() {
          _roomTypes = roomTypes;
          _filteredRoomTypes = roomTypes;
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
      _filteredRoomTypes = _roomTypes.where((type) {
        final name = (type['roomtype_name'] ?? '').toString().toLowerCase();
        final searchLower = query.toLowerCase();
        return name.contains(searchLower);
      }).toList();
    });
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? roomType}) async {
    final isEdit = roomType != null;
    final nameController = TextEditingController(
      text: isEdit ? roomType['roomtype_name'] : '',
    );
    final iconController = TextEditingController(
      text: isEdit ? (roomType['roomtype_icon'] ?? 'category') : 'category',
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
            Text(isEdit ? 'แก้ไขประเภทห้อง' : 'เพิ่มประเภทห้อง'),
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
                  labelText: 'ชื่อประเภทห้อง *',
                  hintText: 'เช่น ห้องพัดลม, ห้องแอร์',
                  prefixIcon: Icon(Icons.category),
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
                    content: Text('กรุณากรอกชื่อประเภทห้อง'),
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
          'roomtype_name': nameController.text.trim(),
          'roomtype_icon': iconController.text,
        };

        Map<String, dynamic> response;
        if (isEdit) {
          response = await RoomService.updateRoomType(
            roomType['roomtype_id'],
            data,
          );
        } else {
          response = await RoomService.createRoomType(data);
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
            await _loadRoomTypes();
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

  Future<void> _deleteRoomType(Map<String, dynamic> roomType) async {
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
          'คุณต้องการลบประเภทห้อง "${roomType['roomtype_name']}" ใช่หรือไม่?\n\nหากมีห้องที่ใช้ประเภทนี้อยู่ จะไม่สามารถลบได้',
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

        final result = await RoomService.deleteRoomType(
          roomType['roomtype_id'],
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
            await _loadRoomTypes();
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
                          'Room Type Management',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage room types and icons',
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
                    hintText: 'ค้นหาประเภทห้อง',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            // Count
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Showing ${_filteredRoomTypes.length} of ${_roomTypes.length} types',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: _loadRoomTypes,
                child: _isLoading
                    ? ListView(
                        physics: AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(height: 120),
                          Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                        ],
                      )
                    : _filteredRoomTypes.isEmpty
                        ? ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 120),
                              Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.category_outlined, size: 80, color: Colors.grey[400]),
                                    SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty ? 'ไม่พบประเภทห้องที่ค้นหา' : 'ยังไม่มีประเภทห้อง',
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
                                    SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddEditDialog(),
                                      icon: Icon(Icons.add),
                                      label: Text('เพิ่มประเภทห้องแรก'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                                    children: List.generate(_filteredRoomTypes.length, (index) {
                                      final t = _filteredRoomTypes[index];
                                      return ConstrainedBox(
                                        constraints: BoxConstraints(minWidth: 160, maxWidth: 260),
                                        child: _typeCard(context, t),
                                      );
                                    }),
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
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 1.15,
                                ),
                                itemCount: _filteredRoomTypes.length,
                                itemBuilder: (context, index) {
                                  final t = _filteredRoomTypes[index];
                                  return _typeCard(context, t);
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
        tooltip: 'เพิ่มประเภทห้อง',
      ),
    );
  }

  Widget _typeCard(BuildContext context, Map<String, dynamic> t) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showAddEditDialog(roomType: t),
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
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.25)),
                  ),
                  child: Icon(
                    _getIconData(t['roomtype_icon']?.toString()),
                    color: Colors.blue,
                    size: 40,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  t['roomtype_name'] ?? '',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                if (value == 'edit') {
                  _showAddEditDialog(roomType: t);
                } else if (value == 'delete') {
                  _deleteRoomType(t);
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
}
