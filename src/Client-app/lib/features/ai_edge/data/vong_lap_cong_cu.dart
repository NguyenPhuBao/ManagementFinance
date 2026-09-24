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
import '../domain/cong_cu.dart';
import '../domain/gac_cau.dart';
import '../domain/goi_so_tra_cuu.dart';
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
  String heThong = kPromptHeThongCongCu,
  int tranGoi = kTranGoiCongCu,
  void Function(String) log = print,
}) async* {
  final dongHo = Stopwatch()..start();
  final PhienCongCu phien;
  try {
    phien = await runtime.moPhien(
      heThong: heThong,
      cauHoi: cauHoi,
      congCu: boCongCu.khaiBao,
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
        }
        return;
      }

      if (loiGoi.isEmpty) {
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
          yield CauQua(soCauQua == 0 ? goi.mauCau().cau : goi.cauNoiThem!);
          log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: $soLanGoi lời gọi, $soCauQua câu');
          return;
        }
        if (soCauQua == 0) {
          log('[SLM][tool] lượt $luot: trả lời rỗng → mẫu câu (L2)');
          yield CauQua(goi.mauCau().cau);
        }
        log('[SLM][tool] xong sau ${dongHo.elapsedMilliseconds} ms: $soLanGoi lời gọi, $soCauQua câu');
        return;
      }

      if (soLanGoi + loiGoi.length > tranGoi) {
        log('[SLM][tool] lượt $luot: ${loiGoi.length} lời gọi nữa vượt trần $tranGoi → mẫu câu (L3)');
        yield CauQua(goi.mauCau().cau);
        return;
      }

      for (final g in loiGoi) {
        soLanGoi++;
        yield DangTraCuu(g.ten);
        final moc = dongHo.elapsedMilliseconds;
        final kq = await boCongCu.chay(g.ten, g.args, idaccount: idaccount, now: now);
        if (kq == null) {
          log('[SLM][tool] lượt $luot: gọi ${g.ten} — không có tool này');
          await phien.traKetQua(g.ten, {
            'loi': 'Không có công cụ tên ${g.ten}. Chỉ có: ${boCongCu.tenCacCongCu.join(', ')}.',
          });
          continue;
        }
        goi.them(g.ten, kq, args: g.args);
        log('[SLM][tool] lượt $luot: gọi ${g.ten} ${g.args} → ${kq.hang.length} hàng'
            '${kq.loi == null ? '' : ', từ chối: ${kq.loi}'}, ${dongHo.elapsedMilliseconds - moc} ms');
        await phien.traKetQua(g.ten, kq.json);
      }
      // Đã có hàng (hoặc lời từ chối) trước mắt mô hình — màn về "Đang nghĩ…".
      yield const DangTraCuu(null);
    }
  } finally {
    await phien.dong();
  }
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
  ].join(' và ');
}

/// Nhãn thang lùi khi cổng đóng sau lượt thành công: L2b (lời từ chối), L2c
/// (lượt rỗng theo bộ lọc — bước 2c), L2b+L2c (cả hai). `hoi.sh` dừng theo nhãn.
String _nhanLui(GoiSoTraCuu goi) {
  final coTuChoi = goi.tuChoiChuaGo.isNotEmpty;
  final coRong = goi.luotRong.isNotEmpty;
  return coTuChoi && coRong ? 'L2b+L2c' : (coRong ? 'L2c' : 'L2b');
}
