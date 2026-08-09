import 'package:flutter/material.dart';

class GoalDetailPage extends StatelessWidget {
  final String id;
  const GoalDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết mục tiêu')),
      body: Center(child: Text('Chi tiết mục tiêu: $id')),
    );
  }
}

