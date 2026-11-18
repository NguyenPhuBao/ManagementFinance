/// Hàm thật của `KhoanNhaChoSoNguon` (spec 2026-11-16 mục 3): bảng tra tên của nhà hiện tại (ví chung + danh mục) cho dòng
/// khoản nhà ở Sổ / Trang chủ, và quyền sửa / xoá một khoản nhà từ Sổ.
library;

import 'dart:async';

import '../../category/data/models/category_entity.dart';
import '../../transaction/data/khoan_nha_cho_so_nguon.dart';
import '../../transaction/data/models/transaction_entity.dart';
import '../../wallet/data/models/wallet_entity.dart';
import '../data/models/nha_cua_toi.dart';
import '../domain/hoat_dong_nha.dart';

/// Theo dõi nhà hiện tại: mỗi lần NHÀ đổi (vào / rời / sang nhà khác) thì huỷ hai stream của nhà cũ và nghe nhà mới — phép
/// "đổi stream" tự viết (dự án không có rxdart). [nha] nên phát giá trị hiện tại trước (DI nối `hienTai` + `theoDoi`).
Stream<TraTenNha> theoDoiTraTenNha({
  required Stream<NhaCuaToi> nha,
  required Stream<List<WalletEntity>> Function(int idNha) viChung,
  required Stream<List<CategoryEntity>> Function(int idaccount) danhMuc,
  required int idaccount,
}) {
  late final StreamController<TraTenNha> ra;
  StreamSubscription<NhaCuaToi>? subNha;
  StreamSubscription<List<WalletEntity>>? subVi;
  StreamSubscription<List<CategoryEntity>>? subDm;
  var daNghe = false;
  int? dangTheo;

  // Chụp hai stream cũ ĐỒNG BỘ rồi mới huỷ: huỷ sau một `await` là huỷ nhầm stream của nhà mới vừa gán.
  void huyTrong() {
    final vi = subVi, dm = subDm;
    subVi = subDm = null;
    unawaited(vi?.cancel());
    unawaited(dm?.cancel());
  }

  ra = StreamController<TraTenNha>(
    onListen: () {
      subNha = nha.listen((t) {
        final n = t.nha;
        if (daNghe && n?.id == dangTheo) return;
        daNghe = true;
        dangTheo = n?.id;
        huyTrong();
        if (n == null) {
          ra.add(TraTenNha.rong);
          return;
        }
        var vi = const <WalletEntity>[];
        var dm = const <CategoryEntity>[];
        void phat() => ra.add(TraTenNha(idNha: n.id, tenNha: n.ten, vi: vi, danhMuc: dm));
        phat();
        subVi = viChung(n.id).listen((v) {
          vi = v;
          phat();
        }, onError: (Object _) {});
        subDm = danhMuc(idaccount).listen((d) {
          dm = d;
          phat();
        }, onError: (Object _) {});
      }, onError: (Object _) => ra.add(TraTenNha.rong));
    },
    onCancel: () async {
      huyTrong();
      await subNha?.cancel();
    },
  );
  return ra.stream;
}

/// Quyền sửa / xoá một khoản nhà từ Sổ — cùng luật `quyenKhoanNha` của màn Hoạt động. Khoản của nhà KHÁC nhà hiện tại (đã
/// rời, dữ liệu chưa dọn) → không gì.
({bool sua, bool xoa}) quyenKhoanNhaTuSo(TransactionEntity t, {required NhaCuaToi nha, required int? idToi}) {
  final n = nha.nha;
  if (n == null || t.idhousehold != n.id) return (sua: false, xoa: false);
  return quyenKhoanNha(t, vai: nha.vai, trangThai: n.trangThai, idToi: idToi);
}
