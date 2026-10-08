import 'package:flutter_test/flutter_test.dart';

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/category/domain/ban_sao_mac_dinh.dart';

/// Một định nghĩa của "hàng này là bản sao danh mục mặc định" — seeder dùng để không tạo trùng, phép đếm danh mục
/// riêng (Premium) dùng để không tính bản sao (spec phân quyền 2026-10-08 mục 4.2).
void main() {
  final now = DateTime(2026, 10, 8);
  Category dm(String ten, {String classify = 'chi', bool macDinh = false}) => Category(
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
        isLocalOnly: false,
        syncStatus: 'synced',
        syncRetryCount: 0,
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
}
