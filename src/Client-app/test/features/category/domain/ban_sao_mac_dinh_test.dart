import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/features/category/data/models/category_entity.dart';
import 'package:flowmoney/features/category/domain/ban_sao_mac_dinh.dart';

/// Một định nghĩa của "hàng này là bản sao danh mục mặc định" — seeder dùng để không tạo trùng, phép đếm danh mục
/// riêng (Premium) dùng để không tính bản sao (spec phân quyền 2026-10-08 mục 4.2).
void main() {
  final now = DateTime(2026, 10, 8);
  CategoryEntity dm(String ten, {String classify = 'chi', bool macDinh = false}) => CategoryEntity(
        id: ten,
        idaccount: macDinh ? 0 : 10,
        name: ten,
        classify: classify,
        isDefault: macDinh,
        updatedAt: now,
        icon: 'x',
        colour: '#000000',
        isGroup: false,
        isDeleted: false,
        syncStatus: 'synced',
        aiCoDinh: false,
      );
  final khuon = [dm('Ăn uống', macDinh: true), dm('Cho vay', classify: 'Vay/no', macDinh: true)];

  test('khớp tên sau chuẩn hoá (NFC, hoa thường, khoảng trắng) và cùng phân loại', () {
    expect(laBanSaoMacDinh(dm('  ăn   UỐNG '), khuon), isTrue);
    expect(laBanSaoMacDinh(dm('Cho vay', classify: 'Vay/nợ'), khuon), isTrue,
        reason: 'hai cách viết phân loại vay/nợ là một');
  });

  test('khác tên hoặc khác phân loại → không phải bản sao', () {
    expect(laBanSaoMacDinh(dm('Ăn vặt'), khuon), isFalse);
    expect(laBanSaoMacDinh(dm('Ăn uống', classify: 'thu'), khuon), isFalse);
    expect(laBanSaoMacDinh(dm('Ăn uống'), const []), isFalse);
  });

  group('dangAnTheoKhuon — admin xoá mềm khuôn thì bản sao ẩn (spec 2026-10-27 mục 3)', () {
    final sauMoc = DateTime.utc(2026, 10, 28);
    final truocMoc = DateTime.utc(2026, 9, 1);
    CategoryEntity k(String ten, {String classify = 'chi', DateTime? xoaLuc}) => CategoryEntity(
          id: 'k-$ten-$classify-${xoaLuc != null}',
          idaccount: 0,
          name: ten,
          classify: classify,
          isDefault: true,
          isDeleted: xoaLuc != null,
          deletedAt: xoaLuc,
          updatedAt: now,
        );
    CategoryEntity sao(String ten, {String classify = 'chi', bool xoa = false, bool nhom = false}) => CategoryEntity(
          id: 's-$ten',
          idaccount: 10,
          name: ten,
          classify: classify,
          isDeleted: xoa,
          isGroup: nhom,
          updatedAt: now,
        );

    test('⭐ khuôn xoá mềm SAU mốc → bản sao cùng tên + loại ẩn', () {
      expect(dangAnTheoKhuon(sao('Thử khuôn'), [k('Thử khuôn', xoaLuc: sauMoc)]), isTrue,
          reason: 'Người dùng chốt 2026-10-27: admin xoá → ẩn khỏi danh sách chọn.');
    });

    test('khuôn bị xoá TRƯỚC mốc (lượt dọn về 13 mã) → không ẩn', () {
      expect(dangAnTheoKhuon(sao('Thử khuôn'), [k('Thử khuôn', xoaLuc: truocMoc)]), isFalse,
          reason: 'Chốt 5: không ai mở app ra mà mất danh mục cũ.');
    });

    test('mốc so theo thời điểm: đúng 00:00 giờ VN 27/10 là ẩn, một giây trước là không', () {
      expect(dangAnTheoKhuon(sao('Thử khuôn'), [k('Thử khuôn', xoaLuc: kMocAnTheoKhuon)]), isTrue);
      expect(
          dangAnTheoKhuon(sao('Thử khuôn'),
              [k('Thử khuôn', xoaLuc: kMocAnTheoKhuon.subtract(const Duration(seconds: 1)))]),
          isFalse);
    });

    test('khuôn còn sống → không ẩn', () {
      expect(dangAnTheoKhuon(sao('Thử khuôn'), [k('Thử khuôn')]), isFalse);
    });

    test('còn một khuôn SỐNG cùng tên + loại (admin xoá rồi thêm lại) → không ẩn', () {
      expect(dangAnTheoKhuon(sao('Thử khuôn'), [k('Thử khuôn', xoaLuc: sauMoc), k('Thử khuôn')]), isFalse);
    });

    test('bản đã đổi tên, hoặc khác loại → không ẩn', () {
      final khuon = [k('Thử khuôn', xoaLuc: sauMoc)];
      expect(dangAnTheoKhuon(sao('Thử khuôn xe máy'), khuon), isFalse, reason: 'Chốt 2: đổi tên là của người dùng.');
      expect(dangAnTheoKhuon(sao('Thử khuôn', classify: 'thu'), khuon), isFalse);
    });

    test('bản người dùng tự xoá, nhóm, hàng khuôn → không xét', () {
      final khuon = [k('Thử khuôn', xoaLuc: sauMoc)];
      expect(dangAnTheoKhuon(sao('Thử khuôn', xoa: true), khuon), isFalse);
      expect(dangAnTheoKhuon(sao('Thử khuôn', nhom: true), khuon), isFalse);
      expect(dangAnTheoKhuon(k('Thử khuôn', xoaLuc: sauMoc), khuon), isFalse);
    });

    test('cauTrungBanSaoDangAn nêu tên', () {
      expect(cauTrungBanSaoDangAn('Thử khuôn'), '‘Thử khuôn’ là danh mục hệ thống đang tạm ngừng — hãy đặt tên khác.');
    });
  });
}
