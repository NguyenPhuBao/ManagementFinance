import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/domain/wallet_status.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';

typedef ViChungState = ({List<WalletEntity> vi, bool daNap});

/// Ví chung của MỘT nhà cho khối VÍ CHUNG ở Nhà mình (đợt 1B, Task 5). Nghe `theoDoiViChung`: ví về từ lượt kéo về hay do
/// máy khác tạo đều hiện, không phải tải lại. Cubit gắn với một nhà — nhà đổi thì trang dựng cubit mới, không tái dùng.
class ViChungCubit extends Cubit<ViChungState> {
  ViChungCubit(DuLieuNhaRepository duLieu, this.idNha) : super((vi: const [], daNap: false)) {
    _sub = duLieu.theoDoiViChung(idNha).listen(
      (ds) {
        if (!isClosed) emit((vi: ds, daNap: true));
      },
      // Luồng hỏng thì khối vẫn phải thôi quay: giữ danh sách cũ (rỗng nếu chưa có) và coi như đã nạp.
      onError: (Object _) {
        if (!isClosed) emit((vi: state.vi, daNap: true));
      },
    );
  }

  final int idNha;
  late final StreamSubscription<List<WalletEntity>> _sub;

  Iterable<WalletEntity> get _dangHoatDong => state.vi.where((v) => !v.isDeleted && WalletStatus.laHoatDong(v.status));

  /// Σ số dư ví đang hoạt động: ví lưu trữ đóng băng nên không cộng vào quỹ.
  double get tongQuy => _dangHoatDong.fold(0.0, (tong, v) => tong + v.balance);

  /// Số ví đang hoạt động — đó cũng là số server đếm vào trần `maxSharedWallets`.
  int get soDangHoatDong => _dangHoatDong.length;

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
