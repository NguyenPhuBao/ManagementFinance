/// Nhãn ảo *Góp quỹ gia đình* / *Rút quỹ gia đình* (`02A` mục 7.2, Task 10 đợt 1B).
///
/// Mã ảo chỉ để GOM nhãn ở thống kê; không đồng bộ, không ghi CSDL. Nhận dạng theo `fundPairId` (nửa RIÊNG: `idhousehold`
/// null), không theo ghi chú.
library;

import 'package:flowmoney/features/transaction/domain/danh_muc_ao_quy.dart';
import 'package:flowmoney/features/transaction/domain/khoan_vao_thong_ke.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('categoryIdThongKe', () {
    test('nửa riêng chưa có danh mục: mã ảo theo chiều', () {
      expect(
        categoryIdThongKe(categoryId: null, fundPairId: 'p', idhousehold: null, loai: 'chi'),
        kDanhMucAoGopQuy,
      );
      expect(
        categoryIdThongKe(categoryId: null, fundPairId: 'p', idhousehold: null, loai: 'thu'),
        kDanhMucAoRutQuy,
      );
    });

    test('nửa riêng đã có danh mục thật giữ danh mục', () {
      expect(
        categoryIdThongKe(categoryId: 'c1', fundPairId: 'p', idhousehold: null, loai: 'chi'),
        'c1',
      );
    });

    test('khoản thường và nửa của nhà không bị đổi mã', () {
      expect(
        categoryIdThongKe(categoryId: null, fundPairId: null, idhousehold: null, loai: 'chi'),
        isNull,
      );
      expect(
        categoryIdThongKe(categoryId: null, fundPairId: 'p', idhousehold: 7, loai: 'chi'),
        isNull,
        reason: 'nửa của nhà không vào thống kê cá nhân; không đoán nhãn cho nó',
      );
    });
  });

  group('nhanAoQuy', () {
    test('hai mã ảo có nhãn, chiều đúng lát: góp là chi, rút là thu', () {
      final gop = nhanAoQuy(kDanhMucAoGopQuy)!;
      final rut = nhanAoQuy(kDanhMucAoRutQuy)!;
      expect(gop.ten, kTenGopQuyGiaDinh);
      expect(gop.classify, 'chi');
      expect(rut.ten, kTenRutQuyGiaDinh);
      expect(rut.classify, 'thu');
      expect(gop.mauHex, startsWith('#'));
      expect(gop.icon, isNotEmpty);
    });

    test('mã khác và null trả null', () {
      expect(nhanAoQuy('c1'), isNull);
      expect(nhanAoQuy(null), isNull);
    });
  });

  group('laNuaRutQuy', () {
    test('chỉ nửa riêng chiều thu của cặp', () {
      expect(laNuaRutQuy(fundPairId: 'p', idhousehold: null, loai: 'thu'), isTrue);
      expect(laNuaRutQuy(fundPairId: 'p', idhousehold: null, loai: 'chi'), isFalse);
      expect(laNuaRutQuy(fundPairId: null, idhousehold: null, loai: 'thu'), isFalse);
      expect(laNuaRutQuy(fundPairId: 'p', idhousehold: 7, loai: 'thu'), isFalse);
    });
  });

  test('khoanVaoThongKe nhận mã ảo: nửa góp / rút vẫn tính, không thành khoản điều chỉnh', () {
    expect(
      khoanVaoThongKe(loai: 'chi', categoryId: kDanhMucAoGopQuy, ghiChu: 'Góp quỹ · tiền chợ'),
      isTrue,
      reason: 'ba hàm con đều đòi categoryId == null; mã ảo làm chúng không khớp, nên nửa góp không bị loại nhầm',
    );
    expect(khoanVaoThongKe(loai: 'thu', categoryId: kDanhMucAoRutQuy, ghiChu: ''), isTrue);
  });
}
