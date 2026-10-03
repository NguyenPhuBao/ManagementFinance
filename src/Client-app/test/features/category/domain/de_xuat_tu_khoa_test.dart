/// Đề xuất thêm từ khoá từ thói quen — spec `2026-09-30-de-xuat-them-tu-khoa-design.md` §2.
library;

import 'package:flowmoney/features/bill/domain/bill_note.dart';
import 'package:flowmoney/features/category/domain/de_xuat_tu_khoa.dart';
import 'package:flowmoney/features/category/domain/phan_loai_ghi_chu.dart';
import 'package:flutter_test/flutter_test.dart';

MauGhiChu m(String c, String ghiChu) =>
    MauGhiChu(categoryId: c, amTiet: amTietCua(ghiChu), ngay: DateTime(2026, 9, 1));

List<MauGhiChu> lap(int n, String c, String ghiChu) => [for (var i = 0; i < n; i++) m(c, ghiChu)];

DeXuatTuKhoa? dx(String ghiChu, String c, List<MauGhiChu> mau,
        {Map<String, List<String>> tuKhoa = const {}, Set<(String, String)> tatCap = const {}}) =>
    deXuatTuKhoa(ghiChu: ghiChu, categoryId: c, mau: mau, tuKhoa: tuKhoa, tatCap: tatCap);

void main() {
  group('thói quen — ≥ 3 lần, ≥ 60 %, tính cả lần đang nhập', () {
    test('⭐ hai lần đã lưu + lần đang nhập = 3 → đề xuất', () {
      final d = dx('trà sữa', 'au', lap(2, 'au', 'trà sữa'))!;
      expect((d.tuKhoa, d.cumBoDau, d.categoryId, d.tuDanhMuc, d.soLanCung, d.soLanTong),
          ('trà sữa', 'tra sua', 'au', null, 3, 3));
    });
    test('một lần đã lưu + lần đang nhập = 2 → chưa', () {
      expect(dx('trà sữa', 'au', lap(1, 'au', 'trà sữa')), isNull);
    });
    test('3 lần nhưng chỉ 50 % → không', () {
      expect(dx('trà sữa', 'au', [...lap(2, 'au', 'trà sữa'), ...lap(3, 'gt', 'trà sữa')]), isNull);
    });
    test('mẫu máy sinh không đếm (mẫu đi qua mauHocTu)', () {
      final mau = mauHocTu([
        for (var i = 0; i < 2; i++)
          (loai: 'chi', categoryId: 'au', ghiChu: '$kGhiChuTraHoaDon trà sữa', ngay: DateTime(2026, 9, 1)),
      ]);
      expect(mau, isEmpty, reason: 'tiền đề của ca: ghi chú trả hoá đơn là ghi chú máy');
      expect(dx('trà sữa', 'au', mau), isNull);
    });
  });

  group('cụm nào', () {
    test('⭐ cụm DÀI NHẤT thoả thắng', () {
      expect(dx('trà sữa trân châu', 'au', lap(2, 'au', 'trà sữa trân châu'))!.tuKhoa, 'trà sữa trân châu');
    });
    test('hoà độ dài → cụm đứng trước trong ghi chú', () {
      final mau = [...lap(2, 'au', 'phở bò'), ...lap(2, 'au', 'bún chả')];
      expect(dx('phở bún', 'au', mau)!.tuKhoa, 'phở');
    });
    test('từ khoá lưu CÓ DẤU, chữ thường, đúng đoạn người dùng gõ', () {
      expect(dx('Trà  Sữa', 'au', lap(2, 'au', 'tra sua'))!.tuKhoa, 'trà sữa');
    });
    test('đoạn có chữ số cắt dãy — "trà sữa 40k" đề xuất "trà sữa", kể cả khi cả ba đoạn lặp đủ ngưỡng', () {
      // Mẫu CÙNG "40k": không cắt thì dãy "tra sua 40k" (dài hơn) đủ 3/3 và thắng. Mẫu khác số thì ca không canh gì.
      expect(dx('trà sữa 40k', 'au', lap(2, 'au', 'trà sữa 40k'))!.tuKhoa, 'trà sữa');
      expect(dx('trà sữa 40k', 'au', lap(2, 'au', 'trà sữa 35k'))!.tuKhoa, 'trà sữa');
    });
    test('cụm chỉ là số → không', () {
      expect(dx('500k', 'au', lap(2, 'au', '500k')), isNull);
    });
    test('dưới 3 chữ cái → không', () {
      expect(dx('cf', 'au', lap(2, 'au', 'cf')), isNull);
    });
    test('⭐ chỉ gồm chữ chung → không; có một chữ không chung thì được', () {
      expect(dx('ăn uống', 'au', lap(2, 'au', 'ăn uống')), isNull);
      expect(dx('ăn phở', 'au', lap(2, 'au', 'ăn phở'))!.tuKhoa, 'ăn phở');
    });
    test('ghi chú rỗng → không', () {
      expect(dx('  ', 'au', lap(3, 'au', 'trà sữa')), isNull);
    });
  });

  group('đã là từ khoá / xung đột / tắt', () {
    test('⭐ đã là từ khoá của danh mục ấy (có dấu hoặc bỏ dấu) → không', () {
      final mau = lap(2, 'au', 'trà sữa');
      expect(dx('trà sữa', 'au', mau, tuKhoa: {'au': ['Trà sữa']}), isNull);
      expect(dx('trà sữa', 'au', mau, tuKhoa: {'au': ['tra sua']}), isNull);
    });
    test('ghi chú đã khớp một từ khoá của danh mục ấy → không đề xuất cụm khác ("trà" có rồi thì không "sữa")', () {
      expect(dx('trà sữa', 'au', lap(2, 'au', 'trà sữa'), tuKhoa: {'au': ['trà']}), isNull);
    });
    test('cụm nằm TRONG một từ khoá đã có của danh mục → không (không đề xuất bản rộng hơn)', () {
      expect(dx('trà', 'au', lap(2, 'au', 'trà'), tuKhoa: {'au': ['trà sữa']}), isNull);
    });
    test('⭐ cụm là từ khoá của ĐÚNG MỘT danh mục khác → đề xuất CHUYỂN', () {
      final d = dx('grab', 'dc', lap(2, 'dc', 'grab'), tuKhoa: {'au': ['cơm', 'Grab']})!;
      expect((d.tuKhoa, d.categoryId, d.tuDanhMuc), ('grab', 'dc', 'au'));
    });
    test('⭐ CHUYỂN vẫn đề xuất khi cụm nằm trong một từ khoá dài hơn của danh mục đích (seed cũ: "grabcar")', () {
      // Dữ liệu thật của tài khoản seed cũ, đo trên Realme 2026-10-01: Di chuyển có `grabcar`, Ăn uống có `grab`.
      final tuKhoa = {
        'dc': ['di chuyen', 'grabcar', 'xang'],
        'au': ['an uong', 'food', 'grab'],
      };
      final d = dx('grab', 'dc', lap(6, 'dc', 'grab đi làm'), tuKhoa: tuKhoa);
      expect(d, isNotNull,
          reason: '"grabcar" không bắt được ghi chú "grab …" (bộ so tìm từ khoá TRONG ghi chú), còn "grab" đang kéo '
              'mọi ghi chú ấy về Ăn uống — luật "bản rộng hơn" không được chặn lối sửa này');
      expect((d!.tuKhoa, d.categoryId, d.tuDanhMuc), ('grab', 'dc', 'au'));
    });
    test('cụm nằm trong từ khoá dài hơn của danh mục đích, và thuộc HAI danh mục khác → vẫn không', () {
      expect(
        dx('grab', 'dc', lap(6, 'dc', 'grab'), tuKhoa: {'dc': ['grabcar'], 'au': ['grab'], 'gt': ['grab']}),
        isNull,
      );
    });
    test('cụm là từ khoá của HAI danh mục khác → không', () {
      expect(dx('grab', 'dc', lap(2, 'dc', 'grab'), tuKhoa: {'au': ['grab'], 'gt': ['grab']}), isNull);
    });
    test('⭐ cặp đang bị tắt → không, và KHÔNG rơi xuống cụm ngắn hơn ("trà")', () {
      expect(dx('trà sữa', 'au', lap(2, 'au', 'trà sữa'), tatCap: {('tra sua', 'au')}), isNull);
    });
  });

  group('cungTuKhoa', () {
    test('so chữ thường + gom khoảng trắng, hoặc bỏ dấu', () {
      expect(cungTuKhoa('Grab', 'grab'), isTrue);
      expect(cungTuKhoa('trà  sữa', 'tra sua'), isTrue);
      expect(cungTuKhoa('grab', 'grabfood'), isFalse);
    });
  });
}
