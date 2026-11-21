import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../design/design.dart';
import '../look/owner_look.dart';
import '../strings/owner_shared_strings.dart';

class OwnerStubScreen extends StatelessWidget {
  const OwnerStubScreen({super.key, required this.title, required this.look, this.openRoute, this.openArgs, this.root = false});

  final String title;
  final OwnerLook look;
  final String? openRoute;
  final Object? openArgs;
  final bool root;

  @override
  Widget build(BuildContext context) {
    final route = openRoute;
    return Scaffold(
      backgroundColor: look.page,
      appBar: root ? null : AppBar(title: Text(title), backgroundColor: look.page, elevation: 0),
      body: SafeArea(
        child: Center(
          child: StateCard(
            title: title,
            kit: look.kit,
            actionLabel: route == null ? null : OwnerSharedStrings.open,
            onAction: route == null ? null : () => Get.toNamed(route, arguments: openArgs),
          ),
        ),
      ),
    );
  }
}
