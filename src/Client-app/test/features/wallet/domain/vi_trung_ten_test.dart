/// G63 — định nghĩa duy nhất của "cặp trùng" và "bản ghi bị giữ" (spec 2026-10-05 mục 4.2, 4.4).
library;

import 'package:flowmoney/core/utils/gioi_han_do_dai.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/domain/vi_trung_ten.dart';
import 'package:flutter_test/flutter_test.dart';

ViXetTrung _v(String id, String ten, {bool co = false, bool xoa = false}) =>
    ViXetTrung(id: id, ten: ten, biTuChoi: co, daXoa: xoa);

void main() {
  group('capViTrungTen', () {
    test('⭐ ví bị từ chối + ví khác cùng tên chưa bị từ chối → một cặp R → P', () {
      expect(capViTrungTen([_v('p', 'Ví MB Bank'), _v('r', 'Ví MB Bank', co: true)]),
          [const CapViTrungTen(idViMayNay: 'r', idViDaDongBo: 'p')]);
    });

    test('⭐ cờ mà KHÔNG còn ví cùng tên → không giữ (cờ một mình không đủ — bẫy 2)', () {
      expect(capViTrungTen([_v('p', 'Ví MoMo'), _v('r', 'Ví MB Bank', co: true)]), isEmpty,
          reason: 'Máy kia đã đổi tên / xoá ví của nó: R phải quay lại hàng đợi, không bị giữ mãi.');
    });

    test('⭐ hai ví cùng tên mà KHÔNG ví nào bị từ chối → không giữ (bẫy 2, chiều kia)', () {
      expect(capViTrungTen([_v('a', 'Ví MB Bank'), _v('b', 'Ví MB Bank')]), isEmpty);
    });

    test('hai ví cùng tên CÙNG mang cờ → không giữ (ứng viên P phải chưa bị từ chối)', () {
      expect(capViTrungTen([_v('a', 'Ví MB Bank', co: true), _v('b', 'Ví MB Bank', co: true)]), isEmpty);
    });

    test('so tên qua chuanHoaTenVi — hoa thường, khoảng trắng', () {
      expect(capViTrungTen([_v('p', 'ví  mb bank '), _v('r', 'Ví MB Bank', co: true)]), hasLength(1));
    });

    test('ví đã xoá mềm không làm thành cặp', () {
      expect(capViTrungTen([_v('p', 'Ví MB Bank', xoa: true), _v('r', 'Ví MB Bank', co: true)]), isEmpty);
    });

    test('ví bị từ chối đã xoá mềm thì không bị giữ', () {
      expect(capViTrungTen([_v('p', 'Ví MB Bank'), _v('r', 'Ví MB Bank', co: true, xoa: true)]), isEmpty);
    });

    test('ví LƯU TRỮ vẫn làm thành cặp — index của server không nhìn Status', () {
      final p = WalletEntity(
          id: 'p', idaccount: 7, name: 'Ví MB Bank', type: 'bank', balance: 0, status: 'inactive',
          updatedAt: DateTime(2026, 10, 5));
      final r = WalletEntity(
          id: 'r', idaccount: 7, name: 'Ví MB Bank', type: 'bank', balance: 0, biTuChoiTrungTen: true,
          updatedAt: DateTime(2026, 10, 5));
      expect(capViTrungTen([ViXetTrung.tuEntity(p), ViXetTrung.tuEntity(r)]), hasLength(1));
    });

    test('nhiều ứng viên: trùng NGUYÊN VĂN trước, rồi id nhỏ hơn', () {
      final ds = [
        _v('p2', 'ví mb bank'),
        _v('p9', 'Ví MB Bank'),
        _v('p1', 'VÍ MB BANK'),
        _v('r', 'Ví MB Bank', co: true),
      ];
      expect(capViTrungTen(ds).single.idViDaDongBo, 'p9');
      final khongNguyenVan = [_v('p2', 'ví mb bank'), _v('p1', 'VÍ MB BANK'), _v('r', 'Ví MB Bank', co: true)];
      expect(capViTrungTen(khongNguyenVan).single.idViDaDongBo, 'p1');
    });

    test('idViBiGiu là tập R của mọi cặp', () {
      expect(idViBiGiu([_v('p', 'A'), _v('r', 'A', co: true), _v('q', 'B'), _v('s', 'B', co: true)]), {'r', 's'});
    });
  });

  group('banGhiBiGiu (bảng 4.4)', () {
    BanGhiBiGiu tinh({
      Set<String> vi = const {'R'},
      List<HoaDonChoXet> hd = const [],
      List<MucTieuChoXet> mt = const [],
      List<GiaoDichChoXet> gd = const [],
    }) =>
        banGhiBiGiu(viBiGiu: vi, hoaDon: hd, mucTieu: mt, giaoDich: gd);

    test('không ví nào bị giữ → rỗng', () {
      final g = tinh(vi: {}, gd: [(id: 't', walletId: 'R', viNhan: null, billId: null, goalId: null)]);
      expect(g.giaoDich, isEmpty);
      expect(g.vi, isEmpty);
    });

    test('hoá đơn: walletId bị giữ; kỳ sau nối từ hoá đơn bị giữ (chuỗi, lặp tới khi hết)', () {
      final g = tinh(hd: [
        (id: 'b3', walletId: 'P', truocDo: 'b2'),
        (id: 'b2', walletId: 'P', truocDo: 'b1'),
        (id: 'b1', walletId: 'R', truocDo: null),
        (id: 'bX', walletId: 'P', truocDo: null),
      ]);
      expect(g.hoaDon, {'b1', 'b2', 'b3'},
          reason: 'fk_bill_previous_bill: kỳ sau lên trước kỳ trước là vỡ khoá ngoại.');
    });

    test('mục tiêu: ví nhận HOẶC ví nguồn trích là ví bị giữ', () {
      final g = tinh(mt: [
        (id: 'g1', walletId: 'R', viNguonTrich: null),
        (id: 'g2', walletId: 'P', viNguonTrich: 'R'),
        (id: 'g3', walletId: 'P', viNguonTrich: 'Q'),
      ]);
      expect(g.mucTieu, {'g1', 'g2'});
    });

    test('giao dịch: ví nguồn · ví nhận · hoá đơn bị giữ · mục tiêu bị giữ', () {
      final g = tinh(
        hd: [(id: 'b1', walletId: 'R', truocDo: null)],
        mt: [(id: 'g1', walletId: 'R', viNguonTrich: null)],
        gd: [
          (id: 't1', walletId: 'R', viNhan: null, billId: null, goalId: null),
          (id: 't2', walletId: 'P', viNhan: 'R', billId: null, goalId: null),
          (id: 't3', walletId: 'P', viNhan: null, billId: 'b1', goalId: null),
          (id: 't4', walletId: 'P', viNhan: null, billId: null, goalId: 'g1'),
          (id: 't5', walletId: 'P', viNhan: null, billId: null, goalId: null),
        ],
      );
      expect(g.giaoDich, {'t1', 't2', 't3', 't4'});
      expect(g.vi, {'R'});
    });
  });

  group('tenGoiYKhiTrung', () {
    test('⭐ "(2)", rồi số kế tiếp còn trống', () {
      expect(tenGoiYKhiTrung('Ví MB Bank', ['Ví MB Bank']), 'Ví MB Bank (2)');
      expect(tenGoiYKhiTrung('Ví MB Bank', ['Ví MB Bank', 'ví mb bank (2)']), 'Ví MB Bank (3)');
    });

    test('tên quá dài thì cắt phần gốc để cả chuỗi vừa độ rộng cột', () {
      final dai = 'A' * 100;
      final goiY = tenGoiYKhiTrung(dai, [dai]);
      expect(goiY.runes.length, lessThanOrEqualTo(DoRongCot.tenVi));
      expect(goiY.endsWith(' (2)'), isTrue);
    });
  });

  group('loiTenViMoi', () {
    WalletEntity w(String id, String ten) =>
        WalletEntity(id: id, idaccount: 7, name: ten, type: 'bank', balance: 0, updatedAt: DateTime(2026, 10, 5));

    test('rỗng → lỗi', () => expect(loiTenViMoi('   ', [w('p', 'Ví MB Bank')], boQuaId: 'r'), isNotNull));
    test('⭐ trùng ví khác (kể cả khác hoa thường) → lỗi', () {
      expect(loiTenViMoi('ví mb bank', [w('p', 'Ví MB Bank'), w('r', 'Ví MB Bank')], boQuaId: 'r'), isNotNull);
    });
    test('tên mới không trùng → null', () {
      expect(loiTenViMoi('Ví MB Bank (2)', [w('p', 'Ví MB Bank'), w('r', 'Ví MB Bank')], boQuaId: 'r'), isNull);
    });
  });
}
