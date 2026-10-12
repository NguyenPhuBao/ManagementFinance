/// C4 — micro của ô Nhập nhanh (spec 2026-10-12 §2.1–2.2). Quyền → chọn lối (`chonLoiNghe`) → nghe (Android) hoặc ghi âm
/// rồi chép lời (Gemma) → MỘT câu ([NgheGiongNoiState.cauXong]); trang đặt câu vào ô và Điền qua `ThemGiaoDichCubit`.
/// Không ghi gì (bất biến ④). Cubit RIÊNG để `ThemGiaoDichCubit` không phình (quét 23).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/nguon_giong_noi.dart';
import '../../domain/chon_loi_nghe.dart';
import '../../domain/do_im_lang.dart';
import 'nghe_giong_noi_state.dart';

/// Hạn chót cho một lượt nghe Android: gói `speech_to_text` không callback nào nếu bộ nhận dạng bận mà không bắt đầu.
final Duration kHanNgheAndroid = kNgheToiDa + const Duration(seconds: 5);

class NgheGiongNoiCubit extends Cubit<NgheGiongNoiState> {
  NgheGiongNoiCubit({required NguonGiongNoi nguon})
      : _nguon = nguon,
        super(const NgheGiongNoiState());

  final NguonGiongNoi _nguon;

  /// Lượt trước Android mất mạng / thiếu gói tiếng Việt → lượt này đi Gemma (xem [kThuGemmaLuotSau]).
  bool _uuTienGemma = false;
  int _luot = 0;
  String? _tep;
  BoDoIm? _boDoIm;
  int _soMau = 0;
  Timer? _han;

  Future<void>? _dong;

  void _phat(NgheGiongNoiState s) {
    if (!isClosed) emit(s);
  }

  /// Nút micro: chờ → bắt đầu; đang nghe / ghi → dừng (chữ cuối / bản ghi đi tiếp); đang chép → bỏ qua.
  Future<void> bam() async {
    switch (state.trangThai) {
      case TrangThaiNghe.cho:
        await _batDau();
      case TrangThaiNghe.dangNghe:
        await _nguon.android.dung();
      case TrangThaiNghe.dangGhi:
        await _dungGhi();
      case TrangThaiNghe.dangChep:
        return;
    }
  }

  /// `/add?noi=1` — bắt đầu nghe ngay khi mở form.
  Future<void> batDau() => state.trangThai == TrangThaiNghe.cho ? _batDau() : Future.value();

  Future<void> _batDau() async {
    final luot = ++_luot;
    // `record.hasPermission` XIN quyền nếu chưa — một lần xin cho cả hai lối.
    if (!await _nguon.ghiAm.coQuyen()) {
      final chan = await _nguon.micro.biChan();
      if (luot == _luot) _bao(chan ? ThongBaoNghe.biChanQuyen : ThongBaoNghe.tuChoiQuyen);
      return;
    }
    final coMang = await _nguon.coMang();
    final gemmaOk = await (_nguon.gemma?.sanSangChua() ?? Future.value(false));
    final androidOk = await _nguon.android.khoiTao();
    if (isClosed || luot != _luot) return;
    final loi = chonLoiNghe(
      coMang: coMang,
      androidSanSang: androidOk,
      gemmaSanSang: gemmaOk,
      uuTienGemma: _uuTienGemma,
    );
    _uuTienGemma = false;
    switch (loi) {
      case null:
        _bao(ThongBaoNghe.khongCoLoi);
      case LoiNghe.gemma:
        await _ghiAm(luot);
      case LoiNghe.android || LoiNghe.androidTrenMay:
        await _ngheAndroid(luot, trenMay: loi == LoiNghe.androidTrenMay, gemmaOk: gemmaOk);
    }
  }

  void _huyHan() {
    _han?.cancel();
    _han = null;
  }

  Future<void> _ngheAndroid(int luot, {required bool trenMay, required bool gemmaOk}) async {
    bool conLuot() => !isClosed && luot == _luot && state.trangThai == TrangThaiNghe.dangNghe;
    _phat(state.copyWith(trangThai: TrangThaiNghe.dangNghe, chuTam: ''));
    _huyHan();
    _han = Timer(kHanNgheAndroid, () {
      if (!conLuot()) return;
      debugPrint('[GiongNoi] hết hạn chót lượt nghe Android');
      _luot++;
      unawaited(_nguon.android.huy());
      _phat(state.copyWith(trangThai: TrangThaiNghe.cho, chuTam: ''));
      _bao(ThongBaoNghe.loiChung);
    });
    try {
      await _nguon.android.nghe(
        trenMay: trenMay,
        onChu: (chu, xong) {
          if (!conLuot()) return;
          if (xong) {
            _huyHan();
            final cau = chu.trim().isNotEmpty ? chu : state.chuTam;
            _ketThucNghe(cau);
          } else {
            _phat(state.copyWith(chuTam: chu));
          }
        },
        onLoi: (ma) {
          if (!conLuot()) return;
          _huyHan();
          final t = thongBaoChoLoiAndroid(ma, gemmaSanSang: gemmaOk);
          if (kThuGemmaLuotSau.contains(t)) _uuTienGemma = true;
          _phat(state.copyWith(trangThai: TrangThaiNghe.cho, chuTam: ''));
          _bao(t);
        },
        onDung: () {
          if (!conLuot()) return;
          _huyHan();
          _ketThucNghe(state.chuTam);
        },
      );
    } catch (e) {
      debugPrint('[GiongNoi] nghe Android lỗi: $e');
      if (!conLuot()) return;
      _huyHan();
      _phat(state.copyWith(trangThai: TrangThaiNghe.cho, chuTam: ''));
      _bao(ThongBaoNghe.loiChung);
    }
  }

  /// Một đường kết thúc lượt Android: có chữ thì thành câu, không thì "không nghe rõ".
  void _ketThucNghe(String chu) {
    final cau = chu.trim();
    if (cau.isNotEmpty) return _xong(cau);
    _phat(state.copyWith(trangThai: TrangThaiNghe.cho, chuTam: ''));
    _bao(ThongBaoNghe.khongNgheRo);
  }

  Future<void> _ghiAm(int luot) async {
    final tep = await _nguon.tepTam();
    if (isClosed || luot != _luot) return;
    _tep = tep;
    _soMau = 0;
    _boDoIm = BoDoIm();
    _phat(state.copyWith(trangThai: TrangThaiNghe.dangGhi, giay: 0, chuTam: ''));
    try {
      await _nguon.ghiAm.batDau(tep, onBienDo: (db) {
        if (isClosed || luot != _luot || state.trangThai != TrangThaiNghe.dangGhi) return;
        _soMau++;
        final luc = kNhipBienDo * _soMau;
        if (luc.inSeconds != state.giay) _phat(state.copyWith(giay: luc.inSeconds));
        if (_boDoIm!.them(db, luc)) unawaited(_dungGhi());
      });
    } catch (e) {
      debugPrint('[GiongNoi] ghi âm lỗi: $e');
      if (isClosed || luot != _luot) {
        // Lượt cũ (đã huỷ / Cubit đóng): chỉ dọn tệp của chính nó, không đụng trạng thái lượt hiện tại.
        await _nguon.xoaTep(tep);
        return;
      }
      await _don();
      _phat(state.copyWith(trangThai: TrangThaiNghe.cho));
      _bao(ThongBaoNghe.loiChung);
    }
  }

  Future<void> _dungGhi() async {
    if (state.trangThai != TrangThaiNghe.dangGhi) return;
    final luot = _luot;
    final tepLuotNay = _tep; // chỉ xoá tệp CỦA LƯỢT NÀY — lượt mới có thể đã gán `_tep` khác khi ta về muộn
    _phat(state.copyWith(trangThai: TrangThaiNghe.dangChep));
    String? p = tepLuotNay;
    try {
      p = await _nguon.ghiAm.dung() ?? tepLuotNay;
    } catch (e) {
      debugPrint('[GiongNoi] dừng ghi âm lỗi: $e');
    }
    final gemma = _nguon.gemma;
    String? cau;
    if (p != null && gemma != null) {
      try {
        // Hàng đợi lượt chép nằm ở `ChepLoiBangGemma` (mô hình là singleton, mọi Cubit dùng chung).
        cau = await gemma.chep(await _nguon.docTep(p));
      } catch (e) {
        debugPrint('[GiongNoi] chép lời lỗi: $e');
      }
    }
    if (p != null) await _nguon.xoaTep(p);
    if (_tep == tepLuotNay) _tep = null;
    if (isClosed || luot != _luot) return;
    if (cau == null || cau.isEmpty) {
      _phat(state.copyWith(trangThai: TrangThaiNghe.cho));
      _bao(ThongBaoNghe.khongNgheRo);
      return;
    }
    _xong(cau);
  }

  void _xong(String cau) => _phat(state.copyWith(
        trangThai: TrangThaiNghe.cho,
        chuTam: '',
        cauXong: cau,
        soLanXong: state.soLanXong + 1,
      ));

  void _bao(ThongBaoNghe t) => _phat(state.copyWith(thongBao: t, soLanThongBao: state.soLanThongBao + 1));

  /// Xoá tệp ghi âm của lượt hiện tại (nếu có). Không lưu âm thanh (spec §2.4).
  Future<void> _don() async {
    final t = _tep;
    _tep = null;
    if (t != null) await _nguon.xoaTep(t);
  }

  /// Nút Huỷ / rời màn: dừng lối đang chạy, xoá tệp.
  Future<void> huy() async {
    _luot++;
    _huyHan();
    switch (state.trangThai) {
      case TrangThaiNghe.dangNghe:
        await _nguon.android.huy();
      case TrangThaiNghe.dangGhi:
        await _nguon.ghiAm.huy();
      case TrangThaiNghe.dangChep:
        await _nguon.gemma?.huy();
      case TrangThaiNghe.cho:
        break;
    }
    await _don();
    _phat(state.copyWith(trangThai: TrangThaiNghe.cho, chuTam: ''));
  }

  @override
  Future<void> close() => _dong ??= () async {
        try {
          await huy();
        } finally {
          await super.close();
        }
      }();
}
