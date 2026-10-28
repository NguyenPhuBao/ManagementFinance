import '../../domain/hang_goi.dart';

/// Trần theo loại (spec Premium 2026-10-06 mục 5.2) — model của `limits` (gói hiệu lực) và của cột Premium (B1, spec
/// 2026-10-27 mục 6) ở `/payment/subscription-info`, và của kho. `null` = không giới hạn. Luật *"được tạo thêm không"* ở
/// `domain/tran_goi.dart` (`conTaoDuoc`, đọc trần qua `tranHieuLuc`).
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

  /// Mặc định của Basic (ô server không gửi): ví / ngân sách / mục tiêu 3; hoá đơn và danh mục riêng không giới hạn
  /// (spec phân quyền 2026-10-08 mục 2 #1 — server cũ không trả hai khoá ấy thì giữ chốt 06/10 *"Mở"*).
  static const macDinh = TranGoi(vi: 3, nganSach: 3, mucTieu: 3);

  /// Mọi ô `null` — không giới hạn. Mặc định của ô trần mà cột PREMIUM không gửi (B1, spec 2026-10-27 mục 6), và trần
  /// hiệu lực của Premium khi bảng đã lưu không dùng được (`tranHieuLuc`).
  static const khongGioiHan = TranGoi();

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

  /// `limits` của server. Ô thiếu / không phải số → [khiThieu] cho ĐÚNG ô ấy (mặc định [macDinh] — trần Basic; cột
  /// Premium truyền [khongGioiHan]). `null` → không giới hạn (Admin-web tick *∞* hoặc xoá trắng ô số). Số ≤ 0 → **0 =
  /// không tạo thêm** (người dùng chốt 2026-10-27): Admin-web bỏ tick *∞* là ô về 0 ngay và tự kẹp số âm về 0 — bản
  /// cũ đọc 0 là rác, nên ví / ngân sách / mục tiêu về 3 còn hoá đơn / danh mục riêng thành KHÔNG giới hạn, ngược hẳn
  /// ý admin.
  static TranGoi tuJson(Object? json, {TranGoi khiThieu = macDinh}) {
    if (json is! Map) return khiThieu;
    int? doc(String khoa, int? macDinhO) {
      if (!json.containsKey(khoa)) return macDinhO;
      final v = json[khoa];
      if (v == null) return null; // Server trả null = không giới hạn
      if (v is! num) return macDinhO;
      return v > 0 ? v.toInt() : 0;
    }

    return TranGoi(
      vi: doc('wallets', khiThieu.vi),
      nganSach: doc('budgets', khiThieu.nganSach),
      mucTieu: doc('goals', khiThieu.mucTieu),
      hoaDon: doc('bills', khiThieu.hoaDon),
      danhMucRieng: doc('custom_categories', khiThieu.danhMucRieng),
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
