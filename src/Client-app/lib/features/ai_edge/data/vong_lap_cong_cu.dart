// ignore_for_file: avoid_print
/// Vòng lặp tool của màn Trợ lý AI (chặng 4b, spec mục 3.6; bước 2b, 2c).
///
/// Điều khiển một [PhienCongCu]: lượt nào mô hình gọi tool thì chạy tool, trả
/// JSON về phiên và TÍCH LUỸ kết quả vào [GoiSoTraCuu]; lượt không gọi tool là
/// câu trả lời. Chữ chỉ đi qua `gacTheoCau` khi CỔNG mở — `goi.choHienChuMoHinh`:
/// đã có lượt THÀNH CÔNG, không còn lời từ chối chưa gỡ, và không có lượt rỗng
/// theo bộ lọc. Cổng đóng thì chữ bị bỏ, chỉ ghi log (chốt L1: `kiemSo` mù với
/// câu bịa tên không có số; bước 2b: mô hình đọc lời từ chối thành "không có dữ
/// liệu" — bẫy 4.40; bước 2c: `tim_giao_dich` 0 khoản với bộ lọc lệch câu hỏi
/// không phải câu trả lời — bẫy 4.44).
///
/// Thang lùi khi mô hình ngừng gọi tool: L1 chưa gọi tool nào → [KhongTraCuu]
/// (màn rơi về bậc 1) · **L1b** mọi lời gọi bị từ chối → mẫu câu trung thực của
/// gói (KHÔNG rơi về bậc 1: sáu gói không có hàng giao dịch nào, và người dùng
/// đọc "không có số liệu" thành "không có giao dịch") · L2 tool đã chạy mà chưa
/// câu nào qua kiểm → `mauCau()` · **L2b** còn lời từ chối chưa gỡ → `mauCau()`
/// (dữ liệu + câu chưa tra được), hoặc chỉ câu chưa tra được nếu đã có câu hiện
/// · **L2c** có lượt `tim_giao_dich` rỗng theo bộ lọc (bước 2c, bẫy 4.44) →
/// `mauCau()` nêu bộ lọc, hoặc chỉ câu về lượt rỗng nếu đã có câu hiện; cả hai
/// lý do → `(L2b+L2c)`, câu nối theo thứ tự xảy ra (`goi.cauNoiThem`) · L3 vượt
/// trần lời gọi → `mauCau()` · L4 runtime ném → lỗi lan lên màn (câu "không
/// chạy được").
///
/// **Định tuyến** (dự án B, 2026-10-02): tool đích đến từ đường ghép luật → mô
/// hình nhỏ (`domain/dinh_tuyen.dart`). Có đích thì phiên chỉ khai một tool;
/// nhưng hai hành vi ÉP chạy tool đích chỉ áp khi nguồn là LUẬT — nguồn mô hình
/// là định tuyến MỀM, không gọi tool thì vẫn L1. Dòng log đầu của mỗi lượt hỏi
/// là `[SLM][tool] định tuyến: …`.
///
/// **Đường nhanh** (spec 2026-10-02, thi công 2026-10-04): đích là tool giao dịch
/// và luật đọc đủ tham số (`docDuThamSoGiaoDich`) → tool chạy TRƯỚC với `{}` (bộ
/// chỉnh trong tool điền tham số), Gemma chỉ viết câu qua `sinhDan` — không mở
/// phiên có tool. Tool từ chối → lời từ chối bị bỏ, đi tiếp đường trên như cũ.
///
/// Riêng `BacCongCuDaTat` (máy từng sập native ở phiên có tool — canary 1b,
/// `domain/canary_cong_cu.dart`) đi đường L1 chứ không L4: bậc 1 vẫn chạy được.
///
/// ⚠️ Log bằng `print`: `debugPrint` bị tiết lưu và nuốt dòng (vế ba bẫy 8.6
/// `AI_EDGE_FEATURE.md`), mà từng dòng ở đây là bằng chứng cổng C. Tiền lệ
/// `// ignore_for_file: avoid_print`: `lib/main.dart`.
///
/// Tệp này KHÔNG import `flutter_gemma` — test quét 16 canh.
library;

import 'dart:async';

import '../domain/canary_cong_cu.dart';
import '../domain/chinh_tham_so.dart';
import '../domain/cong_cu.dart';
import '../domain/dinh_tuyen.dart';
import '../domain/gac_cau.dart';
import '../domain/goi_so_tra_cuu.dart';
import '../domain/hang_so_lieu.dart';
import '../domain/ke_du_ten.dart';
import '../domain/ket_luan_so_sanh.dart';
import '../domain/kiem_cau_tra_loi.dart';
import '../domain/slm_prompt.dart';
import 'bo_cong_cu.dart';
import 'phien_cong_cu.dart';
import 'slm_runtime.dart';

Stream<SuKienGac> hoiBangCongCu(
  String cauHoi, {
  required SlmRuntime runtime,
  required BoCongCu boCongCu,
  required GoiSoTraCuu goi,
  required int idaccount,
  required DateTime now,
  /// `null` = lời theo phiên ([heThongCho] của tool đích, 2026-10-04).
  String? heThong,
  int tranGoi = kTranGoiCongCu,
  void Function(String) log = print,
  KetQuaDinhTuyen Function(String cauHoi) dinhTuyen = dinhTuyenCauHoi,
}) async* {
  final dongHo = Stopwatch()..start();
  // Định tuyến theo CÂU HỎI (mục 9.33): tool mà câu hỏi đòi, nếu bộ tool có nó.
  // Có đích thì phiên chỉ khai MỘT tool ấy (mục 9.34: khai cả bộ là vỡ trần).
  // Từ dự án B đích đến từ đường ghép luật → mô hình nhỏ (`domain/dinh_tuyen.dart`).
  final dt = dinhTuyen(cauHoi);
  final dich = dt.ten;
  final tenDich =
      dich != null && boCongCu.tenCacCongCu.contains(dich) ? dich : null;
  // ⚠️ Định tuyến MỀM (spec dự án B mục 3.1): hai hành vi ÉP bên dưới — tự chạy
  // tool đích khi mô hình không gọi tool nào, và đổi lời gọi sang tool đích —
  // chỉ áp khi nguồn là LUẬT, thứ đã đo trên máy thật. Nguồn mô hình nhỏ chỉ
  // thu phiên về một tool: một câu chào bị định tuyến nhầm mà ép chạy tool giao
  // dịch với `{}` thì người dùng nhận "thiếu kỳ" thay vì một câu trả lời.
  final tenEp = dt.nguon == NguonDinhTuyen.luat ? tenDich : null;
  log('[SLM][tool] định tuyến: ${_taDinhTuyen(dt)}'
      '${dich != null && tenDich == null ? ' — không có trong bộ tool' : ''}');
  // ĐƯỜNG NHANH (spec 2026-10-02): câu giao dịch mà luật đọc đủ tham số → tool chạy
  // TRƯỚC bằng tham số của luật (bộ chỉnh trong tool), Gemma chỉ viết câu — không
  // mở phiên có tool (~20 s Gemma điền tham số trên Realme). Tool từ chối → đường
  // cũ: luật đọc sai thì Gemma còn cơ hội. Xét TRƯỚC `moPhien`: máy đã tắt bậc tool
  // (canary 1b) vẫn đi được.
  if (tenDich == kTenCongCuTruyVan && docDuThamSoGiaoDich(cauHoi)) {
    log('[SLM][tool] đường nhanh: luật đọc đủ → $kTenCongCuTruyVan');
    yield const DangTraCuu(kTenCongCuTruyVan);
    final moc = dongHo.elapsedMilliseconds;
    final kq = await boCongCu.chay(kTenCongCuTruyVan, const {},
        idaccount: idaccount, now: now, cauHoi: cauHoi);
    if (kq != null && kq.loi == null) {
      log('[SLM][tool] đường nhanh: ${kq.hang.length} hàng, ${dongHo.elapsedMilliseconds - moc} ms');
      goi.them(kTenCongCuTruyVan, kq);
      yield* _vietCauDuongNhanh(cauHoi, kq, runtime: runtime, goi: goi, dongHo: dongHo, log: log);
      return;
    }
    log('[SLM][tool] đường nhanh: tool từ chối (${kq?.loi ?? 'không có tool'}) → đường cũ');
  }
  final PhienCongCu phien;
  try {
    phien = await runtime.moPhien(
      // Phiên một tool không nạp ví dụ của tool khác — cùng `tenDich` với khai báo.
      heThong: heThong ?? heThongCho(tenDich),
      cauHoi: cauHoi,
      congCu: boCongCu.khaiBaoCho(tenDich),
    );
  } on BacCongCuDaTat {
    // Máy này từng sập native ở phiên có tool (canary 1b). Bậc 1 không mở
    // phiên có tool nên vẫn chạy được — đi thẳng về đó, không phải L4.
    log('[SLM][tool] bậc tool đã tắt trên máy này (từng sập native) → bậc 1 (L1)');
    yield const KhongTraCuu();
    return;
  }
  var soLanGoi = 0;
  var soCauQua = 0;
  try {
    for (var luot = 1;; luot++) {
      final loiGoi = <GoiCongCu>[];
      final chu = StreamController<String>();
      var biChan = false;

      // Đọc lượt song song với gác: chữ đổ vào `chu`, lời gọi gom lại. Đóng `chu`
      // khi lượt hết để `gacTheoCau` biết luồng đã đóng — phần đuôi chưa có dấu
      // kết cũng phải kiểm (bẫy 4.18).
      final docXong = () async {
        try {
          await for (final sk in phien.sinhLuot()) {
            switch (sk) {
              case Chu(:final token):
                if (!chu.isClosed) chu.add(token);
              case GoiCongCu():
                loiGoi.add(sk);
            }
          }
        } finally {
          await chu.close();
        }
      }();

      if (goi.choHienChuMoHinh) {
        await for (final sk in gacTheoCau(
          chu.stream,
          kiem: (c) => kiemCauTraLoi(c, [goi]),
          huy: phien.huy,
        )) {
          if (sk is CauQua) soCauQua++;
          if (sk is BiChan) biChan = true;
          yield sk;
        }
      } else {
        // Cổng đóng: chữ (nếu có) KHÔNG được hiện — chỉ đếm để log.
        var boQua = 0;
        await for (final t in chu.stream) {
          boQua += t.length;
        }
        if (boQua > 0) {
          log('[SLM][tool] lượt $luot: bỏ $boQua ký tự chữ ${_viSaoDong(goi)}');
        }
      }
      await docXong;

      if (biChan) {
        // gacTheoCau đã huỷ lượt sinh. Chưa câu nào hiện → mẫu câu của gói (L2);
        // đã có câu hiện → giữ, không thêm gì (cùng luật với bậc 1).
        if (soCauQua == 0) {
          log('[SLM][tool] lượt $luot: câu trượt kiểm khi chưa câu nào hiện → mẫu câu (L2)');
          yield CauQua(goi.mauCau().cau);
        } else if (goi.cauChuaKe case final c?) {
          yield CauQua(c);
        }
        return;
      }

      if (loiGoi.isEmpty) {
        if (!goi.daTraCuu && tenEp != null) {
          // Mô hình không gọi tool nào mà LUẬT có đích rõ: tự chạy tool ấy.
          // Phiên không chờ kết quả nào nên không có lượt sinh kế — hiện mẫu câu.
          log('[SLM][tool] lượt $luot: không gọi tool, định tuyến theo câu hỏi → $tenEp, mẫu câu');
          yield DangTraCuu(tenEp);
          final kq = await boCongCu.chay(tenEp, const {},
              idaccount: idaccount, now: now, cauHoi: cauHoi);
          goi.them(tenEp, kq!);
          yield CauQua(goi.mauCau().cau);
          log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: 0 lời gọi, 0 câu');
          return;
        }
        if (!goi.daTraCuu) {
          if (goi.tuChoiChuaGo.isEmpty) {
            log('[SLM][tool] lượt $luot: không gọi tool → bậc 1 (L1) @${dongHo.elapsedMilliseconds} ms');
            yield const KhongTraCuu();
            return;
          }
          log('[SLM][tool] lượt $luot: mọi lời gọi bị từ chối (${_tenTuChoi(goi)}) '
              '→ mẫu câu trung thực (L1b)');
          yield CauQua(goi.mauCau().cau);
          return;
        }
        if (!goi.choHienChuMoHinh) {
          final nhan = _nhanLui(goi);
          log('[SLM][tool] lượt $luot: ${_viSaoDong(goi)} → '
              '${soCauQua == 0 ? 'mẫu câu' : 'nối câu phải nói thêm'} ($nhan)');
          final noiThem = goi.cauNoiThem;
          yield CauQua(
            soCauQua == 0 || noiThem == null
                ? goi.mauCau().cau
                : [noiThem, goi.cauChuaKe].whereType<String>().join(' '),
          );
          log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: $soLanGoi lời gọi, $soCauQua câu');
          return;
        }
        if (soCauQua == 0) {
          log('[SLM][tool] lượt $luot: trả lời rỗng → mẫu câu (L2)');
          yield CauQua(goi.mauCau().cau);
        } else if (goi.cauChuaKe case final c?) {
          // Câu của mô hình kể từ ≤ 4 hàng mà không biết còn hàng nào (N không
          // vào JSON) — nói thay nó (C9, F11 đo OnePlus 2026-10-09).
          log('[SLM][tool] lượt $luot: danh sách bị cắt trần → nối câu chưa kể');
          yield CauQua(c);
        }
        log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: $soLanGoi lời gọi, $soCauQua câu');
        return;
      }

      if (soLanGoi + loiGoi.length > tranGoi) {
        log('[SLM][tool] lượt $luot: ${loiGoi.length} lời gọi nữa vượt trần $tranGoi → mẫu câu (L3)');
        yield CauQua(goi.mauCau().cau);
        return;
      }

      for (final g0 in loiGoi) {
        soLanGoi++;
        // Câu hỏi đòi một tool khác tool mô hình chọn, và tool ấy CHƯA chạy →
        // chạy tool của câu hỏi (không tham số của mô hình: chúng thuộc tool
        // kia). Kết quả vẫn trả về phiên dưới tên lời gọi mô hình đã phát — phiên
        // chờ đúng lời gọi ấy. Chỉ đổi một lần: tool đích đã chạy thì thôi.
        final doi = tenEp != null &&
            g0.ten != tenEp &&
            !goi.tenCongCuDaChay.contains(tenEp);
        final g = doi ? GoiCongCu(tenEp, const {}) : g0;
        if (doi) {
          log('[SLM][tool] lượt $luot: định tuyến theo câu hỏi: ${g0.ten} → $tenEp');
        }
        yield DangTraCuu(g.ten);
        final moc = dongHo.elapsedMilliseconds;
        final kq = await boCongCu.chay(
          g.ten,
          g.args,
          idaccount: idaccount,
          now: now,
          cauHoi: cauHoi,
        );
        if (kq == null) {
          log('[SLM][tool] lượt $luot: gọi ${g.ten} — không có tool này');
          await phien.traKetQua(g0.ten, {
            'loi': 'Không có công cụ tên ${g.ten}. Chỉ có: ${boCongCu.tenCacCongCu.join(', ')}.',
          });
          continue;
        }
        goi.them(g.ten, kq, args: g.args);
        log('[SLM][tool] lượt $luot: gọi ${g.ten} ${g.args} → ${kq.hang.length} hàng'
            '${kq.loi == null ? '' : ', từ chối: ${kq.loi}'}, ${dongHo.elapsedMilliseconds - moc} ms');
        await phien.traKetQua(g0.ten, kq.json);
      }
      // Đã có hàng (hoặc lời từ chối) trước mắt mô hình — màn về "Đang nghĩ…".
      yield const DangTraCuu(null);
    }
  } finally {
    await phien.dong();
  }
}

/// Lượt viết câu của đường nhanh: cổng hiện chữ đóng (0 khoản theo bộ lọc, tool
/// đòi mẫu câu) → mẫu câu ngay, không gọi Gemma; còn lại Gemma viết câu, gác theo
/// câu như mọi lượt; chưa câu nào qua kiểm → mẫu câu (L2), đã có câu hiện thì giữ.
/// `sinhDan` ném → lỗi lan lên màn (L4).
Stream<SuKienGac> _vietCauDuongNhanh(
  String cauHoi,
  KetQuaCongCu kq, {
  required SlmRuntime runtime,
  required GoiSoTraCuu goi,
  required Stopwatch dongHo,
  required void Function(String) log,
}) async* {
  if (!goi.choHienChuMoHinh) {
    log('[SLM][tool] đường nhanh: ${_viSaoDong(goi)} → mẫu câu (${_nhanLui(goi)})');
    yield CauQua(goi.mauCau().cau);
    log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: 0 lời gọi, 0 câu');
    return;
  }
  yield const DangTraCuu(null);
  // C6 (người dùng chọn 2026-10-05): câu hỏi KỂ TÊN mà có ≥ 2 hàng → GIỮ các câu đã qua kiểm tới hết lượt sinh, rồi
  // xét câu trả lời có nêu tên mọi hàng không; thiếu thì mẫu câu đủ dòng thay vào. Câu đã hiện thì không gỡ được,
  // nên phải giữ lại trước — riêng loại câu này mất hiện chữ dần (3–10 s).
  // B14 (cùng khuôn, 2026-10-05): câu hỏi so hai kỳ → câu phải nói đúng HƯỚNG tool đã rút (`so_sanh_*`); thiếu hoặc
  // ngược → mẫu câu (mẫu câu luôn in kết luận).
  final keDu = kq.hang.length >= 2 && cauHoiKeTen(cauHoi);
  final huong = huongCanNoi(kq.chuThem);
  final giu = keDu || huong.isNotEmpty;
  final daGiu = <CauQua>[];
  var soCau = 0;
  await for (final sk in gacTheoCau(
    runtime.sinhDan(promptVietCau(cauHoi, kq.json), tranToken: 300),
    kiem: (c) => kiemCauTraLoi(c, [goi]),
    huy: runtime.huy,
  )) {
    if (sk is CauQua) soCau++;
    if (giu && sk is CauQua) {
      daGiu.add(sk);
    } else {
      yield sk;
    }
  }
  if (giu && soCau > 0) {
    final vanBan = daGiu.map((c) => c.cau).join(' ');
    final thieu = keDu ? tenChuaNeu(vanBan, kq.hang.map((h) => h.ten)) : const <String>[];
    if (thieu.isNotEmpty) {
      log('[SLM][tool] đường nhanh: câu kể tên thiếu ${thieu.length}/${{...kq.hang.map((h) => h.ten)}.length} '
          'hàng → mẫu câu (C6)');
      yield CauQua(goi.mauCau().cau);
    } else if (!cauNoiDungHuong(vanBan, huong)) {
      log('[SLM][tool] đường nhanh: câu so sánh không nói đúng hướng → mẫu câu (B14)');
      yield CauQua(goi.mauCau().cau);
    } else {
      yield* Stream.fromIterable(daGiu);
      if (goi.cauChuaKe case final c?) yield CauQua(c);
    }
  } else if (soCau > 0 && goi.cauChuaKe != null) {
    log('[SLM][tool] đường nhanh: danh sách bị cắt trần → nối câu chưa kể');
    yield CauQua(goi.cauChuaKe!);
  }
  if (soCau == 0) {
    log('[SLM][tool] đường nhanh: chưa câu nào qua kiểm → mẫu câu (L2)');
    yield CauQua(goi.mauCau().cau);
  }
  log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: 0 lời gọi, $soCau câu');
}

/// Một dòng tả kết quả định tuyến — cho log: `luật → X` · `mô hình → X (p=0,93)`
/// · `không (mô hình: Y p=0,41)` · `không`. Lượt đo máy thật đọc dòng này để
/// biết câu đi phiên một tool hay sáu tool, và vì sao.
String _taDinhTuyen(KetQuaDinhTuyen dt) {
  final p = dt.xacSuat?.toStringAsFixed(2).replaceFirst('.', ',');
  return switch (dt.nguon) {
    NguonDinhTuyen.luat => 'luật → ${dt.ten}',
    NguonDinhTuyen.moHinh => 'mô hình → ${dt.ten} (p=$p)',
    NguonDinhTuyen.khong =>
      dt.nhanMoHinh == null ? 'không' : 'không (mô hình: ${dt.nhanMoHinh} p=$p)',
  };
}

/// Tên các tool còn lời từ chối chưa gỡ — cho log.
String _tenTuChoi(GoiSoTraCuu goi) =>
    {for (final r in goi.tuChoiChuaGo) r.ten}.join(', ');

/// Vì sao cổng hiện chữ đóng — cho log; gọi khi cổng đã đóng.
String _viSaoDong(GoiSoTraCuu goi) {
  if (!goi.daTraCuu) return 'trước khi có lượt tool thành công';
  return [
    if (goi.tuChoiChuaGo.isNotEmpty)
      'còn lời từ chối chưa gỡ (${_tenTuChoi(goi)})',
    if (goi.luotRong.isNotEmpty) 'có lượt rỗng theo bộ lọc',
    if (goi.coLuotChiMauCau) 'tool đòi mẫu câu',
  ].join(' và ');
}

/// Nhãn thang lùi khi cổng đóng sau lượt thành công: L2b (lời từ chối), L2c
/// (lượt rỗng theo bộ lọc — bước 2c), L2b+L2c (cả hai). `hoi.sh` dừng theo nhãn.
String _nhanLui(GoiSoTraCuu goi) {
  final coTuChoi = goi.tuChoiChuaGo.isNotEmpty;
  final coRong = goi.luotRong.isNotEmpty;
  if (!coTuChoi && !coRong) return 'L2d';
  return coTuChoi && coRong ? 'L2b+L2c' : (coRong ? 'L2c' : 'L2b');
}
