import 'trang_thai_goi.dart';

/// Trần của gói Basic và câu hỏi *"được tạo thêm không"* — MỘT định nghĩa cho
/// cả ba loại (spec Premium 2026-10-06 mục 5.2), kiểu `viTinhVaoTong`. Hàm
/// KHÔNG biết đếm: nó nhận số đang hoạt động (`DemDangHoatDong`, tầng data).
enum LoaiTran { vi, nganSach, mucTieu }

class TranGoi {
  const TranGoi({
    required this.vi,
    required this.nganSach,
    required this.mucTieu,
  });

  final int vi;
  final int nganSach;
  final int mucTieu;

  /// 3/3/3 — người dùng chốt 2026-10-06 (giữ 3 ví dù tài khoản mới đã có sẵn
  /// 2 ví seed). Server đè bằng `limits` của `/payment/subscription-info`.
  static const macDinh = TranGoi(vi: 3, nganSach: 3, mucTieu: 3);

  int cua(LoaiTran loai) => switch (loai) {
        LoaiTran.vi => vi,
        LoaiTran.nganSach => nganSach,
        LoaiTran.mucTieu => mucTieu,
      };

  Map<String, Object?> toJson() =>
      {'wallets': vi, 'budgets': nganSach, 'goals': mucTieu};

  /// `limits` của server. Ô thiếu / rác / không dương → mặc định cho ĐÚNG ô ấy.
  static TranGoi tuJson(Object? json) {
    if (json is! Map) return macDinh;
    int doc(String khoa, int macDinhO) {
      final v = json[khoa];
      return v is num && v > 0 ? v.toInt() : macDinhO;
    }

    return TranGoi(
      vi: doc('wallets', macDinh.vi),
      nganSach: doc('budgets', macDinh.nganSach),
      mucTieu: doc('goals', macDinh.mucTieu),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TranGoi &&
      other.vi == vi &&
      other.nganSach == nganSach &&
      other.mucTieu == mucTieu;

  @override
  int get hashCode => Object.hash(vi, nganSach, mucTieu);

  @override
  String toString() => 'TranGoi(vi: $vi, nganSach: $nganSach, mucTieu: $mucTieu)';
}

sealed class KetQuaTran {
  const KetQuaTran();
}

class Duoc extends KetQuaTran {
  const Duoc();
}

class Vuot extends KetQuaTran {
  const Vuot({required this.loai, required this.tran, required this.dangCo});
  final LoaiTran loai;
  final int tran;
  final int dangCo;
}

/// Premium (còn hạn theo [now]) → luôn [Duoc], không nhìn [dangCo].
/// Basic → `dangCo >= tran` là [Vuot]: BẰNG trần là vượt (3/3 không tạo cái
/// thứ tư); người bị hạ cấp đang có 5 cũng chỉ bị chặn tạo, không mất gì.
KetQuaTran conTaoDuoc({
  required LoaiTran loai,
  required int dangCo,
  required TrangThaiGoi goi,
  required DateTime now,
}) {
  if (goi.laPremium(now)) return const Duoc();
  final tran = goi.tran.cua(loai);
  return dangCo >= tran
      ? Vuot(loai: loai, tran: tran, dangCo: dangCo)
      : const Duoc();
}

/// Mã trong query `?tran=` của `/premium`.
String maTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'vi',
      LoaiTran.nganSach => 'ngan_sach',
      LoaiTran.mucTieu => 'muc_tieu',
    };

LoaiTran? loaiTranTuMa(String? ma) => switch (ma) {
      'vi' => LoaiTran.vi,
      'ngan_sach' => LoaiTran.nganSach,
      'muc_tieu' => LoaiTran.mucTieu,
      _ => null,
    };

String tenTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'ví',
      LoaiTran.nganSach => 'ngân sách',
      LoaiTran.mucTieu => 'mục tiêu tiết kiệm',
    };
