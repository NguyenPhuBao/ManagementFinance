/// Tool `danh_sach_ngan_sach`: hàng theo displayName, căng nhất trước, trạng
/// thái từ `isOverBudget` / `BudgetPace.status`; kỳ vọng tính bằng CHÍNH
/// `budgetPaceOf` chứ không ghi cứng (nếp của gói ngân sách).
library;

import 'package:flowmoney/features/ai_edge/domain/chon.dart';
import 'package:flowmoney/features/ai_edge/domain/goi_so_tra_cuu.dart';
import 'package:flowmoney/features/ai_edge/domain/hang_ngan_sach.dart';
import 'package:flowmoney/features/budget/domain/de_xuat_ngan_sach.dart';
import 'package:flowmoney/features/budget/data/models/budget_entity.dart';
import 'package:flowmoney/features/budget/domain/budget_pace.dart';
import 'package:flutter_test/flutter_test.dart';

BudgetView _ns({
  String id = 'b1',
  String ten = 'Giáo dục',
  required double amount,
  required double spent,
  DateTime? start,
}) {
  final s = start ?? DateTime(2026, 9, 1);
  return BudgetView(
    budget: BudgetEntity(
      id: id,
      idaccount: 7,
      categoryId: 'c-$id',
      amount: amount,
      spent: spent,
      startDate: s,
      recurrence: true,
      timeRecurrence: BudgetRecurrence.month,
      updatedAt: s,
    ),
    categoryName: ten,
  );
}

void main() {
  final now = DateTime(2026, 9, 22);

  test('⭐ căng nhất trước; TÊN là displayName; số từ domain', () {
    final giaoDuc = _ns(id: 'gd', ten: 'Giáo dục', amount: 50000, spent: 45000);
    final anUong = _ns(id: 'au', ten: 'Ăn uống', amount: 500000, spent: 50000);
    final kq = hangNganSach([anUong, giaoDuc], now: now);
    expect(kq.hang.map((h) => h.ten).toList(), ['Giáo dục', 'Ăn uống']);
    final h = kq.hang.first;
    final nhip = budgetPaceOf(giaoDuc.budget, now);
    expect({for (final s in h.soLieu) s.nhan: s.chuoi}, {
      'Đã chi': '45.000 đ',
      'Hạn mức': '50.000 đ',
      'Tỉ lệ': '90,0%',
      'Còn lại': '5.000 đ',
      'Còn': '${nhip.daysLeft} ngày',
    });
    expect(h.soLieu.every((s) => s.ten == 'Giáo dục'), isTrue);
    expect(h.trangThai, chuNhipNganSach(nhip.status));
    expect(h.canhBao, isFalse);
  });

  test('vượt hạn mức: trạng thái "vượt hạn mức", cờ cảnh báo, KHÔNG có Còn lại', () {
    final kq = hangNganSach([_ns(amount: 3000000, spent: 3400000)], now: now);
    final h = kq.hang.single;
    expect(h.trangThai, 'vượt hạn mức');
    expect(h.canhBao, isTrue);
    expect(h.soLieu.any((s) => s.nhan == 'Còn lại'), isFalse,
        reason: '"Còn lại -400.000 đ" là một con số âm người đọc phải tự đảo nghĩa');
  });

  test('tổng hợp: Tổng còn lại = Σ remaining (khớp thẻ tổng trang Ngân sách), Số ngân sách', () {
    final kq = hangNganSach([
      _ns(id: 'a', ten: 'A', amount: 50000, spent: 45000),
      _ns(id: 'b', ten: 'B', amount: 500000, spent: 50000),
      _ns(id: 'c', ten: 'C', amount: 450000, spent: 355000),
      _ns(id: 'd', ten: 'D', amount: 850000, spent: 60000),
    ], now: now);
    expect(kq.tongHop.map((s) => '${s.nhan}=${s.chuoi}').toList(),
        ['Tổng còn lại=1.340.000 đ', 'Số ngân sách=4']);
  });

  test('trần kToiDaMucMoiGoi hàng; Số ngân sách vẫn đủ', () {
    final kq = hangNganSach(
      [for (var i = 0; i < 6; i++) _ns(id: 'n$i', ten: 'N$i', amount: 100000, spent: 10000.0 * i)],
      now: now,
    );
    expect(kq.hang.length, 4);
    expect(kq.tongHop[1].chuoi, '6');
  });

  test('không ngân sách nào: 0 hàng nhưng tool ĐÃ chạy — tổng hợp vẫn có', () {
    final kq = hangNganSach(const [], now: now);
    expect(kq.hang, isEmpty);
    expect(kq.tongHop.map((s) => s.chuoi).toList(), ['0 đ', '0']);
    expect(kq.loi, isNull);
  });

  group('chon (spec tool truy vấn mục 4, E18)', () {
    final bon = [
      _ns(id: 'gd', ten: 'Giáo dục', amount: 50000, spent: 45000),
      _ns(id: 'dc', ten: 'Di chuyển', amount: 450000, spent: 355000),
      _ns(id: 'au', ten: 'Ăn uống', amount: 500000, spent: 50000),
      _ns(id: 'ms', ten: 'Mua sắm', amount: 850000, spent: 60000),
    ];
    test('⭐ duoi_nua → chỉ hàng < 50 %, căng hơn trước; Số ngân sách khớp = 2, Số ngân sách = 4', () {
      final kq = hangNganSach(bon, now: now, chon: 'duoi_nua');
      expect(kq.hang.map((h) => h.ten).toList(), ['Ăn uống', 'Mua sắm'],
          reason: 'E18 lần đo 15: mô hình liệt kê Giáo dục 90 % cho câu "chưa dùng đến một nửa"');
      expect(kq.json['Số ngân sách khớp'], '2');
      expect(kq.json['Số ngân sách'], '4');
      expect(kq.boLoc, ['đã dùng dưới một nửa']);
      expect(kq.rongTheoBoLoc, isFalse);
    });
    test('tren_nua → ≥ 50 %', () {
      expect(hangNganSach(bon, now: now, chon: 'tren_nua').hang.map((h) => h.ten).toList(),
          ['Giáo dục', 'Di chuyển']);
    });
    test('nhieu_nhat / it_nhat → một hàng', () {
      expect(hangNganSach(bon, now: now, chon: 'nhieu_nhat').hang.single.ten, 'Giáo dục');
      expect(hangNganSach(bon, now: now, chon: 'it_nhat').hang.single.ten, 'Mua sắm');
    });
    test('lọc ra 0 hàng → rongTheoBoLoc, tổng hợp vẫn có (Tổng còn lại của MỌI ngân sách)', () {
      final kq = hangNganSach([bon.first], now: now, chon: 'duoi_nua');
      expect(kq.hang, isEmpty);
      expect(kq.rongTheoBoLoc, isTrue);
      expect(kq.json['Tổng còn lại'], '5.000 đ');
      expect(kq.json['Số ngân sách khớp'], '0');
      expect(kq.doiTuongRong, 'ngân sách');
      expect((GoiSoTraCuu()..them('danh_sach_ngan_sach', kq)).mauCau().cau,
          'Đã dùng dưới một nửa — không có ngân sách nào khớp.',
          reason: 'mẫu câu rỗng từng nói "không có giao dịch nào khớp" cho ngân sách');
    });
    test('không chon → như cũ, không có Số ngân sách khớp, không boLoc', () {
      final kq = hangNganSach(bon, now: now);
      expect(kq.json.containsKey('Số ngân sách khớp'), isFalse);
      expect(kq.boLoc, isEmpty);
      expect(kq.rongTheoBoLoc, isFalse);
    });
    test('chon lạ → từ chối kèm bốn giá trị, không hàng nào', () {
      final kq = hangNganSach(bon, now: now, chon: 'x');
      expect(kq.loi, contains('duoi_nua'));
      expect(kq.hang, isEmpty);
    });
  });

  group('hangChuaDatNganSach — chon=chua_dat (spec 2026-09-27 chắn oan + chưa đặt)', () {
    const goi = GoiDeXuat(
      ds: [
        DeXuatNganSach(categoryId: 'cv', tenDanhMuc: 'Cho vay', mucThang: 960000),
        DeXuatNganSach(categoryId: 'gt', tenDanhMuc: 'Giải trí', mucThang: 40000),
      ],
      soNgayCuaSo: 25,
      soUngVien: 2,
    );
    test('⭐ câu người dùng hỏi: hàng theo TÊN danh mục chưa có ngân sách, số là chi trung bình tháng', () {
      final kq = hangChuaDatNganSach(goi, soNganSach: 4);
      expect(kq.hang.map((h) => h.ten).toList(), ['Cho vay', 'Giải trí']);
      expect(kq.hang.first.trangThai, 'chưa đặt ngân sách');
      expect(kq.hang.first.soLieu.single.nhan, 'Chi trung bình mỗi tháng');
      expect(kq.hang.first.soLieu.single.chuoi, '960.000 đ');
      expect(kq.hang.first.soLieu.single.ten, 'Cho vay', reason: 'kiemNhan đòi câu nêu tên');
      expect(kq.json['Số ngân sách'], '4');
      expect(kq.json['Số danh mục chưa đặt'], '2');
      expect(kq.boLoc, ['chưa đặt ngân sách']);
      expect(kq.rongTheoBoLoc, isFalse);
      expect(kq.loi, isNull);
    });
    test('null (tài khoản quá trẻ) hay 0 ứng viên → rongTheoBoLoc, mẫu câu nói "danh mục"', () {
      for (final g in [null, const GoiDeXuat(ds: [], soNgayCuaSo: 20, soUngVien: 0)]) {
        final kq = hangChuaDatNganSach(g, soNganSach: 4);
        expect(kq.hang, isEmpty);
        expect(kq.rongTheoBoLoc, isTrue);
        expect(kq.json['Số danh mục chưa đặt'], '0');
        expect((GoiSoTraCuu()..them('danh_sach_ngan_sach', kq)).mauCau().cau,
            'Chưa đặt ngân sách — không có danh mục nào khớp.');
      }
    });
    test('kChon có chua_dat; hangNganSach KHÔNG nhận mã ấy (đường riêng)', () {
      expect(kChon, contains('chua_dat'));
      expect(kChuChon['chua_dat'], 'chưa đặt ngân sách');
      expect(() => hangNganSach(const [], now: now, chon: 'chua_dat'), throwsArgumentError);
    });
  });

  test('chuNhipNganSach phủ ba nhịp', () {
    expect(chuNhipNganSach(BudgetPaceStatus.fast), 'tiêu nhanh');
    expect(chuNhipNganSach(BudgetPaceStatus.onTrack), 'đúng nhịp');
    expect(chuNhipNganSach(BudgetPaceStatus.slow), 'tiêu chậm');
  });
}
