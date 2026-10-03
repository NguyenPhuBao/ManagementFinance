/// Dự án B — ĐƯỜNG GHÉP của định tuyến: luật trước, mô hình sau (spec
/// `2026-10-02-du-an-b-mo-hinh-dinh-tuyen-cau-hoi-design.md` mục 3).
///
/// Canh chừng điều gì: thứ tự hai tầng và tập nhãn được hành động. Luật là thứ
/// đã đo trên máy thật — mô hình nhỏ giành một câu của luật, hoặc được nghe khi
/// nó đoán một tool ngoài tập người dùng đã chốt (hướng 1), thì câu ấy đổi
/// đường mà không exception nào báo.
library;

import 'package:flowmoney/features/ai_edge/domain/chinh_tham_so.dart';
import 'package:flowmoney/features/ai_edge/domain/cong_cu.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen.dart';
import 'package:flowmoney/features/ai_edge/domain/dinh_tuyen_hoc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Trọng số TAY: mỗi đặc trưng đẩy hẳn về một nhãn (e^5 / (e^5 + 2) ≈ 0,987).
  final w = TrongSoDinhTuyen(
    nhan: [kTenCongCuTruyVan, kTenCongCuHoaDon, kNhanKhongDinhTuyen],
    tuVung: ['tieu', 'hoa don', 'chao', 'qua han'],
    thienLech: [0, 0, 0],
    maTran: [
      5, 0, 0, // tieu → giao dịch
      0, 5, 0, // hoa don → hoá đơn
      0, 0, 5, // chao → không định tuyến
      9, 0, 0, // qua han → giao dịch (cố ý NGƯỢC luật — ca "luật trước")
    ],
  );

  const cauGiaoDich = 'thang nay toi tieu gi tren 500k';
  const cauHoaDonLuatBo = 'Hoa don nao toi da tra?';
  const cauChao = 'xin chao';

  test('tiền đề: ba câu thử đều là câu LUẬT bỏ lại — luật giành chúng thì các ca dưới mất nghĩa', () {
    for (final c in [cauGiaoDich, cauHoaDonLuatBo, cauChao]) {
      expect(congCuTheoCauHoi(c), isNull, reason: c);
    }
    expect(kNhanMoHinhDuocDinhTuyen, contains(kTenCongCuTruyVan));
    expect(kNhanMoHinhDuocDinhTuyen, isNot(contains(kTenCongCuHoaDon)),
        reason: 'ca "tool ngoài tập" dựa vào việc hoá đơn CHƯA được mở');
  });

  test('⭐ luật có tool → nguồn luật, mô hình KHÔNG được hỏi', () {
    final r = dinhTuyenCauHoi('Hoa don nao qua han?', trongSo: w, nguong: 0.5);
    expect(r.ten, kTenCongCuHoaDon,
        reason: 'trọng số tay đẩy "qua han" về tool giao dịch ở p ≈ 1 — luật vẫn thắng');
    expect(r.nguon, NguonDinhTuyen.luat);
    expect(r.nhanMoHinh, isNull);
    expect(r.xacSuat, isNull);
  });

  test('luật im, mô hình đoán nhãn ĐƯỢC PHÉP ở p ≥ ngưỡng → nguồn mô hình', () {
    final r = dinhTuyenCauHoi(cauGiaoDich, trongSo: w, nguong: 0.9);
    expect(r.ten, kTenCongCuTruyVan);
    expect(r.nguon, NguonDinhTuyen.moHinh);
    expect(r.nhanMoHinh, kTenCongCuTruyVan);
    expect(r.xacSuat, closeTo(0.987, 0.001));
  });

  test('p đúng BẰNG ngưỡng thì định tuyến (≥, không phải >)', () {
    final p = dinhTuyenCauHoi(cauGiaoDich, trongSo: w, nguong: 0).xacSuat!;
    expect(dinhTuyenCauHoi(cauGiaoDich, trongSo: w, nguong: p).nguon, NguonDinhTuyen.moHinh);
  });

  test('dưới ngưỡng → không định tuyến, nhưng nhãn và xác suất vẫn ghi (cho log)', () {
    final r = dinhTuyenCauHoi(cauGiaoDich, trongSo: w, nguong: 0.995);
    expect(r.ten, isNull);
    expect(r.nguon, NguonDinhTuyen.khong);
    expect(r.nhanMoHinh, kTenCongCuTruyVan);
    expect(r.xacSuat, closeTo(0.987, 0.001));
  });

  test('⭐ hướng 1: mô hình đoán tool NGOÀI tập được phép (p ≈ 0,99) → không định tuyến', () {
    final r = dinhTuyenCauHoi(cauHoaDonLuatBo, trongSo: w, nguong: 0.5);
    expect(r.ten, isNull,
        reason: 'kiểm chéo: với tám tool ngoài giao dịch mô hình sai ở p = 0,91–0,93 — '
            'người dùng chốt chỉ nghe nó khi nó đoán nhãn giao dịch');
    expect(r.nguon, NguonDinhTuyen.khong);
    expect(r.nhanMoHinh, kTenCongCuHoaDon);
    expect(r.xacSuat, greaterThan(0.9));
  });

  test('mô hình đoán nhãn ÂM với p cao → không định tuyến', () {
    final r = dinhTuyenCauHoi(cauChao, trongSo: w, nguong: 0.5);
    expect(r.ten, isNull);
    expect(r.nguon, NguonDinhTuyen.khong);
    expect(r.nhanMoHinh, kNhanKhongDinhTuyen);
  });

  test('câu rỗng → không định tuyến', () {
    final r = dinhTuyenCauHoi('', trongSo: w, nguong: 0);
    expect(r.ten, isNull);
    expect(r.nguon, NguonDinhTuyen.khong);
  });

  test('dinhTuyenChiLuat: chỉ luật — câu luật bỏ lại không bao giờ tới mô hình', () {
    final co = dinhTuyenChiLuat('Hoa don nao qua han?');
    expect((co.ten, co.nguon), (kTenCongCuHoaDon, NguonDinhTuyen.luat));
    final khong = dinhTuyenChiLuat(cauGiaoDich);
    expect((khong.ten, khong.nguon, khong.nhanMoHinh, khong.xacSuat),
        (null, NguonDinhTuyen.khong, null, null));
  });

  test('⭐ không truyền ngưỡng → dùng kNguongDinhTuyen của tệp sinh ra, không phải 0', () {
    // Trọng số 1 → p = e / (e + 2) ≈ 0,576: dưới mọi ngưỡng hợp lệ (sàn 0,60).
    final yeu = TrongSoDinhTuyen(
      nhan: [kTenCongCuTruyVan, kTenCongCuHoaDon, kNhanKhongDinhTuyen],
      tuVung: ['tieu'],
      thienLech: [0, 0, 0],
      maTran: [1, 0, 0],
    );
    final r = dinhTuyenCauHoi(cauGiaoDich, trongSo: yeu);
    expect(r.xacSuat, closeTo(0.576, 0.001));
    expect(r.ten, isNull,
        reason: 'bảng 72 câu KHÔNG bắt được lỗi này: 72 câu là in-sample nên mô hình vốn đoán đúng, '
            'ngưỡng 0 vẫn cho ra cùng đường — thử bằng bản sai 2026-10-02');
    expect(dinhTuyenCauHoi(cauGiaoDich, trongSo: w).ten, kTenCongCuTruyVan,
        reason: 'p ≈ 0,987 vượt ngưỡng sinh ra (trần kẹp 0,99 — sửa ca này nếu ngưỡng lên tới đó)');
  });

  test('mặc định dùng trọng số và ngưỡng SINH RA: câu chào không bị định tuyến', () {
    final r = dinhTuyenCauHoi('xin chào bạn');
    expect(r.ten, isNull);
    expect(r.nguon, NguonDinhTuyen.khong);
  });
}
