// lib/features/ai_edge/data/bo_nap_mo_hinh.dart
/// Điều phối NẠP mô hình cho `SlmRuntimeThat` (C4 vòng sửa 1) — Dart thuần, không import `flutter_gemma` nên test được
/// bằng bản giả. Ba việc:
/// 1. TUẦN TỰ HOÁ: các lượt cần mô hình chạy lần lượt; lượt sau tính lại [quyetDinhNap] trên trạng thái MỚI của lượt
///    trước (không nạp hai lần song song, không đóng lần hai — A5: OnePlus GPU sập native ở lần ĐÓNG thứ hai).
/// 2. HUỶ TRONG PHA NẠP: [huy] tăng một bộ đếm; lượt ghi [moc] trước khi nạp, nạp xong mà bộ đếm đã đổi thì ném
///    [LuotNapBiHuy] để không tạo chat. Mô hình vừa nạp vẫn được GIỮ (đóng là phá luật ≤ 1 lần).
/// 3. Giữ cờ ảnh / âm của bản đang nạp.
/// 4. BÁO native tiến trình có đang giữ một bản mô hình không ([baoGiu], G100 đường gỡ task): `MainActivity` giết tiến
///    trình khi activity bị huỷ thật mà cờ bật — engine dựng lại trong tiến trình còn sống sẽ nạp THÊM một bản.
library;

import '../domain/nap_da_phuong_thuc.dart';

/// Lượt bị huỷ lúc đang chờ / đang nạp mô hình — lớp bọc ([ChepLoiBangGemma]…) coi như không có kết quả.
class LuotNapBiHuy implements Exception {
  const LuotNapBiHuy();
  @override
  String toString() => 'LuotNapBiHuy: lượt bị huỷ trong lúc nạp mô hình';
}

class BoNapMoHinh {
  BoNapMoHinh({required this.coMoHinh, required this.dong, required this.nap, this.baoGiu});

  /// Đang có mô hình trong bộ nhớ không (nơi khác có thể đã đóng nó).
  final bool Function() coMoHinh;
  final Future<void> Function() dong;
  final Future<void> Function(String duongTep, {required bool anh, required bool am}) nap;

  /// `true` sau khi [nap] xong, `false` sau khi [dong] xong; `null` = không báo (test). ⚠️ Chỉ báo `true` khi nạp đã
  /// XONG: giết tiến trình giữa pha nạp là để dấu canary GPU sót lại, và lần mở sau đánh dấu GPU hỏng vĩnh viễn.
  final Future<void> Function(bool giu)? baoGiu;

  bool coAnh = false;
  bool coAm = false;
  int _huy = 0;
  Future<void> _hangDoi = Future<void>.value();

  /// Giá trị bộ đếm huỷ — ghi TRƯỚC khi gọi [can].
  int get moc => _huy;

  /// Người dùng huỷ: mọi lượt đã ghi [moc] cũ sẽ ném [LuotNapBiHuy] khi nạp xong.
  void huy() => _huy++;

  /// Bảo đảm mô hình đúng loại [can]. [moc] khác `null` và bộ đếm đã đổi → ném [LuotNapBiHuy].
  Future<void> can(CanMoHinh can, String duongTep, {int? moc}) {
    final luot = _hangDoi.then((_) async {
      if (moc != null && moc != _huy) throw const LuotNapBiHuy();
      final q = quyetDinhNap(coMoHinh: coMoHinh(), coAnh: coAnh, coAm: coAm, can: can);
      if (q.dong) {
        await dong();
        coAnh = false;
        coAm = false;
        await baoGiu?.call(false);
      }
      if (q.nap) {
        await nap(duongTep, anh: q.anh, am: q.am);
        coAnh = q.anh;
        coAm = q.am;
        await baoGiu?.call(true);
      }
      if (moc != null && moc != _huy) throw const LuotNapBiHuy();
    });
    _hangDoi = luot.then<void>((_) {}, onError: (_) {});
    return luot;
  }
}
