// lib/features/ai_edge/data/mo_hinh_tai_ve.dart
/// Trạng thái và vòng đời tệp mô hình trên máy (spec mục 4.2).
///
/// Mô hình **không** đóng vào APK: 2,41 GB, và người không dùng AI thì không
/// nên trả dung lượng ấy. Tải chỉ khi người dùng bấm ở màn Cài đặt AI.
///
/// Phép tải tiêm qua [taiTep] để test không chạm mạng — bản thật ở
/// `injection_container.dart` dùng `Dio` đã có sẵn của dự án.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum TrangThaiMoHinh { chuaTai, dangTai, daTai, loi }

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

/// Cỡ tệp thật, đo 2026-09-20. Dùng để hiện dung lượng trước khi tải.
const int kCoTepByte = 2588147712;

/// Tín hiệu huỷ của **một lượt** tải.
///
/// ⚠️ Vì sao là một đối tượng chứ không phải một cờ `bool`: một cờ chỉ trả lời
/// được câu *"đã huỷ chưa"* khi có ai đó hỏi, mà `Dio.download` thì không hỏi —
/// nó cần được **báo** để cắt kết nối. Bản đầu dùng cờ, và hậu quả là `huy()`
/// chỉ thôi vẽ tiến độ trong khi máy **vẫn tải hết 2,41 GB ở nền**: người dùng
/// bấm Huỷ trên dữ liệu di động vẫn mất chừng ấy dung lượng, im lặng.
///
/// [khiHuy] là chỗ bên tải gắn phép cắt của mình vào (`CancelToken.cancel()`
/// với Dio); [daHuy] cho bên tải nào chỉ hỏi được một lần lúc vào.
///
/// **Một đối tượng cho mỗi lượt tải** — xem `_tai()`. Dùng chung cho cả đời
/// `MoHinhTaiVe` thì lượt sau bị huỷ ngay khi vừa bắt đầu, và người dùng thấy
/// nút Tải bấm mãi không lên gì.
class DauHuy {
  final _xong = Completer<void>();

  bool get daHuy => _xong.isCompleted;

  Future<void> get khiHuy => _xong.future;

  void huy() {
    if (!_xong.isCompleted) _xong.complete();
  }
}

class MoHinhTaiVe {
  final Future<Directory> Function() thuMuc;
  final Future<void> Function(
    String url,
    File dich,
    void Function(double phanTram) bao,
    DauHuy dauHuy,
  ) taiTep;

  final _phat = StreamController<TienDoTai>.broadcast();
  Future<void>? _dangChay;
  DauHuy? _dauHuy;

  MoHinhTaiVe({required this.thuMuc, required this.taiTep});

  Stream<TienDoTai> get tienDo => _phat.stream;

  Future<String> duongTep() async => '${(await thuMuc()).path}/$kTenTep';

  Future<bool> daCo() async => File(await duongTep()).existsSync();

  /// Tải mô hình. Gọi lần hai khi lượt đầu chưa xong thì **dùng chung** lượt
  /// đang chạy — hai lượt ghi vào cùng một tệp là hỏng tệp.
  Future<void> tai() {
    return _dangChay ??= _tai().whenComplete(() => _dangChay = null);
  }

  Future<void> _tai() async {
    // Tín hiệu MỚI cho mỗi lượt: xem chú thích đầu [DauHuy].
    final dauHuy = _dauHuy = DauHuy();
    final dich = File(await duongTep());
    _phat.add((trangThai: TrangThaiMoHinh.dangTai, phanTram: 0, loi: null));
    try {
      await taiTep(kUrlMoHinh, dich, (p) {
        if (dauHuy.daHuy) return;
        _phat.add(
          (trangThai: TrangThaiMoHinh.dangTai, phanTram: p, loi: null),
        );
      }, dauHuy);
      // Bên tải có thể **về bình thường** dù đã bị báo huỷ (bản giả trong test,
      // hoặc một thư viện nuốt lỗi huỷ). Chốt này giữ cho hai đường ra cùng
      // một kết cục.
      if (dauHuy.daHuy) throw const _HuyTai();
      _phat.add((trangThai: TrangThaiMoHinh.daTai, phanTram: 1, loi: null));
    } catch (e) {
      // ⚠️ Xoá tệp dở NGAY. Một tệp cụt trông y hệt tệp đủ với `existsSync()`,
      // và lần mở app sau sẽ nạp nó rồi ném "Model may be invalid".
      if (dich.existsSync()) {
        try {
          dich.deleteSync();
        } catch (_) {}
      }
      // ⚠️ Huỷ **không phải lỗi**: người dùng vừa chủ ý bấm nút. Dựng khối lỗi
      // đỏ cho một thao tác thành công là nói với họ rằng có gì đó hỏng — và
      // cũng không ném ra ngoài, vì không ai cần xử lý "việc đã làm xong".
      if (dauHuy.daHuy) {
        _phat.add(
          (trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null),
        );
        return;
      }
      _phat.add(
        (trangThai: TrangThaiMoHinh.loi, phanTram: 0, loi: e.toString()),
      );
      debugPrint('[SLM] tải mô hình hỏng: $e');
      rethrow;
    }
  }

  /// Cắt lượt tải đang chạy. Không có lượt nào thì không làm gì.
  void huy() => _dauHuy?.huy();

  Future<void> xoa() async {
    final f = File(await duongTep());
    if (f.existsSync()) f.deleteSync();
    _phat.add((trangThai: TrangThaiMoHinh.chuaTai, phanTram: 0, loi: null));
  }

  Future<void> dong() async => _phat.close();
}

class _HuyTai implements Exception {
  const _HuyTai();
  @override
  String toString() => 'Đã huỷ tải';
}
