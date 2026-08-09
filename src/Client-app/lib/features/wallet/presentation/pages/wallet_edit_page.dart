import 'package:flutter/material.dart';

class WalletEditPage extends StatelessWidget {
  final String id;
  const WalletEditPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa ví')),
      body: Center(child: Text('Sửa ví: $id')),
    );
  }
}

