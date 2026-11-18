import 'package:flowmoney/features/transaction/data/vi_chung_cho_form_nguon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/them_giao_dich_nguon_gia.dart';

void main() {
  test('hàm nạp ném → null (form mở như không có nhà, không đỏ màn)', () async {
    final c = ViChungChoFormNguon(() async => throw StateError('kho hỏng'));
    expect(await c.nap(), isNull);
  });

  test('trả nguyên kết quả hàm nạp', () async {
    final nhom = NhomViChung(
      idNha: 7,
      tenNha: 'Nhà An Bình',
      vi: const [],
      nguon: NguonThemGiaoDichGia(),
      conDuocGhi: () => true,
      duongChonDanhMuc: '/add/nha-category',
    );
    final c = ViChungChoFormNguon(() async => nhom);
    expect(await c.nap(), same(nhom));
  });
}
