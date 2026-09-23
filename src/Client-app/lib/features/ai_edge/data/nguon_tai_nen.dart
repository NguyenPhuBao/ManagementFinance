// lib/features/ai_edge/data/nguon_tai_nen.dart
/// Một lượt tải tệp **sống lâu hơn tiến trình app**.
///
/// ⚠️ Vì sao cần một giao diện riêng thay vì một hàm `taiTep` như trước: hàm
/// ấy là một `Future` sống *trong* tiến trình này. Khi người dùng thoát app,
/// tiến trình chết, và lúc app sống lại thì **không ai gọi hàm ấy nữa** — phải
/// hỏi hệ thống *"còn lượt nào đang chạy không"*. [NguonTaiNen.luotDangSong] là
/// câu hỏi đó, và là cả lý do lớp này tồn tại.
///
/// Giao diện **thuần**, đúng khuôn `SlmRuntime`: bản thật bọc thư viện native
/// (`background_downloader`), bản giả cho test — nhờ vậy tầng trên vẫn chạy
/// được trong `flutter test` trên máy phát triển x86_64.
library;

import 'dart:async';

enum TrangThaiLuot { dangCho, dangChay, tamDung, xong, hong, huy }

typedef TinLuot = ({
  TrangThaiLuot trangThai,
  double phanTram,
  String? loi,
});

abstract class NguonTaiNen {
  /// Bắt đầu một lượt tải.
  ///
  /// [chiWifi] `false` nghĩa là người dùng **đã đồng ý** dùng dữ liệu di động.
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  });

  /// Lượt đang sống, kể cả lượt do **lần chạy trước** của app tạo ra.
  ///
  /// `null` = không có lượt nào. ⚠️ Khác hẳn *"có lượt ở 0 %"*: gộp hai thứ ấy
  /// là màn hình hiện một thanh tiến độ đứng yên cho một lượt không tồn tại.
  Future<TinLuot?> luotDangSong();

  Future<void> tamDung();

  Future<void> tiepTuc();

  Future<void> huy();

  Stream<TinLuot> get tin;
}

/// Bản giả cho test — **không** chạm mạng, không chạm nền tảng.
class NguonTaiNenGia implements NguonTaiNen {
  final _phat = StreamController<TinLuot>.broadcast();
  TinLuot? _luot;

  /// Giá trị `chiWifi` của lần [batDau] gần nhất. Test hộp thoại 4G đọc nó.
  bool? chiWifiLanCuoi;

  @override
  Stream<TinLuot> get tin => _phat.stream;

  @override
  Future<void> batDau({
    required String url,
    required String tenTep,
    required bool chiWifi,
  }) async {
    chiWifiLanCuoi = chiWifi;
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: 0, loi: null));
  }

  @override
  Future<TinLuot?> luotDangSong() async => _luot;

  @override
  Future<void> tamDung() async {
    final l = _luot;
    if (l == null) return;
    _dat((trangThai: TrangThaiLuot.tamDung, phanTram: l.phanTram, loi: null));
  }

  @override
  Future<void> tiepTuc() async {
    final l = _luot;
    if (l == null) return;
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: l.phanTram, loi: null));
  }

  @override
  Future<void> huy() async {
    _luot = null;
    _phat.add((trangThai: TrangThaiLuot.huy, phanTram: 0, loi: null));
  }

  // ── Chỉ dành cho test: đẩy lượt giả đi tới ───────────────────────────────

  void tienToi(double phanTram) {
    _dat((trangThai: TrangThaiLuot.dangChay, phanTram: phanTram, loi: null));
  }

  void choMang() {
    _dat((
      trangThai: TrangThaiLuot.dangCho,
      phanTram: _luot?.phanTram ?? 0,
      loi: null,
    ));
  }

  void xong() {
    _dat((trangThai: TrangThaiLuot.xong, phanTram: 1, loi: null));
  }

  void hong(String loi) {
    _dat((trangThai: TrangThaiLuot.hong, phanTram: 0, loi: loi));
  }

  /// Dựng sẵn một lượt "của lần chạy trước" mà KHÔNG phát tin nào — đúng cảnh
  /// app vừa khởi động lại: lượt có thật, nhưng stream chưa từng phát gì.
  void dungSanLuotCu(TinLuot l) => _luot = l;

  void _dat(TinLuot l) {
    _luot = l;
    _phat.add(l);
  }

  Future<void> dong() => _phat.close();
}
