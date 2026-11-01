/// `docCapGopQuy`: nửa RIÊNG của khoản góp / rút nhận ra cặp của nó ở màn cá nhân (đợt 1B Task 9).
///
/// Vì sao cần: Sổ giao dịch và Chi tiết ngân sách sửa, xoá từng hàng. Nửa riêng sửa / xoá một mình thì hai nửa lệch nhau
/// (quỹ một số, ví riêng một số khác), nên chỗ này phải nhận ra "còn cặp, còn đúng nhà" để dẫn người dùng sang đường đi
/// theo cả cặp. Đã rời nhà thì nửa riêng là khoản thường (`02A` mục 6).
library;

import 'package:flowmoney/features/household/application/doc_cap_gop_quy.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flowmoney/features/household/domain/vai_nha.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

NhaCuaToi _nha({int id = 5, VaiNha vai = VaiNha.chu, TrangThaiNha trangThai = TrangThaiNha.hoatDong}) => NhaCuaToi(
      nha: NhaEntity(id: id, ten: 'Nhà', trangThai: trangThai, toiDaThanhVien: 6),
      vai: vai,
      thanhVien: const [],
      nhanLuc: DateTime(2026, 11, 1),
    );

TransactionEntity _t({
  required String id,
  required String type,
  String walletId = 'w-rieng',
  String? fundPairId = 'cap-1',
  int? idhousehold,
  double amount = 200000,
}) =>
    TransactionEntity(
      id: id,
      walletId: walletId,
      idaccount: 7,
      fundPairId: fundPairId,
      idhousehold: idhousehold,
      amount: amount,
      type: type,
      date: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  final nuaRieng = _t(id: 'r', type: 'chi');
  final nuaNha = _t(id: 'n', type: 'thu', walletId: 'w-chung', idhousehold: 5);

  Future<({TransactionEntity? rieng, TransactionEntity? nha})> Function(String) capCo({
    TransactionEntity? rieng,
    TransactionEntity? nha,
  }) =>
      (_) async => (rieng: rieng, nha: nha);

  Future<String?> tenVi(String id) async => id == 'w-chung' ? 'Quỹ chợ' : 'Ví MB';

  test('nửa riêng còn nửa nhà và còn ở đúng nhà: có cặp, đủ mã, chiều và câu xoá', () async {
    final cap = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => _nha(id: 5),
      tenVi: tenVi,
    );
    expect(cap, isNotNull, reason: 'Còn nửa nhà ở đúng nhà đang ở thì phải nhận ra cặp, không để sửa lệch cặp.');
    expect(cap!.maCap, 'cap-1');
    expect(cap.laGop, isTrue, reason: 'Nửa riêng là chi: góp (rút thì nửa riêng là thu).');
    expect(cap.choThaoTac, isTrue);
    expect(cap.cauXoa, contains('Quỹ chợ'), reason: 'Câu hộp nêu tên quỹ.');
    expect(cap.cauXoa, contains('Ví MB'), reason: 'Máy người ghi có nửa riêng: câu nêu ví riêng được trả tiền về.');
  });

  test('nửa riêng của khoản rút: laGop = false', () async {
    final rut = _t(id: 'r', type: 'thu');
    final nhaChi = _t(id: 'n', type: 'chi', walletId: 'w-chung', idhousehold: 5);
    final cap = await docCapGopQuy(
      rut,
      docCap: capCo(rieng: rut, nha: nhaChi),
      nhaHienTai: () => _nha(),
      tenVi: tenVi,
    );
    expect(cap?.laGop, isFalse);
  });

  test('đã rời nhà (không còn nửa nhà): khoản thường', () async {
    final cap = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng),
      nhaHienTai: () => _nha(),
      tenVi: tenVi,
    );
    expect(cap, isNull, reason: 'Sau khi rời nhà nửa riêng là khoản thường (02A mục 6): sửa, xoá như mọi khoản.');
  });

  test('nửa nhà thuộc nhà khác nhà đang ở: khoản thường', () async {
    final cap = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => _nha(id: 99),
      tenVi: tenVi,
    );
    expect(cap, isNull, reason: 'Đổi sang nhà khác thì cặp cũ không còn là của nhà đang ở.');
  });

  test('không còn ở nhà nào: khoản thường', () async {
    final cap = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => NhaCuaToi.khongCo(DateTime(2026, 11, 1)),
      tenVi: tenVi,
    );
    expect(cap, isNull);
  });

  test('khoản thường (không mã cặp) và nửa của nhà: null, không đọc cặp', () async {
    var daDoc = false;
    Future<({TransactionEntity? rieng, TransactionEntity? nha})> doc(String _) async {
      daDoc = true;
      return (rieng: null, nha: null);
    }

    expect(await docCapGopQuy(_t(id: 'x', type: 'chi', fundPairId: null), docCap: doc, nhaHienTai: () => _nha(), tenVi: tenVi),
        isNull);
    expect(await docCapGopQuy(nuaNha, docCap: doc, nhaHienTai: () => _nha(), tenVi: tenVi), isNull,
        reason: 'Nửa của nhà đã có đường riêng (Hoạt động); cổng chỉ dành cho nửa riêng.');
    expect(daDoc, isFalse, reason: 'Khoản không thuộc diện thì không đọc kho.');
  });

  test('nhà chỉ xem (Chỉ xem, hoặc chủ hết Premium): choThaoTac = false', () async {
    final chiXem = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => _nha(vai: VaiNha.chiXem),
      tenVi: tenVi,
    );
    expect(chiXem?.choThaoTac, isFalse, reason: 'Server từ chối nửa nhà của nhà chỉ xem, nên nửa riêng cũng khoá.');
    final nhaChiXem = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => _nha(trangThai: TrangThaiNha.chiXem),
      tenVi: tenVi,
    );
    expect(nhaChiXem?.choThaoTac, isFalse);
  });

  test('FINAL I-1b: đọc TÊN ví ném — vẫn trả cặp với câu chung (nuốt thành null là xoá một nửa, lệch cặp)', () async {
    final cap = await docCapGopQuy(
      nuaRieng,
      docCap: capCo(rieng: nuaRieng, nha: nuaNha),
      nhaHienTai: () => _nha(id: 5),
      tenVi: (_) async => throw StateError('đọc ví hỏng'),
    );
    expect(cap, isNotNull,
        reason: 'cặp ĐÃ xác nhận có; lỗi chỉ ở tên ví thì không được rơi về đường xoá một nửa');
    expect(cap!.maCap, 'cap-1');
    expect(cap.cauXoa, contains('Quỹ ví chung'), reason: 'tên quỹ rơi về câu chung');
    expect(cap.cauXoa, isNot(contains('Ví MB')));
  });

  test('đọc cặp ném: ném tiếp để cổng nuốt thành null (CapGopQuyNguon.cua), không bịa ra một cặp', () async {
    await expectLater(
      docCapGopQuy(
        nuaRieng,
        docCap: (_) async => throw StateError('kho hỏng'),
        nhaHienTai: () => _nha(),
        tenVi: tenVi,
      ),
      throwsStateError,
      reason: 'Hàm này không tự nuốt lỗi: cổng (cap_gop_quy_nguon_test) mới là chỗ biến lỗi đọc thành khoản thường.',
    );
  });
}
