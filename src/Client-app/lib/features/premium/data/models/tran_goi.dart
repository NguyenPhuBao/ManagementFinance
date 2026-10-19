import '../../domain/hang_goi.dart';

/// Trần của gói Basic theo loại (spec Premium 2026-10-06 mục 5.2) — model của `limits`
/// (`/payment/subscription-info`) và của kho. Luật *"được tạo thêm không"* ở `domain/tran_goi.dart` (`conTaoDuoc`).
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
