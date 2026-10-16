/// A5 mục 5.6 — form Thêm giao dịch mở từ ẢNH QUÉT đi qua đúng đường điền sẵn của D1 (`DienSanBienDong`), khoá `quet:`.
library;

import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flowmoney/features/transaction/domain/doc_anh_quet.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../category/presentation/category_test_fakes.dart';

void main() {
  final kq = KetQuaAnhQuet(
    loai: LoaiAnhQuet.hoaDon,
    soTien: 191862,
    chieu: 'chi',
    thoiGian: DateTime(2026, 9, 28, 18, 42),
    ghiChu: 'CO.OPMART',
    mon: const [],
    oThieu: const {},
    aiLap: true,
  );

  test('⭐ deeplinkQuet → dienSanBienDongTuQuery đọc lại đủ: khoá quet:, ảnh, tiền, chiều, giờ, ghi chú, ai', () {
    final u = Uri.parse(deeplinkQuet(kq, anh: 'a1b2c3d4.jpg'));
    expect(u.path, '/add');
    final d = dienSanBienDongTuQuery(u.queryParameters)!;
    expect(d.laQuet, isTrue);
    expect(d.khoa, '${kTienToKhoaQuet}a1b2c3d4.jpg');
    expect(d.anh, 'a1b2c3d4.jpg');
    expect(d.soTien, 191862);
    expect(d.chieu, 'chi');
    expect(d.thoiGian, DateTime(2026, 9, 28, 18, 42));
    expect(d.ghiChu, 'CO.OPMART');
    expect(d.ai, isTrue);
    expect(d.nguon, kNguonAnhQuet);
  });

  test('không đọc ra tiền → query không có amount; không AI → không ai', () {
    final d = dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(
      KetQuaAnhQuet(
          loai: LoaiAnhQuet.bienLai,
          soTien: null,
          chieu: 'thu',
          thoiGian: DateTime(2026, 10, 1),
          ghiChu: '',
          mon: const [],
          oThieu: const {}),
      anh: 'a1b2c3d4.png',
    )).queryParameters)!;
    expect(d.soTien, isNull);
    expect(d.chieu, 'thu');
    expect(d.ai, isFalse);
  });

  test('⭐ hai số lệch (A5 mục 13) → query mang chon=AI,luật, đọc lại đúng thứ tự; không amount', () {
    final u = Uri.parse(deeplinkQuet(
      KetQuaAnhQuet(
          loai: LoaiAnhQuet.hoaDon,
          soTien: null,
          chieu: 'chi',
          thoiGian: DateTime(2026, 9, 6),
          ghiChu: '',
          mon: const [],
          oThieu: const {},
          aiLap: true),
      anh: 'a1b2c3d4.jpg',
      luaChonTien: const [16588, 79243],
    ));
    expect(u.queryParameters['chon'], '16588,79243');
    final d = dienSanBienDongTuQuery(u.queryParameters)!;
    expect(d.soTien, isNull);
    expect(d.luaChonTien, [16588, 79243]);
  });

  test('⭐ danh mục AI chọn → query dm=<tên>, đọc lại; khoá không phải quet: → bỏ', () {
    final u = Uri.parse(deeplinkQuet(kq, anh: 'a1b2c3d4.jpg', danhMucAi: 'Ăn uống'));
    expect(dienSanBienDongTuQuery(u.queryParameters)!.danhMucAi, 'Ăn uống');
    expect(dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(kq, anh: 'a1b2c3d4.jpg')).queryParameters)!.danhMucAi,
        isNull);
    expect(dienSanBienDongTuQuery({'khoa': 'bienDong:x', 'nguon': 'MB', 'dm': 'Ăn uống'})!.danhMucAi, isNull);
  });

  test('chon hỏng / số quá trần / khoá không phải quet: → bỏ', () {
    expect(dienSanBienDongTuQuery({'khoa': 'quet:a', 'nguon': kNguonAnhQuet, 'chon': 'abc,0,-5'})!.luaChonTien,
        isEmpty);
    expect(dienSanBienDongTuQuery({'khoa': 'quet:a', 'nguon': kNguonAnhQuet, 'chon': '10000000000000'})!.luaChonTien,
        isEmpty);
    expect(dienSanBienDongTuQuery({'khoa': 'bienDong:x', 'nguon': 'MB', 'chon': '1000,2000'})!.luaChonTien, isEmpty);
  });

  test('dải nguồn: "Từ ảnh quét · 28/09 18:42", thêm " · Đọc bằng AI" khi ai', () {
    final d = dienSanBienDongTuQuery(Uri.parse(deeplinkQuet(kq, anh: 'a1b2c3d4.jpg')).queryParameters)!;
    expect(dongNguonBienDong(d), 'Từ ảnh quét · 28/09 18:42 · Đọc bằng AI');
  });

  test('khoá bienDong: cũ vẫn đọc như trước (laQuet false, ai bị bỏ qua)', () {
    final d = dienSanBienDongTuQuery({'khoa': 'bienDong:x', 'nguon': 'MB Bank', 'ai': '1'})!;
    expect(d.laQuet, isFalse);
    expect(d.ai, isFalse, reason: 'ai=1 chỉ có nghĩa với khoá quet:');
    expect(dongNguonBienDong(d), 'Từ thông báo MB Bank');
  });

  test('khoá lạ → null; tên ảnh hỏng → không ảnh', () {
    expect(dienSanBienDongTuQuery({'khoa': 'xyz:1', 'nguon': 'A'}), isNull);
    expect(dienSanBienDongTuQuery({'khoa': 'quet:1', 'nguon': kNguonAnhQuet, 'anh': '../x'})!.anh, isNull);
  });

  group('danh mục AI chọn (A5 mục 13)', () {
    final anUong = makeCategory(id: 'food', name: 'Ăn uống');
    final muaSam = makeCategory(id: 'shop', name: 'Mua sắm');
    final luong = makeCategory(id: 'luong', name: 'Lương', classify: 'thu');
    final chonDuoc = [anUong, muaSam, luong];
    DienSanBienDong d(String? dm, {String note = 'PHO 24'}) => dienSanBienDongTuQuery(
        Uri.parse(deeplinkQuet(kq.copyWith(ghiChu: note), anh: 'a1b2c3d4.jpg', danhMucAi: dm)).queryParameters)!;

    test('⭐ tên AI có trong danh mục chọn được → chọn nó, THẮNG từ khoá ghi chú', () {
      final k = ketQuaTuBienDong(d('Mua sắm'), chonDuoc: chonDuoc, tuKhoa: const {
        'food': ['pho'],
      });
      expect(k.categoryId, 'shop');
    });

    test('tên AI khớp sau chuẩn hoá', () {
      expect(ketQuaTuBienDong(d(' ăn UỐNG'), chonDuoc: chonDuoc).categoryId, 'food');
    });

    test('tên AI không có / sai chiều (danh mục thu cho khoản chi) → từ khoá như cũ', () {
      const tk = {
        'food': ['pho'],
      };
      expect(ketQuaTuBienDong(d('Cà phê'), chonDuoc: chonDuoc, tuKhoa: tk).categoryId, 'food');
      expect(ketQuaTuBienDong(d('Lương'), chonDuoc: chonDuoc, tuKhoa: tk).categoryId, 'food');
    });

    test('ghi chú (tên cửa hàng) không khớp từ khoá nào → danh mục chỉ đến từ AI', () {
      expect(ketQuaTuBienDong(d('Ăn uống', note: 'ỦA TEA'), chonDuoc: chonDuoc).categoryId, 'food');
      expect(ketQuaTuBienDong(d(null, note: 'ỦA TEA'), chonDuoc: chonDuoc).categoryId, isNull);
    });
  });
}
