// test/features/transaction/domain/bo_20_cau_noi_test.dart
/// C4 — bộ 20 câu đọc của spike (soạn 2026-10-01, tên ví / danh mục tài khoản 10) chạy qua LUẬT, mỗi câu hai dạng:
/// chữ như người nói, và chữ số như máy nghe trả về (dạng chữ số là GIẢ ĐỊNH — phần kiểm thử trên máy ghi lời chép
/// thật; mọi dạng thật khác bảng thành ca bổ sung). Spec 2026-10-12 mục 5.
library;

import 'package:flowmoney/features/transaction/domain/doc_cau_giao_dich.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 1, 9); // thứ Năm
  final tienMat = makeWallet(id: 'cash', name: 'Tiền mặt');
  final mb = makeWallet(id: 'mb', name: 'Ví MB Bank').copyWith(type: 'bank');
  final momo = makeWallet(id: 'momo', name: 'Ví MoMo').copyWith(type: 'bank');
  final tk = makeWallet(id: 'tk', name: 'Tiết kiệm').copyWith(type: 'saving');
  final vi = [tienMat, mb, momo, tk];
  final dm = [
    makeCategory(id: 'food', name: 'Ăn uống', isDefault: true),
    makeCategory(id: 'move', name: 'Di chuyển', isDefault: true),
    makeCategory(id: 'shop', name: 'Mua sắm', isDefault: true),
    makeCategory(id: 'edu', name: 'Giáo dục', isDefault: true),
    makeCategory(id: 'luong', name: 'Lương', classify: 'thu', isDefault: true),
    makeCategory(id: 'thuong', name: 'Thưởng', classify: 'thu', isDefault: true),
  ];

  // (số câu, dạng chữ, dạng chữ số, số tiền, đọc bằng dạng nói ở dạng chữ / ở dạng số — `soTienDangNoi`, kiểm thêm)
  final bang = <(int, String, String, double, bool, bool, void Function(KetQuaDocCau))>[
    (1, 'Ăn phở bốn mươi lăm nghìn', 'Ăn phở 45.000', 45000, false, false, (_) {}),
    (2, 'Cà phê hai mươi lăm nghìn', 'Cà phê 25.000', 25000, false, false, (_) {}),
    (3, 'Đổ xăng năm chục', 'Đổ xăng 50', 50000, true, true, (_) {}),
    (4, 'Gửi xe năm nghìn', 'Gửi xe 5.000', 5000, false, false, (_) {}),
    (5, 'Mua sách một trăm hai mươi nghìn', 'Mua sách 120.000', 120000, false, false, (_) {}),
    (6, 'Tiền điện một triệu hai', 'Tiền điện 1,2 triệu', 1200000, true, false, (_) {}),
    (7, 'Tiền nhà hai triệu rưỡi', 'Tiền nhà 2,5 triệu', 2500000, false, false, (_) {}),
    (8, 'Sửa xe ba trăm rưỡi', 'Sửa xe 350', 350000, true, true, (_) {}),
    (
      9,
      'Nhận lương chín triệu',
      'Nhận lương 9 triệu',
      9000000,
      false,
      false,
      (k) {
        expect(k.loai, 'thu');
        expect(k.categoryId, 'luong');
      }
    ),
    (
      10,
      'Thưởng tết ba triệu',
      'Thưởng tết 3 triệu',
      3000000,
      false,
      false,
      (k) {
        expect(k.loai, 'thu');
        expect(k.categoryId, 'thuong');
      }
    ),
    (
      11,
      'Hôm qua ăn trưa bốn mươi lăm nghìn',
      'Hôm qua ăn trưa 45.000',
      45000,
      false,
      false,
      (k) => expect(k.ngay, DateTime(2026, 9, 30))
    ),
    (
      12,
      'Hôm kia đi grab ba mươi lăm nghìn',
      'Hôm kia đi grab 35.000',
      35000,
      false,
      false,
      (k) => expect(k.ngay, DateTime(2026, 9, 29))
    ),
    (
      13,
      'Ngày năm tháng chín mua sách một trăm hai mươi nghìn',
      'Ngày 5 tháng 9 mua sách 120.000',
      120000,
      false,
      false,
      (k) => expect(k.ngay, DateTime(2026, 9, 5))
    ),
    (
      14,
      'Thứ hai đổ xăng năm mươi nghìn',
      'Thứ hai đổ xăng 50.000',
      50000,
      false,
      false,
      (k) => expect(k.ngay, DateTime(2026, 9, 28))
    ),
    (
      15,
      'Đầu tháng đóng học phí hai triệu',
      'Đầu tháng đóng học phí 2 triệu',
      2000000,
      false,
      false,
      (k) => expect(k.ngay, DateTime(2026, 10, 1))
    ),
    (
      16,
      'Mua áo hai trăm nghìn bằng MB Bank',
      'Mua áo 200.000 bằng MB Bank',
      200000,
      false,
      false,
      (k) => expect(k.walletId, 'mb')
    ),
    (
      17,
      'Trà sữa ba mươi nghìn trả bằng MoMo',
      'Trà sữa 30.000 trả bằng MoMo',
      30000,
      false,
      false,
      (k) => expect(k.walletId, 'momo')
    ),
    (
      18,
      'Hôm qua đi chợ một trăm năm mươi nghìn bằng tiền mặt',
      'Hôm qua đi chợ 150.000 bằng tiền mặt',
      150000,
      false,
      false,
      (k) {
        expect(k.ngay, DateTime(2026, 9, 30));
        expect(k.walletId, 'cash');
      }
    ),
    (
      19,
      'Chuyển năm trăm nghìn từ MB Bank sang tiết kiệm',
      'Chuyển 500.000 từ MB Bank sang tiết kiệm',
      500000,
      false,
      false,
      (k) {
        expect(k.loai, 'transfer');
        expect(k.walletId, 'mb');
        expect(k.walletToId, 'tk');
      }
    ),
    (20, 'Thu nợ anh Nam năm trăm nghìn', 'Thu nợ anh Nam 500.000', 500000, false, false, (_) {}),
  ];

  for (final (so, chu, chuSo, tien, kiemChu, kiemSo, them) in bang) {
    for (final (dang, cau, kiem) in [('chữ', chu, kiemChu), ('chữ số', chuSo, kiemSo)]) {
      test('câu $so ($dang): "$cau"', () {
        final k = docCauGiaoDich(cau, now: now, vi: vi, chonDuoc: dm);
        expect(k.soTien, tien);
        expect(k.soTienDangNoi, kiem);
        if (k.soTien != null) {
          expect(cachDocSoTien(cau, now: now), contains(k.soTien), reason: 'bất biến kiểm chéo: số luật ∈ cách đọc');
        }
        them(k);
      });
    }
  }
}
