import 'package:flutter/material.dart';

import '../../../transaction/presentation/pages/quet_anh_page.dart';

/// G107 — đứng trong cột Trang chủ, không vẽ gì: dựng lần đầu thì hỏi ảnh của lượt Quét bị bỏ dở (tiến trình chết lúc
/// máy ảnh / trình chọn ảnh đang mở) **một lần**, có ảnh thì mở `/quet` ([nhanAnhQuetBoDo]). Trang chủ là chỗ nút Quét
/// đứng và là đích của mọi lần mở app đã đăng nhập; `HomePage` là widget không trạng thái nên lượt hỏi cần một `State`
/// riêng — `build` chạy lại ở mỗi `AuthSuccess` phát lại và mỗi lần quay về tab.
class NhanAnhQuetBoDo extends StatefulWidget {
  const NhanAnhQuetBoDo({super.key, this.layAnhMat});

  /// `null` → `layAnhQuetBoDoThat` (`image_picker`). Tiêm cho test.
  final LayAnhBoDo? layAnhMat;

  @override
  State<NhanAnhQuetBoDo> createState() => _NhanAnhQuetBoDoState();
}

class _NhanAnhQuetBoDoState extends State<NhanAnhQuetBoDo> {
  @override
  void initState() {
    super.initState();
    // Sau khung đầu: `push` trong lúc cây đang dựng là lỗi của navigator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) nhanAnhQuetBoDo(context, layAnh: widget.layAnhMat);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
