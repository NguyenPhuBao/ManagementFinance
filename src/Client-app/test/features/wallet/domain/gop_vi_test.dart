/// G63 — kế hoạch gộp ví, MỘT nguồn cho hộp xác nhận lẫn bước thi hành (spec mục 6.1, 6.3; bẫy 4, 5).
library;

import 'package:flowmoney/features/wallet/domain/gop_vi.dart';
import 'package:flowmoney/features/wallet/domain/so_du_mo_so.dart';
import 'package:flutter_test/flutter_test.dart';

const r = 'r';
const p = 'p';

GiaoDichChoGop _gd(String id, String loai, double tien, {String w = r, String? nhan}) =>
    (id: id, walletId: w, viNhan: nhan, loai: loai, soTien: tien);

KeHoachGop _kh({
  ViChoGop? bo,
  ViChoGop? giu,
  List<GiaoDichChoGop>? gd,
  List<HoaDonChoGop> hd = const [],
  List<MucTieuChoGop> mt = const [],
}) =>
    keHoachGop(
      viBo: bo ?? const ViChoGop(id: r, loai: 'bank', soDu: 1250000, tongSo: 1250000),
      viGiu: giu ?? const ViChoGop(id: p, loai: 'bank', soDu: 3400000, tongSo: 3400000),
      giaoDich: gd ??
          [
            _gd(idKhoanMoSo(r), 'thu', 1000000),
            _gd('tx1', 'thu', 500000),
            _gd('tx2', 'chi', 250000),
          ],
      hoaDon: hd,
      mucTieu: mt,
    );

void main() {
  test('⭐ ví dụ của spec: 3.400.000 + 1.250.000 − 1.000.000 = 3.650.000', () {
    final kh = _kh();
    expect(kh.soDuSauGop, 3650000);
    expect(kh.soDuBanDauBo, 1000000);
    expect(kh.idKhoanMoSoBo, idKhoanMoSo(r));
    expect(kh.giaoDichDoiVi, ['tx1', 'tx2'],
        reason: 'Khoản "Số dư ban đầu" KHÔNG chuyển sang — hai ví là một tài khoản thật, giữ hai số dư mở sổ là đếm đôi.');
  });

  test('⭐ khoản mở sổ tìm bằng ID tất định, KHÔNG bằng ghi chú (bẫy 5)', () {
    final kh = _kh(gd: [
      _gd('khong-phai-neo', 'thu', 1000000), // ghi chú có thể là "Số dư ban đầu" mà không phải neo
      _gd('tx1', 'thu', 500000),
    ]);
    expect(kh.idKhoanMoSoBo, isNull);
    expect(kh.giaoDichDoiVi, containsAll(['khong-phai-neo', 'tx1']));
  });

  test('khoản mở sổ ÂM (type chi) lấy đúng dấu', () {
    final kh = _kh(
      bo: const ViChoGop(id: r, loai: 'bank', soDu: -200000, tongSo: -200000),
      gd: [_gd(idKhoanMoSo(r), 'chi', 200000)],
    );
    expect(kh.soDuSauGop, 3400000 + (-200000) - (-200000));
    expect(kh.soDuBanDauBo, -200000);
  });

  test('khoản chuyển giữa hai ví (cả hai chiều) bị bỏ; chuyển từ ví thứ ba thì chuyển sang', () {
    final kh = _kh(gd: [
      _gd('p-sang-r', 'transfer', 100000, w: p, nhan: r),
      _gd('r-sang-p', 'transfer', 30000, w: r, nhan: p),
      _gd('x-sang-r', 'transfer', 50000, w: 'x', nhan: r),
    ]);
    expect(kh.khoanChuyenNoiBo, unorderedEquals(['p-sang-r', 'r-sang-p']));
    expect(kh.giaoDichDoiVi, ['x-sang-r']);
  });

  test('số dư ban đầu bị bỏ gồm cả phần số dư R chưa từng vào sổ', () {
    final kh = _kh(bo: const ViChoGop(id: r, loai: 'bank', soDu: 1300000, tongSo: 1250000));
    expect(kh.soDuBanDauBo, 1300000 - (1250000 - 1000000));
  });

  test('mục tiêu: đổi ví nhận, đổi ví nguồn, tắt trích khi nguồn trùng nhận', () {
    final kh = _kh(mt: const [
      (id: 'g1', ten: 'Du lịch', walletId: r, viNguonTrich: null),
      (id: 'g2', ten: 'Mua xe', walletId: p, viNguonTrich: r),
      (id: 'g3', ten: 'Học', walletId: 'y', viNguonTrich: r),
    ]);
    final theoId = {for (final m in kh.mucTieu) m.id: m};
    expect(theoId['g1']!.doiViNhan, isTrue);
    expect(theoId['g1']!.tatTrich, isFalse);
    expect(theoId['g2']!.tatTrich, isTrue, reason: 'Sau gộp ví nguồn = ví nhận = P — trích từ ví sang chính nó.');
    expect(theoId['g3']!.doiViNguon, isTrue);
    expect(theoId['g3']!.tatTrich, isFalse);
    expect(kh.tenMucTieuTatTrich, ['Mua xe']);
  });

  test('cờ mặc định: chuyển khi R mặc định; KHÔNG chuyển sang ví lưu trữ', () {
    expect(_kh(bo: const ViChoGop(id: r, loai: 'bank', soDu: 0, tongSo: 0, macDinh: true)).chuyenCoMacDinh, isTrue);
    expect(
        _kh(
          bo: const ViChoGop(id: r, loai: 'bank', soDu: 0, tongSo: 0, macDinh: true),
          giu: const ViChoGop(id: p, loai: 'bank', soDu: 0, tongSo: 0, luuTru: true),
        ).chuyenCoMacDinh,
        isFalse);
    expect(_kh().chuyenCoMacDinh, isFalse);
  });

  test('ví liên kết ngân hàng (cả hai phía) → không gộp được', () {
    expect(_kh(giu: const ViChoGop(id: p, loai: 'banking', soDu: 0, tongSo: 0)).coTheGop, isFalse);
    expect(_kh(bo: const ViChoGop(id: r, loai: 'banking', soDu: 0, tongSo: 0)).coTheGop, isFalse);
    expect(_kh().coTheGop, isTrue);
  });

  test('cungTapVoi: cùng tập id → true; thêm một giao dịch → false', () {
    final a = _kh();
    expect(a.cungTapVoi(_kh()), isTrue);
    final b = _kh(gd: [
      _gd(idKhoanMoSo(r), 'thu', 1000000),
      _gd('tx1', 'thu', 500000),
      _gd('tx2', 'chi', 250000),
      _gd('tx-moi', 'chi', 1000),
    ]);
    expect(a.cungTapVoi(b), isFalse);
  });

  group('cacDongXacNhanGop', () {
    test('⭐ in đúng các con số của chính kế hoạch (bẫy 4)', () {
      final kh = _kh(
        hd: const [(id: 'b1')],
        mt: const [(id: 'g2', ten: 'Mua xe', walletId: p, viNguonTrich: r)],
      );
      expect(cacDongXacNhanGop(kh), [
        'Chuyển 2 giao dịch, 1 hoá đơn, 1 mục tiêu sang ví đã đồng bộ.',
        'Bỏ số dư ban đầu 1.000.000 đ của ví trên máy này.',
        'Tắt trích tự động của mục tiêu Mua xe.',
        'Số dư sau gộp: 3.650.000 đ.',
        'Ví giữ lại: Ngân hàng.',
        'Không hoàn tác được.',
      ]);
    });

    test('không có gì để chuyển; ví giữ lại đang lưu trữ', () {
      final kh = _kh(
        bo: const ViChoGop(id: r, loai: 'bank', soDu: 0, tongSo: 0),
        giu: const ViChoGop(id: p, loai: 'cash', soDu: 500000, tongSo: 500000, luuTru: true),
        gd: const [],
      );
      expect(cacDongXacNhanGop(kh).first, 'Không có giao dịch nào cần chuyển.');
      expect(cacDongXacNhanGop(kh), contains('Ví giữ lại: Tiền mặt, đang lưu trữ.'));
    });
  });
}
