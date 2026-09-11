import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/auth_repository.dart';
import 'bloc/auth_bloc.dart';

/// Huỷ yêu cầu xoá tài khoản từ một nút trên giao diện — dùng chung cho thẻ nhắc
/// ở Trang chủ và thẻ Vùng nguy hiểm ở Cài đặt (spec cưỡng chế đăng xuất §5.2–5.3).
///
/// Thành công hay không cũng phát `ThongTinTaiKhoanThayDoi`: huỷ được (kể cả đã
/// huỷ ở máy khác) thì repository đã đưa bộ nhớ đệm về Active, và việc thẻ biến
/// mất chính là phản hồi. Lỗi thì báo bằng `SnackBar`.
///
/// Bloc lấy TRƯỚC `await` và được báo cả khi nút đã rời cây giữa lúc chờ server
/// (rời Cài đặt chẳng hạn): bộ nhớ đệm đã đổi thì `AuthSuccess` phải đổi theo.
/// Chỉ `SnackBar` mới cần `context` còn gắn (soát cuối G33).
Future<void> huyYeuCauXoa(BuildContext context, AuthRepository repo) async {
  final authBloc = context.read<AuthBloc>();
  String? loi;
  try {
    await repo.cancelDelete();
  } catch (e) {
    loi = e.toString().replaceAll('Exception: ', '');
  }
  authBloc.add(ThongTinTaiKhoanThayDoi());
  if (loi == null) return;
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loi)));
}
