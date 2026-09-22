// lib/features/ai_edge/data/mo_hinh_tai_ve.dart
/// Trạng thái và vòng đời tệp mô hình trên máy (spec mục 4.2; tải nền + resume
/// theo spec `2026-09-22-tai-mo-hinh-nen-resume-design.md`).
///
/// Mô hình **không** đóng vào APK: 2,41 GB, và người không dùng AI thì không
/// nên trả dung lượng ấy. Tải chỉ khi người dùng bấm ở màn Cài đặt AI.
///
/// Lượt tải là **một đối tượng có danh tính do hệ thống giữ** ([NguonTaiNen]),
/// không phải một `Future` sống trong tiến trình này: người dùng thoát app thì
/// lượt vẫn chạy, và lúc app mở lại thì [khoiPhuc] hỏi hệ thống *"còn lượt
/// nào không"*. Bản thật ở `tai_nen_background_downloader.dart`; test dùng
/// `NguonTaiNenGia`.
library;

import 'dart:async';
import 'dart:io';

import 'nguon_tai_nen.dart';

enum TrangThaiMoHinh { chuaTai, dangTai, tamDung, choMang, daTai, loi }

typedef TienDoTai = ({
  TrangThaiMoHinh trangThai,
  double phanTram,
  String? loi,
});

/// Gemma 4 E2B, bản `.litertlm` **chuẩn**.
///
/// ⚠️ **Không** đổi sang `gemma-4-E2B-it-gpu.litertlm`: nhẹ hơn 0,6 GB nhưng
/// **không nạp được** trên engine FFI Android dù tệp nguyên vẹn từng byte, và
/// lỗi nó ném (*"Model may be invalid"*) dẫn người đọc đi kiểm tra tải hỏng —
/// P1 mục 8.2 `docs/AI_EDGE_FEATURE.md`.
const String kUrlMoHinh = 'https://huggingface.co/litert-community/'
    'gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

const String kTenTep = 'gemma-4-E2B-it.litertlm';

/// Cỡ tệp thật, đo 2026-09-20. Dùng để hiện dung lượng trước khi tải **và**
/// để [MoHinhTaiVe.daCo] phân biệt tệp đủ với tệp dở.
const int kCoTepByte = 2588147712;

class MoHinhTaiVe {
  final Future<Directory> Function() thuMuc;
  final NguonTaiNen nguon;

  /// Cỡ tệp coi là **đủ**. Mặc định [kCoTepByte]; chỉ test tiêm số khác, vì
  /// không ai dựng nổi tệp 2,4 GB trong `flutter test` để đóng vai "đã có".
  final int coTepByte;

  final _phat = StreamController<TienDoTai>.broadcast();
  StreamSubscription<TinLuot>? _nghe;

  MoHinhTaiVe({
    required this.thuMuc,
    required this.nguon,
    this.coTepByte = kCoTepByte,
  }) {
    _nghe = nguon.tin.listen(_dich);
  }

  Stream<TienDoTai> get tienDo => _phat.stream;

  Future<String> duongTep() async => '${(await thuMuc()).path}/$kTenTep';

  /// Tệp mô hình đã **đủ** trên máy chưa.
  ///
  /// ⚠️ Kiểm **kích thước**, không chỉ kiểm tồn tại. Từ khi có resume, một tệp
  /// tải dở được **giữ lại** để lượt sau tiếp tục — mà `existsSync()` đúng với
  /// cả tệp 650 MB lẫn tệp đủ 2,41 GB. Đọc nhầm thì engine ném *"Model may be
  /// invalid"* ở một chỗ chẳng liên quan gì tới việc tải, và người sửa lỗi đi
  /// tìm nguyên nhân trong `SlmRuntime`.
  ///
  /// Không dùng checksum: phải đọc trọn 2,41 GB mỗi lần mở màn Cài đặt AI.
  Future<bool> daCo() async {
    final f = File(await duongTep());
    if (!f.existsSync()) return false;
    return f.lengthSync() == coTepByte;
  }

  /// Bắt đầu tải. [chiWifi] `false` = người dùng đã đồng ý dùng dữ liệu di động.
  ///
  /// Gọi hai lần chồng nhau thì bản thật **từ chối lượt thứ hai** vì cùng
  /// `taskId` — hai lượt ghi vào cùng một tệp là hỏng tệp.
  Future<void> tai({bool chiWifi = true}) async {
    await nguon.batDau(url: kUrlMoHinh, tenTep: kTenTep, chiWifi: chiWifi);
  }

  /// Hỏi lại lượt tải của **lần chạy trước** và phát lại trạng thái của nó.
  ///
  /// ⚠️ Màn Cài đặt AI phải gọi hàm này khi mở, không chỉ nghe stream: lượt
  /// tải có thể đã chạy từ lần mở app trước, mà stream chỉ phát những gì xảy
  /// ra **từ lúc nghe trở đi**. Cùng họ lỗi G48.
  Future<void> khoiPhuc() async {
    final l = await nguon.luotDangSong();
    if (l == null) return;
    _dich(l);
  }

  Future<void> tamDung() => nguon.tamDung();

  /// Tiếp tục lượt đang sống (tạm dừng, hoặc **hỏng** — bản thật nối lại từ
  /// chỗ đứt nhờ `Range`). Không còn lượt nào (bản ghi đã bị dọn) thì bắt đầu
  /// lượt mới — nút "Thử lại" ở màn lỗi đi qua đây, để người dùng không bao
  /// giờ gặp một nút bấm mà không có gì xảy ra.
  Future<void> tiepTuc() async {
    if (await nguon.luotDangSong() == null) return tai();
    await nguon.tiepTuc();
  }

  /// Dừng HẲN: cắt lượt tải và xoá tệp dở.
  ///
  /// ⚠️ Tệp dở chỉ bị xoá ở đây và ở [xoa] — **không** xoá khi lượt hỏng
  /// giữa chừng nữa: nó là thứ lượt sau sẽ tiếp tục. Phép chặn "tệp cụt trông
  /// như tệp đủ" nay nằm ở [daCo], chỗ nó thuộc về.
  Future<void> huy() async {
    await nguon.huy();
    final f = File(await duongTep());
    if (f.existsSync()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> xoa() async {
    final f = File(await duongTep());
    if (f.existsSync()) f.deleteSync();
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> dong() async {
    await _nghe?.cancel();
    await _phat.close();
  }

  void _dich(TinLuot l) {
    final tt = switch (l.trangThai) {
      // ⚠️ `dangCho` → `choMang`, KHÔNG phải `dangTai`: `requiresWiFi` làm lượt
      // đứng im vô thời hạn mà gói không báo lỗi gì; gộp vào "đang tải" là
      // hiện 0 % đứng yên mãi mãi.
      TrangThaiLuot.dangCho => TrangThaiMoHinh.choMang,
      TrangThaiLuot.dangChay => TrangThaiMoHinh.dangTai,
      TrangThaiLuot.tamDung => TrangThaiMoHinh.tamDung,
      TrangThaiLuot.xong => TrangThaiMoHinh.daTai,
      TrangThaiLuot.hong => TrangThaiMoHinh.loi,
      TrangThaiLuot.huy => TrangThaiMoHinh.chuaTai,
    };
    final loi = l.loi;
    _phat.add((
      trangThai: tt,
      phanTram: l.phanTram,
      loi: loi == null ? null : cauLoiTai(loi),
    ));
  }
}

/// Câu lỗi NGẮN cho người dùng đọc, từ một exception bất kỳ của đường tải.
///
/// ⚠️ Vì sao cần hàm này thay vì `e.toString()`: URL tải là một đường ký của
/// CDN HuggingFace, dài **hàng nghìn ký tự** (chữ ký, policy base64, hạn dùng)
/// và thông báo lỗi của thư viện tải nhét trọn nó vào. Nghiệm thu máy thật
/// 2026-09-22 (P3 Task 9) dựng đúng trạng thái ấy — kết nối đứt giữa chừng —
/// và màn Cài đặt AI hiện **một bức tường base64** phủ kín màn hình, trong đó
/// câu duy nhất có ích (*"Connection closed while receiving data"*) nằm lọt ở
/// dòng thứ hai. Người dùng không rút ra được gì, còn người sửa lỗi thì vẫn
/// phải xem logcat — nên màn hình chẳng phục vụ ai.
///
/// Chi tiết đầy đủ vẫn đi vào `debugPrint`, chỗ nó thuộc về.
///
/// Hàm thuần, không phụ thuộc thư viện tải: nhận diện theo **chuỗi** để không
/// phải import một kiểu lỗi nào — tầng này đã cố ý không biết bên tải là ai.
String cauLoiTai(Object loi) {
  final thap = loi.toString().toLowerCase();

  // Hết dung lượng đứng TRƯỚC nhánh mạng: tệp 2,41 GB làm đầy máy là ca thật,
  // và bảo người dùng "kiểm tra mạng" khi máy hết chỗ là chỉ sai hướng hẳn.
  if (thap.contains('no space left') ||
      thap.contains('enospc') ||
      thap.contains('not enough space')) {
    return 'Máy không đủ dung lượng trống. Mô hình cần 2,41 GB.';
  }
  if (thap.contains('connection closed') ||
      thap.contains('connection reset') ||
      thap.contains('connection refused') ||
      thap.contains('socketexception') ||
      thap.contains('httpexception') ||
      thap.contains('failed host lookup') ||
      thap.contains('timeout') ||
      thap.contains('network is unreachable')) {
    return 'Mất kết nối giữa chừng. Kiểm tra mạng rồi tải lại.';
  }

  // Lỗi lạ: giữ lại phần đầu, nhưng cắt sạch từ chỗ URL xuất hiện. Một dòng
  // ngắn còn đọc được; nguyên `toString()` thì không.
  var s = loi.toString().replaceAll('\n', ' ').trim();
  for (final moc in ['uri =', 'http://', 'https://']) {
    final i = s.indexOf(moc);
    if (i > 0) s = s.substring(0, i).trim();
  }
  s = s.replaceAll(RegExp(r'[,:\s]+$'), '');
  if (s.length > 120) s = '${s.substring(0, 117)}…';
  return s.isEmpty ? 'Tải hỏng. Thử lại sau.' : s;
}
