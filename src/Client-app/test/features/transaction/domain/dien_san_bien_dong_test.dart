/// D1 Task 7 — điền sẵn form Thêm giao dịch từ một hàng biến động số dư (spec D1 §3.3). Hàm thuần: đọc
/// query `/add?…` mà `NhapBienDong` dựng, dựng `KetQuaDocCau` cho đường điền của C2, dòng nguồn, và lọc
/// khoản trong sổ có thể đã ghi.
library;

import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final tin = TinBienDong(
    soTien: 45000,
    chieu: 'chi',
    thoiGian: DateTime(2026, 9, 2, 12, 1),
    noiDung: 'PHO 24',
    nguon: kNguonMb,
    duoiTaiKhoan: '7777',
  );
  Map<String, String> query([TinBienDong? t]) =>
      Uri.parse(deeplinkBienDong(t ?? tin, dedupeKey: 'bienDong:MB Bank|45000|chi|2026-09-02T12:01')).queryParameters;

  group('dienSanBienDongTuQuery', () {
    test('⭐ đọc ngược ĐÚNG deeplink của NhapBienDong (hai phía một hợp đồng)', () {
      final d = dienSanBienDongTuQuery(query())!;
      expect(d.soTien, 45000);
      expect(d.chieu, 'chi');
      expect(d.thoiGian, DateTime(2026, 9, 2, 12, 1));
      expect(d.ghiChu, 'PHO 24');
      expect(d.nguon, kNguonMb);
      expect(d.duoi, '7777');
      expect(d.khoa, 'bienDong:MB Bank|45000|chi|2026-09-02T12:01');
    });

    test('không có khoa bienDong: hoặc thiếu nguồn → null (mở /add thường, form trống)', () {
      expect(dienSanBienDongTuQuery(const {}), isNull);
      expect(dienSanBienDongTuQuery(const {'amount': '5000', 'nguon': kNguonMb}), isNull);
      expect(dienSanBienDongTuQuery(const {'khoa': 'billDue:x', 'nguon': kNguonMb}), isNull,
          reason: 'chỉ hàng loại 20 mới được xoá cứng lúc Lưu — khoá lạ không được mở đường ấy');
      expect(dienSanBienDongTuQuery(const {'khoa': 'bienDong:x', 'nguon': ' '}), isNull);
    });

    test('trường hỏng thì bỏ ĐÚNG trường ấy, không ném (query gõ tay được)', () {
      final d = dienSanBienDongTuQuery(const {
        'khoa': 'bienDong:x',
        'nguon': kNguonMb,
        'amount': '-5',
        'huong': 'transfer',
        'date': 'hôm qua',
        'duoi': '',
      })!;
      expect((d.soTien, d.chieu, d.thoiGian, d.duoi, d.ghiChu), (null, null, null, null, ''));
      expect(dienSanBienDongTuQuery(const {'khoa': 'bienDong:x', 'nguon': kNguonMb, 'amount': '10000000000000'})!.soTien,
          isNull, reason: 'quá 13 chữ số là tràn numeric(15,2) — bản ghi kẹt hàng đợi đẩy');
    });
  });

  test('dòng nguồn: nguồn · đuôi TK · ngày giờ trong tin — thiếu thì bỏ vế', () {
    expect(dongNguonBienDong(dienSanBienDongTuQuery(query())!), 'Từ thông báo MB Bank · TK ••7777 · 02/09 12:01');
    expect(dongNguonBienDong(dienSanBienDongTuQuery(const {'khoa': 'bienDong:x', 'nguon': kNguonMomo})!),
        'Từ thông báo MoMo');
  });

  group('ketQuaTuBienDong', () {
    final anUong = makeCategory(id: 'c-an', name: 'Ăn uống');
    final luong = makeCategory(id: 'c-luong', name: 'Lương', classify: 'thu');
    final ds = [anUong, luong];

    test('⭐ tiền, chiều, NGÀY (đầu ngày — form giữ giờ riêng), ghi chú = nội dung, ví truyền vào', () {
      final kq = ketQuaTuBienDong(dienSanBienDongTuQuery(query())!, chonDuoc: ds, walletId: 'w-mb');
      expect(kq.soTien, 45000);
      expect(kq.loai, 'chi');
      expect(kq.ngay, DateTime(2026, 9, 2));
      expect(kq.ghiChu, 'PHO 24');
      expect(kq.walletId, 'w-mb');
      expect(kq.khongDocDuocGi, isFalse);
    });

    test('⭐ danh mục đoán trên NỘI DUNG tin bằng luật C2 (từ khoá) và chỉ trong danh mục HỢP CHIỀU', () {
      final kq = ketQuaTuBienDong(
        dienSanBienDongTuQuery(query())!,
        chonDuoc: ds,
        tuKhoa: const {
          'c-an': ['pho'],
          'c-luong': ['pho'],
        },
      );
      expect(kq.categoryId, 'c-an',
          reason: 'tin là tiền RA — danh mục thu (Lương) không được đoán dù cùng từ khoá (C1 hopLeTheoChieu)');
      expect(kq.goiY, isNotNull, reason: 'màn ghi phản hồi chon / khac lúc lưu như thẻ gợi ý');
    });

    test('không đoán được danh mục → để trống (thẻ gợi ý của màn lo tiếp), không bịa', () {
      final kq = ketQuaTuBienDong(dienSanBienDongTuQuery(query())!, chonDuoc: ds);
      expect(kq.categoryId, isNull);
    });
  });

  group('khoanCoTheDaGhi', () {
    final so = <KhoanSo>[
      (id: 'a', soTien: 45000, loai: 'chi', ngay: DateTime(2026, 9, 2, 8), ghiChu: ''),
      (id: 'b', soTien: 45000, loai: 'thu', ngay: DateTime(2026, 9, 2, 12), ghiChu: ''),
      (id: 'c', soTien: 45000, loai: 'chi', ngay: DateTime(2026, 9, 3, 0, 5), ghiChu: ''),
      (id: 'd', soTien: 45000.3, loai: 'chi', ngay: DateTime(2026, 9, 2, 23, 59), ghiChu: ''),
      (id: 'e', soTien: 46000, loai: 'chi', ngay: DateTime(2026, 9, 2, 12), ghiChu: ''),
    ];

    test('⭐ cùng số tiền (ngưỡng nửa đồng), cùng chiều, cùng NGÀY lịch', () {
      final t = khoanCoTheDaGhi(so, soTien: 45000, chieu: 'chi', ngay: DateTime(2026, 9, 2, 12, 1));
      expect(t.map((k) => k.id), ['a', 'd'],
          reason: 'b khác chiều · c khác ngày (dù cách 12 phút) · e khác tiền');
    });

    test('thiếu tiền / chiều / ngày → không nhắc (không đủ căn cứ để nói "có thể đã ghi")', () {
      expect(khoanCoTheDaGhi(so, soTien: null, chieu: 'chi', ngay: DateTime(2026, 9, 2)), isEmpty);
      expect(khoanCoTheDaGhi(so, soTien: 45000, chieu: null, ngay: DateTime(2026, 9, 2)), isEmpty);
      expect(khoanCoTheDaGhi(so, soTien: 45000, chieu: 'chi', ngay: null), isEmpty);
    });
  });
}
