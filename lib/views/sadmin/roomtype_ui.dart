import 'package:flutter/material.dart';
// Services //
import '../../services/room_service.dart';
// Widgets //
import '../widgets/colors.dart';
import '../widgets/snack_message.dart';

class RoomTypesUi extends StatefulWidget {
  final String? branchId;
  final String? branchName;

  const RoomTypesUi({Key? key, this.branchId, this.branchName})
      : super(key: key);

  @override
  State<RoomTypesUi> createState() => _RoomTypesUiState();
}

class _RoomTypesUiState extends State<RoomTypesUi> {
  List<Map<String, dynamic>> _roomTypes = [];
  List<Map<String, dynamic>> _filteredRoomTypes = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedBranchId;
  // String _selectedBranchName = '';
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
    {
      'name': 'single_bed',
      'icon': Icons.single_bed_outlined,
      'label': 'Single'
    },
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
                      onPressed: () => Navigator.pop(context),
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
    if (selectedIcon != null) controller.text = selectedIcon;
  }

  @override
  void initState() {
    super.initState();
    _selectedBranchId = widget.branchId;
    // _selectedBranchName = widget.branchName ?? '';
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
        // Filter by branchId if provided
        final filteredByBranch = _selectedBranchId != null
            ? roomTypes.where((type) {
                return type['branch_id']?.toString() == _selectedBranchId;
              }).toList()
            : roomTypes;

        setState(() {
          _roomTypes = filteredByBranch;
          _filteredRoomTypes = filteredByBranch;
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
                  isEdit ? 'แก้ไขประเภทห้อง' : 'เพิ่มประเภทห้อง',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 16),
                // Icon selector box
                InkWell(
                  onTap: () async {
                    await _showIconPicker(iconController, iconController.text);
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
                    labelText: 'ชื่อประเภทห้อง',
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
                        onPressed: () => Navigator.pop(context, false),
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
                        onPressed: () {
                          if (nameController.text.trim().isEmpty) {
                            debugPrint('กรุณากรอกชื่อประเภทห้อง');
                            SnackMessage.showError(
                                context, 'กรุณากรอกชื่อประเภทห้อง');

                            return;
                          }
                          Navigator.pop(context, true);
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
                            Icon(isEdit ? Icons.save_outlined : Icons.add),
                            SizedBox(width: 8),
                            Text(
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
          // Validate branch selection for create operation
          if (_selectedBranchId == null) {
            if (mounted) Navigator.pop(context);
            if (mounted) {
              SnackMessage.showError(
                  context, 'กรุณาเลือกสาขา (branch) ก่อนเพิ่มประเภทห้อง');
            }
            return;
          }
          response = await RoomService.createRoomType(data,
              branchId: _selectedBranchId);
        }

        if (mounted) Navigator.pop(context);

        if (mounted) {
          if (response['success']) {
            debugPrint(response['message']);
            SnackMessage.showSuccess(context, response['message']);
            await _loadRoomTypes();
          } else {
            debugPrint("เกิดข้อผิดพลาด {$response['message']}");
            throw Exception(response['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          debugPrint('เกิดข้อผิดพลาด: $e');
          SnackMessage.showError(context, 'เกิดข้อผิดพลาด');
        }
      }
    }
  }

  Future<void> _deleteRoomType(Map<String, dynamic> roomType) async {
    final String name = (roomType['roomtype_name'] ?? '').toString();
    final String id = (roomType['roomtype_id'] ?? '').toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
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
                'ลบประเภทห้องหรือไม่?',
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
    );

    if (confirm == true) {
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
                    'กำลังลบประเภทห้อง...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'กรุณารอสักครู่...',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        );

        final result = await RoomService.deleteRoomType(id);
        if (mounted) Navigator.of(context).pop();

        if (mounted) {
          if (result['success'] == true) {
            debugPrint(result['message']);
            SnackMessage.showSuccess(context, result['message'] ?? 'ลบสำเร็จ');
            await _loadRoomTypes();
          } else {
            debugPrint("เกิดข้อผิดพลาด {$result['message']}");
            throw Exception(result['message']);
          }
        }
      } catch (e) {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
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
                          'ประเภทห้อง',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'สำหรับจัดการประเภทห้องของที่พัก',
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
                    hintText: 'ค้นหาประเภทห้อง',
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
                          Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primary,
                            ),
                          ),
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
                                    Icon(
                                      Icons.category_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'ไม่พบประเภทห้องที่ค้นหา'
                                          : 'ยังไม่มีประเภทห้อง',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: () => _showAddEditDialog(),
                                      icon: Icon(Icons.add),
                                      label: Text('เพิ่มประเภทห้องแรก'),
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
                              if (width < 900) {
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
                                  children: _filteredRoomTypes.map((t) {
                                    return SizedBox(
                                      width: cardWidth,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: () =>
                                            _showAddEditDialog(roomType: t),
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
                                                  color: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  onSelected: (value) {
                                                    if (value == 'edit') {
                                                      _showAddEditDialog(
                                                          roomType: t);
                                                    } else if (value ==
                                                        'delete') {
                                                      _deleteRoomType(t);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    PopupMenuItem(
                                                      value: 'edit',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .edit_outlined,
                                                              size: 20,
                                                              color: Color(
                                                                  0xFF14B8A6)),
                                                          SizedBox(width: 12),
                                                          Text('แก้ไข'),
                                                        ],
                                                      ),
                                                    ),
                                                    PopupMenuItem(
                                                      value: 'delete',
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .delete_outline,
                                                              size: 20,
                                                              color:
                                                                  Colors.red),
                                                          SizedBox(width: 12),
                                                          Text('ลบ',
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .red)),
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
                                                  _getIconData(
                                                      t['roomtype_icon']
                                                          ?.toString()),
                                                  color: Colors.orange,
                                                  size: 56,
                                                ),
                                              ),
                                              SizedBox(height: 16),
                                              // ชื่ออยู่ใต้ไอคอน
                                              Text(
                                                t['roomtype_name'] ?? '',
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
        tooltip: 'เพิ่มประเภทห้อง',
      ),
    );
  }
}
