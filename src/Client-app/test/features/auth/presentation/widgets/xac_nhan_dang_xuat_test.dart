import 'package:flowmoney/features/auth/presentation/widgets/xac_nhan_dang_xuat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hộp xác nhận đăng xuất không hứa đăng nhập offline; nói rõ đăng nhập lại cần mạng', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(onPressed: () => xacNhanDangXuat(context), child: const Text('mở')),
      ),
    ));
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    expect(find.textContaining('offline'), findsNothing,
        reason: 'app không có đăng nhập offline (đăng nhập lại luôn gọi máy chủ) — câu cũ hứa sai');
    expect(find.textContaining('Đăng nhập lại cần có kết nối mạng'), findsOneWidget);
  });
}
