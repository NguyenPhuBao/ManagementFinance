/// Mẫu học của hai bộ gợi ý danh mục — B1 (ghi chú, `mauHocTu`) và dự án C (số tiền, `mauSoTienTu`) — dựng từ hàng sổ
/// qua `laGhiChuMay`. Hai nhóm ca dời nguyên văn từ `category/domain/phan_loai_ghi_chu_test.dart` và
/// `phan_loai_so_tien_test.dart` (2026-10-16, quét 29).
library;

import 'package:flowmoney/features/category/domain/phan_loai_so_tien.dart';
import 'package:flowmoney/features/goal/domain/goal_history_direction.dart';
import 'package:flowmoney/features/transaction/domain/ghi_chu_gop_quy.dart';
import 'package:flowmoney/features/transaction/domain/khoan_vao_thong_ke.dart';
import 'package:flowmoney/features/transaction/domain/mau_hoc_danh_muc.dart';
import 'package:flowmoney/features/transaction/domain/transaction_owner.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _GiaoDich = ({
  String loai,
  String? categoryId,
  String? ghiChu,
  double soTien,
  String walletId,
  DateTime ngay,
  bool daXoa
});

/// Mặc định: khoản chi, không ghi chú, ví cash, 01/09/2026 (thứ Ba).
_GiaoDich _gd(
  String? c,
  double soTien, {
  String loai = 'chi',
  String? ghiChu = '',
  String vi = 'cash',
  DateTime? ngay,
  bool daXoa = false,
}) =>
    (
      loai: loai,
      categoryId: c,
      ghiChu: ghiChu,
      soTien: soTien,
      walletId: vi,
      ngay: ngay ?? DateTime(2026, 9, 1),
      daXoa: daXoa,
    );

void main() {
  group('laGhiChuMay / mauHocTu', () {
    test('⭐ mọi ghi chú máy sinh bị loại — học chúng là dạy "thanh toán hóa đơn" là một danh mục', () {
      for (final g in [
        '${kGhiChuTraHoaDon}Tiền điện',
        '${kGhiChuNapMucTieu}MuaXe',
        '${kGhiChuRutMucTieu}MuaXe',
        'Tích lũy nhận từ Tiền mặt',
      ]) {
        expect(laGhiChuMay(loai: 'chi', categoryId: 'c', ghiChu: g), isTrue, reason: g);
      }
      expect(laGhiChuMay(loai: 'thu', categoryId: null, ghiChu: 'Điều chỉnh số dư'), isTrue);
      expect(laGhiChuMay(loai: 'thu', categoryId: null, ghiChu: 'Số dư ban đầu'), isTrue);
      expect(laGhiChuMay(loai: 'chi', categoryId: 'c', ghiChu: 'cafe'), isFalse);
    });
    test('laGhiChuMay nhận tiền tố góp, rút kể cả khi đã gắn danh mục', () {
      expect(laGhiChuMay(loai: 'chi', categoryId: 'x', ghiChu: 'Góp quỹ · Tiền chợ'), isTrue,
          reason: 'sau khi rời nhà sửa thêm danh mục thì không được dạy B1 câu do máy sinh');
      expect(laGhiChuMay(loai: 'thu', categoryId: 'x', ghiChu: 'Rút quỹ · Tiền chợ'), isTrue);
      expect(laGhiChuMay(loai: 'chi', categoryId: 'x', ghiChu: kTienToGopQuy), isTrue);
      expect(laGhiChuMay(loai: 'chi', categoryId: 'x', ghiChu: 'Góp bạn bè đi ăn'), isFalse,
          reason: 'chỉ đúng tiền tố có dấu chấm giữa, không phải mọi câu bắt đầu bằng "Góp"');
    });
    test('bỏ: không danh mục, ghi chú rỗng, khoản chuyển, ghi chú chỉ toàn số; giữ phần còn lại', () {
      final ra = mauHocTu([
        (loai: 'chi', categoryId: null, ghiChu: 'cafe', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: '   ', ngay: DateTime(2026, 9, 1)),
        (loai: 'transfer', categoryId: 'au', ghiChu: 'cafe', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: '50000', ngay: DateTime(2026, 9, 1)),
        (loai: 'chi', categoryId: 'au', ghiChu: 'Cafe sáng', ngay: DateTime(2026, 9, 2)),
      ]);
      // ⚠️ Không so bản ghi chứa List: Dart so List theo danh tính, ca đỏ oan.
      expect(ra.single.categoryId, 'au');
      expect(ra.single.amTiet, ['cafe', 'sang']);
    });
  });

  group('mauSoTienTu', () {
    test('⭐ khoản KHÔNG ghi chú vẫn là mẫu — tín hiệu ở đây là số tiền', () {
      final m = mauSoTienTu([_gd('food', 30000, ghiChu: null), _gd('food', 30000, ghiChu: '')]);
      expect(m, hasLength(2));
      expect(m.first.categoryId, 'food');
      expect(m.first.chieu, 'chi');
      expect(m.first.maBac, '20000-50000');
      expect(m.first.nhomThu, kNhomNgayThuong);
      expect(m.first.walletId, 'cash');
    });

    test('bỏ khoản chuyển khoản', () => expect(mauSoTienTu([_gd('food', 30000, loai: 'transfer')]), isEmpty));
    test('bỏ khoản không danh mục', () => expect(mauSoTienTu([_gd(null, 30000)]), isEmpty));
    test('bỏ khoản đã xoá', () => expect(mauSoTienTu([_gd('food', 30000, daXoa: true)]), isEmpty));
    test('bỏ khoản số tiền 0', () => expect(mauSoTienTu([_gd('food', 0)]), isEmpty));
    test('bỏ khoản do máy gắn ghi chú (trả hoá đơn)', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: '${kGhiChuTraHoaDon}Tiền nhà')]), isEmpty);
    });

    test('ghi chú do người gõ không làm mất mẫu', () {
      expect(mauSoTienTu([_gd('food', 30000, ghiChu: 'cafe sáng')]), hasLength(1));
    });

    test('nửa riêng của cặp góp / rút (không danh mục) không vào mẫu nào, kể cả có ghi chú', () {
      // Nửa riêng của cặp không có danh mục: cả hai bộ mẫu đều đòi categoryId nên bỏ nó, không cần đổi laGhiChuMay.
      final ra1 = mauHocTu([(loai: 'chi', categoryId: null, ghiChu: 'góp quỹ nhà', ngay: DateTime(2026, 9, 1))]);
      final ra2 = mauSoTienTu([_gd(null, 30000, ghiChu: 'góp quỹ nhà')]);
      expect(ra1, isEmpty, reason: 'nửa riêng không danh mục không được dạy B1');
      expect(ra2, isEmpty, reason: 'nửa riêng không danh mục không được dạy gợi ý theo số tiền');
    });
  });
}
