// ignore_for_file: avoid_print
/// CHẤM BỘ ĐO KHOÁ của bộ định tuyến học (dự án B, spec mục 6). CHẠY TAY, mặc
/// định bỏ qua:
///
/// ```bash
/// flutter test test/tool/dinh_tuyen/do_bo_do_test.dart --run-skipped
/// ```
///
/// ⚠️ Bộ đo (`bo_do.tsv`) được mở để chấm ĐÚNG MỘT LẦN, sau khi mô hình và
/// ngưỡng đã chốt. Mọi lần chạy sau lần đầu phải ghi là *"đã nhìn bộ đo"* — sửa
/// dữ liệu huấn luyện hay ngưỡng theo kết quả ở đây rồi chạy lại là đang học
/// trên bộ đo. Công cụ này commit TRƯỚC khi chạy lần đầu, để cách chấm không
/// được chọn sau khi đã thấy số.
///
/// ⚠️ Hai bộ dữ liệu do cùng một người soạn: số đo ở đây LẠC QUAN HƠN THỰC TẾ.
///
/// Chấm cái gì: ĐƯỜNG GHÉP — đúng hàm `dinhTuyenCauHoi` chạy trong app (luật
/// trước, mô hình sau, chỉ hành động với `kNhanMoHinhDuocDinhTuyen`). Kèm: luật
/// làm gì với từng câu; mô hình trên phần luật bỏ lại; mô hình đứng riêng; và số
/// của phương án chín tool (không dùng trong app) để khỏi phải mở bộ đo lần hai
/// nếu người dùng muốn xét lại.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flowmoney/features/ai_edge/domain/trong_so_dinh_tuyen.g.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/ai_edge/domain/dinh_tuyen_du_lieu_test.dart' show kBamBoDo;
import 'du_lieu.dart';
import 'huan_luyen.dart';

String _pt(double x) => '${(x * 100).toStringAsFixed(1)} %';
String _p(double? x) => x == null ? '-' : x.toStringAsFixed(3);

/// Kết quả của ĐƯỜNG GHÉP với một câu.
enum _Kq { dung, chapNhan, sai, oLaiDung, boLo }

_Kq _cham(MauDinhTuyen m, KetQuaDinhTuyen r) {
  final ten = r.ten;
  if (ten == null) return m.nhan == kNhanKhongDinhTuyen ? _Kq.oLaiDung : _Kq.boLo;
  if (ten == m.nhan) return _Kq.dung;
  return m.chapNhan.contains(ten) ? _Kq.chapNhan : _Kq.sai;
}

const _chu = {
  _Kq.dung: 'đúng',
  _Kq.chapNhan: 'chấp nhận',
  _Kq.sai: 'SAI',
  _Kq.oLaiDung: 'ở lại (đúng)',
  _Kq.boLo: 'không định tuyến',
};

void main() {
  test(
    'chấm bộ đo khoá — đường ghép luật → mô hình',
    () {
      final tho = docTep(kDuongBoDo);
      expect(bamNoiDung(tho), kBamBoDo, reason: 'bộ đo đã bị sửa — không chấm');
      expect(bamNoiDung(docTep(kDuongBoHuanLuyen)), kBamBoHuanLuyen,
          reason: 'trọng số cũ hơn bộ huấn luyện — sinh lại rồi mới chấm');
      final mau = docTsv(tho);
      print('BỘ ĐO: ${mau.length} câu · mô hình $kLoaiMoHinhDinhTuyen · ngưỡng $kNguongDinhTuyen · '
          'hành động: ${kNhanMoHinhDuocDinhTuyen.join(', ')} · bộ huấn luyện ${kBamBoHuanLuyen.substring(0, 8)}…');

      // ── Từng câu ───────────────────────────────────────────────────────────
      print('\nkết quả | nhãn đúng | luật | mô hình (nhãn p) | đường ghép | câu');
      final dem = {for (final k in _Kq.values) k: 0};
      final saiLuat = <String>[], saiMoHinh = <String>[];
      final duDoan = <DuDoan>[];
      for (final m in mau) {
        final luat = congCuTheoCauHoi(m.cau);
        final d = doanDinhTuyen(kTrongSoDinhTuyen, m.cau);
        duDoan.add(DuDoan(m, d.nhan, d.xacSuat));
        final r = dinhTuyenCauHoi(m.cau);
        final kq = _cham(m, r);
        dem[kq] = dem[kq]! + 1;
        if (kq == _Kq.sai) {
          (r.nguon == NguonDinhTuyen.luat ? saiLuat : saiMoHinh)
              .add('${m.nhan} → ${r.ten}${r.xacSuat == null ? '' : ' (p=${_p(r.xacSuat)})'}: ${m.cau}');
        }
        print('${_chu[kq]} | ${m.nhan} | ${luat ?? '-'} | ${d.nhan} ${_p(d.xacSuat)} | '
            '${r.nguon.name}${r.ten == null ? '' : ' → ${r.ten}'} | ${m.cau}');
      }

      // ── Đường ghép ─────────────────────────────────────────────────────────
      final soTool = mau.where((m) => m.nhan != kNhanKhongDinhTuyen).length;
      print('\n=== ĐƯỜNG GHÉP (${mau.length} câu: $soTool mang nhãn tool, ${mau.length - soTool} nhãn âm) ===');
      print('định tuyến ĐÚNG ${dem[_Kq.dung]} · chấp nhận ${dem[_Kq.chapNhan]} · SAI ${dem[_Kq.sai]} '
          '(do luật ${saiLuat.length}, do mô hình ${saiMoHinh.length})');
      print('không định tuyến ${dem[_Kq.boLo]! + dem[_Kq.oLaiDung]!}: '
          '${dem[_Kq.oLaiDung]} nhãn âm ở lại đúng · ${dem[_Kq.boLo]} câu mang nhãn tool đi phiên sáu tool như cũ');
      for (final s in saiLuat) {
        print('  SAI do LUẬT (ngoài phạm vi dự án B — báo người dùng): $s');
      }
      for (final s in saiMoHinh) {
        print('  SAI do MÔ HÌNH: $s');
      }

      // ── (c) Luật ───────────────────────────────────────────────────────────
      final luatCo = mau.where((m) => congCuTheoCauHoi(m.cau) != null).toList();
      final luatDung = luatCo.where((m) => congCuTheoCauHoi(m.cau) == m.nhan).length;
      print('\n=== LUẬT: định tuyến ${luatCo.length}/${mau.length} câu, đúng nhãn $luatDung ===');

      // ── (a)(b) Mô hình trên phần luật bỏ lại, hành động chỉ nhãn được phép ──
      final boLai = phanLuatBoLai(duDoan, congCuTheoCauHoi);
      final gd = boLai.where((d) => kNhanMoHinhDuocDinhTuyen.contains(d.mau.nhan)).toList();
      final khac = boLai.where((d) => !kNhanMoHinhDuocDinhTuyen.contains(d.mau.nhan)).toList();
      bool tuyen(DuDoan d, [double? t]) =>
          duocDinhTuyen(d, t ?? kNguongDinhTuyen, hanhDong: kNhanMoHinhDuocDinhTuyen);
      final k = danhGia(boLai, kNguongDinhTuyen, hanhDong: kNhanMoHinhDuocDinhTuyen);
      print('\n=== MÔ HÌNH trên phần luật bỏ lại (${boLai.length} câu) — hành động chỉ nhãn được phép ===');
      print('(a) câu mang nhãn được phép: ${gd.length}; được định tuyến ${gd.where(tuyen).length} → phủ ${_pt(k.phu)}');
      print('(b) câu khác: ${khac.length}; bị kéo vào tool được phép ${khac.where(tuyen).length} '
          '(chấp nhận ${k.soChapNhan}, SAI ${k.dinhTuyenSai})');
      print('độ chính xác mười nhãn (không xét ngưỡng): ${_pt(k.chinhXac)}');
      for (final t in [0.5, 0.6, 0.7, 0.8, 0.9, 0.95]) {
        final x = danhGia(boLai, t, hanhDong: kNhanMoHinhDuocDinhTuyen);
        print('  ngưỡng ${t.toStringAsFixed(2)}: định tuyến ${x.soDinhTuyen}, SAI ${x.dinhTuyenSai}, phủ ${_pt(x.phu)}');
      }
      final lech = boLai
          .where((d) => tuyen(d, 0.5) && d.nhanDoan != d.mau.nhan && !d.mau.chapNhan.contains(d.nhanDoan))
          .toList()
        ..sort((a, b) => b.xacSuat.compareTo(a.xacSuat));
      print('câu mô hình kéo NHẦM vào tool được phép ở ngưỡng 0,50 (${lech.length}), p giảm dần:');
      for (final d in lech) {
        print('  ${_p(d.xacSuat)}  ${d.mau.nhan}: ${d.mau.cau}');
      }
      final lo = gd.where((d) => !tuyen(d)).toList()..sort((a, b) => b.xacSuat.compareTo(a.xacSuat));
      print('câu nhãn được phép mà KHÔNG được định tuyến (${lo.length}):');
      for (final d in lo) {
        print('  đoán ${d.nhanDoan} ${_p(d.xacSuat)}: ${d.mau.cau}');
      }
      print('theo nhãn — phần luật bỏ lại (mô hình đoán đúng nhãn / số câu):');
      for (final n in kMuoiNhan) {
        final cua = boLai.where((d) => d.mau.nhan == n).toList();
        print('  ${n.padRight(22)} ${cua.where((d) => d.nhanDoan == n).length}/${cua.length}');
      }

      // ── Phương án CHÍN TOOL (không dùng trong app) ─────────────────────────
      print('\n=== THAM KHẢO — chín tool, phần luật bỏ lại (người dùng đã không chọn) ===');
      for (final t in [kNguongDinhTuyen, 0.8, 0.9, 0.95, 0.98]) {
        final x = danhGia(boLai, t);
        print('  ngưỡng ${t.toStringAsFixed(2)}: định tuyến ${x.soDinhTuyen}, chấp nhận ${x.soChapNhan}, '
            'SAI ${x.dinhTuyenSai}, phủ ${_pt(x.phu)}');
      }

      // ── Mô hình ĐỨNG RIÊNG trên cả bộ đo (spec mục 6: ghi kèm) ─────────────
      final rieng = danhGia(duDoan, kNguongDinhTuyen, hanhDong: kNhanMoHinhDuocDinhTuyen);
      print('\n=== THAM KHẢO — mô hình đứng riêng, cả ${mau.length} câu (trong app không xảy ra) ===');
      print('chính xác mười nhãn ${_pt(rieng.chinhXac)} · định tuyến ${rieng.soDinhTuyen}, '
          'chấp nhận ${rieng.soChapNhan}, SAI ${rieng.dinhTuyenSai}, phủ ${_pt(rieng.phu)}');
    },
    skip: 'chạy tay: --run-skipped — MỞ BỘ ĐO, mỗi lần chạy sau lần đầu ghi "đã nhìn bộ đo"',
  );
}
