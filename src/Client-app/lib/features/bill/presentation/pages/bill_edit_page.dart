import 'package:flutter/material.dart';

class BillEditPage extends StatelessWidget {
  final String id;
  const BillEditPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa hóa đơn')),
      body: Center(child: Text('Sửa hóa đơn: $id')),
    );
  }
}

