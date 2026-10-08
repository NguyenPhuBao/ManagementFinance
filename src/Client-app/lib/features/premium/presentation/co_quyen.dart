import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/quyen_tinh_nang.dart';
import 'cubit/goi_cubit.dart';

/// Hỏi quyền tính năng từ một trang (spec phân quyền 2026-10-08 mục 4.3 (2)).
///
/// Không có `GoiCubit` trên cây → `true`: chỉ test cũ dựng trang trần mới gặp, và quy ước của Premium là *không
/// provider = không khoá* (`PREMIUM_FEATURE.md`). Đọc bằng `context.read/watch` chứ không `BlocProvider.of` — cái sau
/// bọc `ProviderNotFoundException` thành `FlutterError`.
extension CoQuyenContext on BuildContext {
  /// Đăng ký phụ thuộc — dùng trong `build` để trang dựng lại khi gói / bảng quyền đổi.
  bool coQuyen(MaQuyen ma) {
    try {
      watch<GoiCubit>();
      return read<GoiCubit>().coQuyen(ma);
    } on ProviderNotFoundException {
      return true;
    }
  }

  /// Không đăng ký phụ thuộc — dùng trong handler / `initState`-sau.
  bool coQuyenDoc(MaQuyen ma) {
    try {
      return read<GoiCubit>().coQuyen(ma);
    } on ProviderNotFoundException {
      return true;
    }
  }
}
