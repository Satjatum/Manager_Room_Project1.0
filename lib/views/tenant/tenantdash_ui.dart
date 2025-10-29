import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:manager_room_project/views/widgets/subnavbar.dart';

class TenantdashUi extends StatefulWidget {
  const TenantdashUi({super.key});

  @override
  State<TenantdashUi> createState() => _TenantdashUiState();
}

class _TenantdashUiState extends State<TenantdashUi> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      bottomNavigationBar: Subnavbar(currentIndex: 0),
    );
  }
}
