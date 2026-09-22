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

class MoHinhTaiVe {
  final Future<Directory> Function() thuMuc;
  final Future<void> Function(
    String url,
    File dich,
    void Function(double phanTram) bao,
  ) taiTep;

  final _phat = StreamController<TienDoTai>.broadcast();
  Future<void>? _dangChay;
  bool _huy = false;

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
    _huy = false;
    final dich = File(await duongTep());
    _phat.add((trangThai: TrangThaiMoHinh.dangTai, phanTram: 0, loi: null));
    try {
      await taiTep(kUrlMoHinh, dich, (p) {
        if (_huy) return;
        _phat.add(
          (trangThai: TrangThaiMoHinh.dangTai, phanTram: p, loi: null),
        );
      });
      if (_huy) throw const _HuyTai();
      _phat.add((trangThai: TrangThaiMoHinh.daTai, phanTram: 1, loi: null));
    } catch (e) {
      // ⚠️ Xoá tệp dở NGAY. Một tệp cụt trông y hệt tệp đủ với `existsSync()`,
      // và lần mở app sau sẽ nạp nó rồi ném "Model may be invalid".
      if (dich.existsSync()) {
        try {
          dich.deleteSync();
        } catch (_) {}
      }
      _phat.add(
        (trangThai: TrangThaiMoHinh.loi, phanTram: 0, loi: e.toString()),
      );
      debugPrint('[SLM] tải mô hình hỏng: $e');
      rethrow;
    }
  }

  void huy() => _huy = true;

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
