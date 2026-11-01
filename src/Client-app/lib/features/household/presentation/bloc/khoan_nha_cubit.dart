import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../category/data/models/category_entity.dart';
import '../../../transaction/data/models/transaction_entity.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';

/// [ds] là khoản THÔ của nhà (kể cả neo): trang lọc bằng `locHoatDong`. [danhMuc] là bảng tra tên (không phải danh sách chọn).
typedef KhoanNhaState = ({List<TransactionEntity> ds, List<CategoryEntity> danhMuc, bool daNap});

/// Khoản của MỘT nhà cho Hoạt động (đợt 1B, Task 6). Nghe `theoDoiKhoan`: khoản máy khác ghi hay vừa kéo về đều hiện. Cubit gắn
/// với một nhà — nhà đổi thì trang dựng cái mới. [idaccount] từ phiên; `null` (chưa có phiên) thì không có bảng tra tên, chứ
/// không đoán một tài khoản.
class KhoanNhaCubit extends Cubit<KhoanNhaState> {
  KhoanNhaCubit(DuLieuNhaRepository duLieu, this.idNha, {String? walletId, int? idaccount})
      : super((ds: const [], danhMuc: const [], daNap: false)) {
    _subKhoan = duLieu.theoDoiKhoan(idNha, walletId: walletId).listen(
      (ds) {
        if (!isClosed) emit((ds: ds, danhMuc: state.danhMuc, daNap: true));
      },
      // Luồng hỏng thì trang vẫn phải thôi quay: giữ danh sách cũ và coi như đã nạp.
      onError: (Object _) {
        if (!isClosed) emit((ds: state.ds, danhMuc: state.danhMuc, daNap: true));
      },
    );
    if (idaccount != null) {
      _subDanhMuc = duLieu.theoDoiBangTraDanhMuc(idaccount).listen(
        (dm) {
          if (!isClosed) emit((ds: state.ds, danhMuc: dm, daNap: state.daNap));
        },
        onError: (Object _) {},
      );
    }
  }

  final int idNha;
  late final StreamSubscription<List<TransactionEntity>> _subKhoan;
  StreamSubscription<List<CategoryEntity>>? _subDanhMuc;

  @override
  Future<void> close() async {
    await _subKhoan.cancel();
    await _subDanhMuc?.cancel();
    return super.close();
  }
}
