import 'package:flutter/material.dart';

import '../../../../core/utils/gioi_han_do_dai.dart';

/// Hộp "Đổi tên ví" (G63, spec mục 5.4; màn Stitch
/// `5fea1834ebe344e3a4f53ce64feee2bb` *"Quản lý ví - Hộp đổi tên ví"*). Trả tên
/// mới (đã cắt khoảng trắng) hoặc `null` khi Hủy. [kiemTen] trả câu lỗi hoặc
/// `null`; có lỗi thì nút Lưu tắt.
Future<String?> hoiTenMoiChoVi(
  BuildContext context, {
  required String goiY,
  required String? Function(String ten) kiemTen,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _HopDoiTen(goiY: goiY, kiemTen: kiemTen),
  );
}

class _HopDoiTen extends StatefulWidget {
  const _HopDoiTen({required this.goiY, required this.kiemTen});

  final String goiY;
  final String? Function(String ten) kiemTen;

  @override
  State<_HopDoiTen> createState() => _HopDoiTenState();
}

class _HopDoiTenState extends State<_HopDoiTen> {
  late final TextEditingController _ten =
      TextEditingController(text: widget.goiY);

  @override
  void dispose() {
    _ten.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _ten,
      builder: (context, v, _) {
        final loi = widget.kiemTen(v.text);
        return AlertDialog(
          title: const Text('Đổi tên ví'),
          content: TextField(
            key: const ValueKey('o-ten-vi-moi'),
            controller: _ten,
            autofocus: true,
            // Ô tên ví — cùng bộ lọc với màn Thêm / Sửa ví (bẫy 10): tên dài
            // hơn cột vỡ P2000 và ví không bao giờ lên server.
            inputFormatters: const [GioiHanDoRong(DoRongCot.tenVi)],
            decoration: InputDecoration(labelText: 'Tên mới', errorText: loi),
          ),
          actions: [
            // `Navigator.pop`, KHÔNG `context.pop` của go_router: hộp nằm
            // ngoài cây route.
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            TextButton(
              key: const ValueKey('nut-luu-ten-vi'),
              onPressed: loi == null
                  ? () => Navigator.pop(context, v.text.trim())
                  : null,
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }
}
