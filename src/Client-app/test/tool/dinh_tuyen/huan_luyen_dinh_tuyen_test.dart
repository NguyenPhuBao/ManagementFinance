// ignore_for_file: avoid_print
/// HUẤN LUYỆN bộ định tuyến học (dự án B). CHẠY TAY, mặc định bỏ qua:
///
/// ```bash
/// flutter test test/tool/dinh_tuyen/huan_luyen_dinh_tuyen_test.dart --run-skipped
/// ```
///
/// Đọc `bo_huan_luyen.tsv` → kiểm chéo 5 phần cho Naive Bayes và hồi quy
/// logistic, chấm trên PHẦN LUẬT BỎ LẠI (đường ghép: luật chạy trước) → in bảng
/// so sánh → chọn (spec mục 4.2: ít câu định tuyến sai hơn →
/// phủ cao hơn → hoà thì Naive Bayes) → học lại trên TOÀN BỘ mẫu → ghi
/// `lib/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart`.
///
/// ⚠️ Công cụ này KHÔNG đọc bộ đo (`bo_do.tsv`). Bộ đo chỉ được mở bởi
/// `do_bo_do_test.dart`, sau khi mô hình và ngưỡng đã chốt ở đây.
library;

import 'dart:io';

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'du_lieu.dart';
import 'huan_luyen.dart';

const _duongTrongSo = 'lib/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart';

String _pt(double x) => '${(x * 100).toStringAsFixed(1)} %';

void _inBang(String ten, List<DuDoan> d, double? nguong) {
  print('\n=== $ten ===');
  print('độ chính xác (mười nhãn, kiểm chéo): ${_pt(danhGia(d, 0.5).chinhXac)}');
  for (final t in [0.5, 0.6, 0.7, 0.8, 0.9, 0.95]) {
    final k = danhGia(d, t);
    print('  ngưỡng ${t.toStringAsFixed(2)}: định tuyến ${k.soDinhTuyen}, SAI ${k.dinhTuyenSai}, phủ ${_pt(k.phu)}');
  }
  if (nguong == null) {
    print('NGƯỠNG: không có mức nào ≤ 0,99 cho 0 câu sai → LOẠI');
  } else {
    final k = danhGia(d, nguong);
    print('NGƯỠNG CHỌN ${nguong.toStringAsFixed(2)}: định tuyến ${k.soDinhTuyen}, SAI ${k.dinhTuyenSai}, phủ ${_pt(k.phu)}');
  }
  print('theo nhãn (đoán đúng nhãn / tổng · định tuyến đúng ở ngưỡng chọn):');
  for (final n in kMuoiNhan) {
    final cua = d.where((x) => x.mau.nhan == n).toList();
    final dung = cua.where((x) => x.nhanDoan == n).length;
    final tuyen = nguong == null
        ? 0
        : cua.where((x) => x.nhanDoan == n && duocDinhTuyen(x, nguong)).length;
    print('  ${n.padRight(22)} $dung/${cua.length} · $tuyen');
  }
  final sai = d.where((x) => duocDinhTuyen(x, 0.5) && x.nhanDoan != x.mau.nhan).toList()
    ..sort((a, b) => b.xacSuat.compareTo(a.xacSuat));
  print('câu định tuyến SAI ở ngưỡng 0,50 (${sai.length}), p giảm dần:');
  for (final x in sai) {
    print('  ${x.xacSuat.toStringAsFixed(3)}  ${x.mau.nhan} → ${x.nhanDoan}: ${x.mau.cau}');
  }
}

void main() {
  test(
    'huấn luyện, so sánh hai mô hình, ghi tệp trọng số',
    () {
      final tho = docTep(kDuongBoHuanLuyen);
      final mau = khuTrung(docTsv(tho));
      print('bộ huấn luyện: ${mau.length} câu sau khử trùng, '
          '${tuVungTu(mau).length} đặc trưng (có ở ≥ 2 câu)');

      // ĐƯỜNG GHÉP: luật chạy trước. Câu luật đã định tuyến không tới mô hình —
      // chấm mô hình CHỈ trên phần luật bỏ lại (học thì vẫn trên toàn bộ mẫu).
      final luatCo = mau.where((m) => congCuTheoCauHoi(m.cau) != null).toList();
      final luatSai = luatCo.where((m) => congCuTheoCauHoi(m.cau) != m.nhan).toList();
      print('\nLUẬT định tuyến ${luatCo.length}/${mau.length} câu; lệch nhãn ${luatSai.length} câu '
          '(ngoài phạm vi dự án B — chỉ ghi lại):');
      for (final m in luatSai) {
        print('  ${m.nhan} → ${congCuTheoCauHoi(m.cau)}: ${m.cau}');
      }
      print('phần luật bỏ lại cho mô hình: ${mau.length - luatCo.length} câu');

      final ungVien = <(String, HamHoc)>[('naive_bayes', hocNaiveBayes), ('logistic', hocLogistic)];
      final ketQua = <(String, HamHoc, double, ThongKe)>[];
      for (final (ten, hoc) in ungVien) {
        final d = phanLuatBoLai(kiemCheo(mau, kMuoiNhan, hoc), congCuTheoCauHoi);
        final nguong = chonNguong(d);
        _inBang(ten, d, nguong);
        if (nguong != null) ketQua.add((ten, hoc, nguong, danhGia(d, nguong)));
      }
      if (ketQua.isEmpty) fail('không mô hình nào đạt 0 câu định tuyến sai — không ghi trọng số');

      // Ít câu sai hơn → phủ cao hơn → hoà thì ứng viên đứng trước (Naive Bayes).
      ketQua.sort((a, b) {
        final s = a.$4.dinhTuyenSai.compareTo(b.$4.dinhTuyenSai);
        return s != 0 ? s : b.$4.phu.compareTo(a.$4.phu);
      });
      final (ten, hoc, nguong, tk) = ketQua.first;
      print('\n>>> CHỌN $ten, ngưỡng ${nguong.toStringAsFixed(2)}, phủ kiểm chéo ${_pt(tk.phu)}');

      final w = hoc(mau, kMuoiNhan);
      final tep = sinhTepTrongSo(w, loai: ten, nguong: nguong, bamHuanLuyen: bamNoiDung(tho));
      File(_duongTrongSo).writeAsStringSync(tep);
      print('đã ghi $_duongTrongSo: ${w.tuVung.length} đặc trưng × ${w.nhan.length} nhãn, '
          '${(tep.length / 1024).toStringAsFixed(1)} KB');

      // Trên chính bộ huấn luyện, phần luật bỏ lại (KHÔNG phải số đo — chỉ để
      // thấy mô hình khớp dữ liệu tới đâu).
      final tren = phanLuatBoLai([
        for (final m in mau)
          () {
            final d = doanDinhTuyen(w, m.cau);
            return DuDoan(m, d.nhan, d.xacSuat);
          }(),
      ], congCuTheoCauHoi);
      final k = danhGia(tren, nguong);
      print('trên chính bộ huấn luyện: chính xác ${_pt(k.chinhXac)}, định tuyến ${k.soDinhTuyen}, '
          'SAI ${k.dinhTuyenSai}, phủ ${_pt(k.phu)}');
    },
    skip: 'chạy tay: --run-skipped (ghi đè tệp trọng số)',
  );
}
