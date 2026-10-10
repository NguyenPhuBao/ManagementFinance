import 'trang_thai_goi.dart';

/// Trần của gói Basic và câu hỏi *"được tạo thêm không"* — MỘT định nghĩa cho
/// cả ba loại (spec Premium 2026-10-06 mục 5.2), kiểu `viTinhVaoTong`. Hàm
/// KHÔNG biết đếm: nó nhận số đang hoạt động (`DemDangHoatDong`, tầng data).
enum LoaiTran { vi, nganSach, mucTieu, hoaDon, danhMucRieng }

class TranGoi {
  const TranGoi({
    this.vi,
    this.nganSach,
    this.mucTieu,
    this.hoaDon,
    this.danhMucRieng,
  });

  final int? vi;
  final int? nganSach;
  final int? mucTieu;
  final int? hoaDon;
  final int? danhMucRieng;

  /// 3/3/3 — server đè bằng `limits` của `/payment/subscription-info`. Hoá đơn và danh mục riêng: thiếu khoá = không
  /// giới hạn (spec phân quyền 2026-10-08 mục 2 #1 — server cũ không trả hai khoá ấy thì giữ chốt 06/10 *"Mở"*).
  static const macDinh = TranGoi(vi: 3, nganSach: 3, mucTieu: 3);

  int? cua(LoaiTran loai) => switch (loai) {
        LoaiTran.vi => vi,
        LoaiTran.nganSach => nganSach,
        LoaiTran.mucTieu => mucTieu,
        LoaiTran.hoaDon => hoaDon,
        LoaiTran.danhMucRieng => danhMucRieng,
      };

  Map<String, Object?> toJson() => {
        'wallets': vi,
        'budgets': nganSach,
        'goals': mucTieu,
        'bills': hoaDon,
        'custom_categories': danhMucRieng,
      };

  /// `limits` của server. Ô thiếu / rác → mặc định cho ĐÚNG ô ấy.
  /// Nếu server gửi rõ ràng `null` → coi là không giới hạn (`null`).
  static TranGoi tuJson(Object? json) {
    if (json is! Map) return macDinh;
    int? doc(String khoa, int? macDinhO) {
      if (!json.containsKey(khoa)) return macDinhO;
      final v = json[khoa];
      if (v == null) return null; // Server trả null = không giới hạn
      return v is num && v > 0 ? v.toInt() : macDinhO;
    }

    return TranGoi(
      vi: doc('wallets', macDinh.vi),
      nganSach: doc('budgets', macDinh.nganSach),
      mucTieu: doc('goals', macDinh.mucTieu),
      hoaDon: doc('bills', macDinh.hoaDon),
      danhMucRieng: doc('custom_categories', macDinh.danhMucRieng),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TranGoi &&
      other.vi == vi &&
      other.nganSach == nganSach &&
      other.mucTieu == mucTieu &&
      other.hoaDon == hoaDon &&
      other.danhMucRieng == danhMucRieng;

  @override
  int get hashCode => Object.hash(vi, nganSach, mucTieu, hoaDon, danhMucRieng);

  @override
  String toString() =>
      'TranGoi(vi: $vi, nganSach: $nganSach, mucTieu: $mucTieu, hoaDon: $hoaDon, danhMucRieng: $danhMucRieng)';
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
/// Khi [tran] là null (không giới hạn) → luôn [Duoc].
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
  if (tran == null) return const Duoc();
  return dangCo >= tran
      ? Vuot(loai: loai, tran: tran, dangCo: dangCo)
      : const Duoc();
}

/// Mã trong query `?tran=` của `/premium`.
String maTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'vi',
      LoaiTran.nganSach => 'ngan_sach',
      LoaiTran.mucTieu => 'muc_tieu',
      LoaiTran.hoaDon => 'hoa_don',
      LoaiTran.danhMucRieng => 'danh_muc_rieng',
    };

LoaiTran? loaiTranTuMa(String? ma) => switch (ma) {
      'vi' => LoaiTran.vi,
      'ngan_sach' => LoaiTran.nganSach,
      'muc_tieu' => LoaiTran.mucTieu,
      'hoa_don' => LoaiTran.hoaDon,
      'danh_muc_rieng' => LoaiTran.danhMucRieng,
      _ => null,
    };

String tenTran(LoaiTran loai) => switch (loai) {
      LoaiTran.vi => 'ví',
      LoaiTran.nganSach => 'ngân sách',
      LoaiTran.mucTieu => 'mục tiêu tiết kiệm',
      LoaiTran.hoaDon => 'hóa đơn định kỳ',
      LoaiTran.danhMucRieng => 'danh mục riêng',
    };

/// Dòng phụ của thẻ Gói (tab Cá nhân): mọi trần có số, `null` (không giới hạn) bị bỏ — *"3 ví · 3 ngân sách · 3 mục
/// tiêu · 3 hoá đơn · 5 danh mục riêng"*. Tên ngắn hơn [tenTran] vì thẻ chật; trong mỗi mục là dấu cách KHÔNG
/// ngắt nên chữ chỉ xuống dòng ở dấu `·` (nghiệm thu OnePlus: *"3 mục / tiêu"*).
String tomTatTran(TranGoi tran) => [
      for (final l in LoaiTran.values)
        if (tran.cua(l) case final n?)
          '$n ${switch (l) {
            LoaiTran.vi => 'ví',
            LoaiTran.nganSach => 'ngân sách',
            LoaiTran.mucTieu => 'mục tiêu',
            LoaiTran.hoaDon => 'hoá đơn',
            LoaiTran.danhMucRieng => 'danh mục riêng',
          }}'.replaceAll(' ', '\u00A0'),
    ].join(' · ');
