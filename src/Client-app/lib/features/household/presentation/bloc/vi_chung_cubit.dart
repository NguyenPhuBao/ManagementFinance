import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../goal/data/models/goal_entity.dart';
import '../../../wallet/data/models/wallet_entity.dart';
import '../../../wallet/domain/wallet_status.dart';
import '../../data/repositories/du_lieu_nha_repository.dart';
import '../../domain/muc_tieu_chung.dart';

typedef ViChungState = ({List<WalletEntity> vi, Map<String, GoalEntity> mucTieu, bool daNap});

/// Ví chung của MỘT nhà cho khối VÍ CHUNG ở Nhà mình (đợt 1B, Task 5). Nghe `theoDoiViChung`: ví về từ lượt kéo về hay do
/// máy khác tạo đều hiện, không phải tải lại. Cubit gắn với một nhà — nhà đổi thì trang dựng cubit mới, không tái dùng.
///
/// Từ đợt 2 nghe thêm mục tiêu chung (theo ví). `daNap` chỉ đúng khi CẢ HAI luồng đã phát lần đầu: ví về trước mà đã `daNap`
/// thì thẻ hiện không thanh rồi nhấp nháy sang có thanh.
class ViChungCubit extends Cubit<ViChungState> {
  ViChungCubit(DuLieuNhaRepository duLieu, this.idNha) : super((vi: const [], mucTieu: const {}, daNap: false)) {
    void phat({List<WalletEntity>? vi, Map<String, GoalEntity>? mucTieu}) {
      if (isClosed) return;
      emit((vi: vi ?? state.vi, mucTieu: mucTieu ?? state.mucTieu, daNap: _daVi && _daMuc));
    }

    _sub = duLieu.theoDoiViChung(idNha).listen(
      (ds) {
        _daVi = true;
        phat(vi: ds);
      },
      // Luồng hỏng thì khối vẫn phải thôi quay: giữ danh sách cũ (rỗng nếu chưa có) và coi như đã nạp.
      onError: (Object _) {
        _daVi = true;
        phat();
      },
    );
    _subMuc = duLieu.theoDoiMucTieuChung(idNha).listen(
      (ds) {
        _daMuc = true;
        phat(mucTieu: mucTieuTheoVi(ds));
      },
      // Mục tiêu hỏng thì ví vẫn hiện, chỉ không có thanh.
      onError: (Object _) {
        _daMuc = true;
        phat();
      },
    );
  }

  final int idNha;
  late final StreamSubscription<List<WalletEntity>> _sub;
  late final StreamSubscription<List<GoalEntity>> _subMuc;
  var _daVi = false;
  var _daMuc = false;

  Iterable<WalletEntity> get _dangHoatDong => state.vi.where((v) => !v.isDeleted && WalletStatus.laHoatDong(v.status));

  /// Σ số dư ví đang hoạt động: ví lưu trữ đóng băng nên không cộng vào quỹ.
  double get tongQuy => _dangHoatDong.fold(0.0, (tong, v) => tong + v.balance);

  /// Số ví đang hoạt động — đó cũng là số server đếm vào trần `maxSharedWallets`.
  int get soDangHoatDong => _dangHoatDong.length;

  @override
  Future<void> close() async {
    await _sub.cancel();
    await _subMuc.cancel();
    return super.close();
  }
}
