/// Nhắc ghi sau khi dùng app ngân hàng — hàm thuần (spec `2026-10-03-nhac-ghi-sau-app-ngan-hang-design.md` §4).
///
/// Ba điều đáng canh, cả ba hỏng im lặng:
/// 1. **Gộp phiên đúng biên 3 phút** — lệch là một lần chuyển tiền có chia sẻ biên lai (rời app vài giây) thành hai
///    phiên, phiên sau không có bằng chứng → nhắc oan.
/// 2. **Hai activity đổi chỗ cùng mili giây** (đo Realme 02/10: `PAUSED MainActivity` + `RESUMED …AuthenSession`) không
///    được cắt phiên — theo LỚP, không theo gói.
/// 3. **Bằng chứng đúng mép cửa sổ** và **chuyển khoản tự ghi là bằng chứng**.
library;

import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/core/notification/phien_ngan_hang.dart';
import 'package:flowmoney/features/transaction/domain/dien_san_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

const _mb = 'com.mbmobile';
const _momo = 'com.mservice.momotransfer';
const _main = 'io.flutter.plugins.MainActivity';
const _ekyc = 'com.singalarity.ekyc.activity.SingalarityAuthenSessionActivity';

DateTime _t(int h, int m, [int s = 0]) => DateTime(2026, 10, 3, h, m, s);
SuKienSuDung _vao(DateTime luc, {String goi = _mb, String lop = _main}) =>
    SuKienSuDung(goi: goi, lop: lop, vao: true, luc: luc);
SuKienSuDung _ra(DateTime luc, {String goi = _mb, String lop = _main}) =>
    SuKienSuDung(goi: goi, lop: lop, vao: false, luc: luc);
String? _nguon(String goi) => const {_mb: 'MB Bank', _momo: 'MoMo'}[goi];

void main() {
  group('phienTuSuKien', () {
    test('một lần vào – ra → một phiên đúng giờ mở, giờ rời, thời gian trên màn', () {
      final p = phienTuSuKien([_vao(_t(11, 19)), _ra(_t(11, 20, 35))], bayGio: _t(12, 0)).single;
      expect((p.goi, p.batDau, p.ketThuc, p.trenMan, p.dangMo),
          (_mb, _t(11, 19), _t(11, 20, 35), const Duration(seconds: 95), false));
    });

    test('⭐ quay lại trong 3 phút → CÙNG phiên; trên màn = tổng các khoảng, không tính khe', () {
      final ds = phienTuSuKien([
        _vao(_t(19, 37, 32)), _ra(_t(19, 39, 11)), // 99 s
        _vao(_t(19, 41, 28)), _ra(_t(19, 42, 44)), // khe 2:17 · 76 s
      ], bayGio: _t(20, 0));
      expect(ds, hasLength(1),
          reason: 'đo Realme 02/10: rời MB để chia sẻ biên lai rồi quay lại — tách đôi là phiên sau bị nhắc oan');
      expect((ds.single.batDau, ds.single.ketThuc, ds.single.trenMan),
          (_t(19, 37, 32), _t(19, 42, 44), const Duration(seconds: 175)));
    });

    test('khe ĐÚNG 3 phút → vẫn cùng phiên; 3 phút 1 giây → hai phiên', () {
      expect(phienTuSuKien([_vao(_t(10, 0)), _ra(_t(10, 1)), _vao(_t(10, 4)), _ra(_t(10, 5))], bayGio: _t(11, 0)),
          hasLength(1));
      expect(phienTuSuKien([_vao(_t(10, 0)), _ra(_t(10, 1)), _vao(_t(10, 4, 1)), _ra(_t(10, 5))], bayGio: _t(11, 0)),
          hasLength(2));
    });

    test('⭐ hai lớp đổi chỗ cùng mili giây — thứ tự nào cũng là một khoảng liền', () {
      final t0 = _t(18, 30, 10), t1 = _t(18, 30, 29), t2 = _t(18, 30, 51);
      for (final thuTu in [
        [_vao(t0), _ra(t1), _vao(t1, lop: _ekyc), _ra(t2, lop: _ekyc)],
        [_vao(t0), _vao(t1, lop: _ekyc), _ra(t1), _ra(t2, lop: _ekyc)],
      ]) {
        final p = phienTuSuKien(thuTu, bayGio: _t(19, 0)).single;
        expect((p.batDau, p.ketThuc, p.trenMan), (t0, t2, t2.difference(t0)));
      }
    });

    test('sự kiện rời lẻ (không có vào trước, vd. vào trước mốc truy vấn) bị bỏ', () {
      final p = phienTuSuKien([_ra(_t(9, 0)), _vao(_t(10, 0)), _ra(_t(10, 1))], bayGio: _t(11, 0)).single;
      expect(p.batDau, _t(10, 0));
    });

    test('khoảng cuối chưa rời → phiên ĐANG MỞ, ketThuc = bây giờ, chưa kết thúc', () {
      final p = phienTuSuKien([_vao(_t(11, 59))], bayGio: _t(12, 0)).single;
      expect((p.dangMo, p.ketThuc, p.trenMan), (true, _t(12, 0), const Duration(minutes: 1)));
      expect(p.daKetThuc(_t(12, 10)), isFalse);
    });

    test('sự kiện sau bây giờ bị bỏ (đồng hồ máy bị chỉnh)', () {
      final ds = phienTuSuKien([_vao(_t(10, 0)), _ra(_t(10, 1)), _vao(_t(13, 0))], bayGio: _t(12, 0));
      expect(ds.single.dangMo, isFalse);
    });

    test('hai gói xen nhau → phiên riêng từng gói, sắp theo giờ mở; đầu vào lộn thứ tự vẫn ra như nhau', () {
      final ev = [
        _vao(_t(10, 0)), _ra(_t(10, 1)),
        _vao(_t(10, 2), goi: _momo), _ra(_t(10, 3), goi: _momo),
        _vao(_t(10, 10)), _ra(_t(10, 11)),
      ];
      for (final dauVao in [ev, ev.reversed.toList()]) {
        final ds = phienTuSuKien(dauVao, bayGio: _t(11, 0));
        expect([for (final p in ds) (p.goi, p.batDau)],
            [(_mb, _t(10, 0)), (_momo, _t(10, 2)), (_mb, _t(10, 10))]);
      }
    });
  });

  group('daKetThuc / phienCanXet / mocSauKhiXet', () {
    final p = PhienNganHang(goi: _mb, batDau: _t(11, 19), ketThuc: _t(11, 20), trenMan: const Duration(seconds: 60));

    test('rời chưa đủ 3 phút → chưa kết thúc; đủ 3 phút → kết thúc', () {
      expect(p.daKetThuc(_t(11, 22, 59)), isFalse);
      expect(p.daKetThuc(_t(11, 23)), isTrue);
    });

    test('chỉ phiên đã kết thúc và mở SAU mốc', () {
      expect(phienCanXet([p], bayGio: _t(12, 0), moc: _t(11, 18)), [p]);
      expect(phienCanXet([p], bayGio: _t(12, 0), moc: _t(11, 19)), isEmpty, reason: 'mở đúng mốc = đã xét');
      expect(phienCanXet([p], bayGio: _t(11, 22), moc: _t(11, 0)), isEmpty, reason: 'chưa kết thúc');
      final mo = PhienNganHang(
          goi: _mb, batDau: _t(11, 30), ketThuc: _t(12, 0), trenMan: const Duration(minutes: 30), dangMo: true);
      expect(phienCanXet([mo], bayGio: _t(12, 0), moc: _t(11, 0)), isEmpty);
    });

    test('mốc mới = giờ rời lớn nhất; không có gì để xét → null', () {
      final q = PhienNganHang(goi: _momo, batDau: _t(10, 0), ketThuc: _t(10, 5), trenMan: const Duration(minutes: 5));
      expect(mocSauKhiXet(const []), isNull);
      expect(mocSauKhiXet([p, q]), _t(11, 20));
    });
  });

  group('phienCanNhac', () {
    PhienNganHang phien({Duration tren = const Duration(seconds: 95), String goi = _mb}) =>
        PhienNganHang(goi: goi, batDau: _t(11, 19), ketThuc: _t(11, 20, 44), trenMan: tren);
    List<PhienNganHang> nhac(List<PhienNganHang> xet,
            {List<BangChungTin> tin = const [],
            List<BangChungGiaoDich> gd = const [],
            Map<String, String?> vi = const {}}) =>
        phienCanNhac(xet, nguonCuaGoi: _nguon, tin: tin, giaoDich: gd, viCuaNguon: vi);

    test('⭐ phiên 95 giây không bằng chứng → nhắc (phiên 11:19 sáng 03/10 — không cách nào phân biệt với xem số dư)',
        () {
      final p = phien();
      expect(nhac([p]), [p]);
    });

    test('dưới 20 giây → không nhắc; đúng 20 giây → nhắc', () {
      expect(nhac([phien(tren: const Duration(seconds: 19))]), isEmpty);
      final p20 = phien(tren: const Duration(seconds: 20));
      expect(nhac([p20]), [p20]);
    });

    test('gói ngoài danh sách → không nhắc', () {
      expect(nhac([phien(goi: 'com.khac')]), isEmpty);
    });

    test('⭐ tin / biên lai CÙNG nguồn trong [mở − 2 phút, rời + 10 phút] → không nhắc; ngoài cửa sổ / khác nguồn → nhắc',
        () {
      final p = phien();
      BangChungTin tin(DateTime luc, [String nguon = 'MB Bank']) => (nguon: nguon, luc: luc);
      expect(nhac([p], tin: [tin(_t(11, 17))]), isEmpty, reason: 'mép trước, tính');
      expect(nhac([p], tin: [tin(_t(11, 16, 59))]), [p]);
      expect(nhac([p], tin: [tin(_t(11, 30, 44))]), isEmpty, reason: 'mép sau, tính');
      expect(nhac([p], tin: [tin(_t(11, 30, 45))]), [p]);
      expect(nhac([p], tin: [tin(_t(11, 19, 30), 'MoMo')]), [p], reason: 'tin của nguồn khác không che phiên MB');
    });

    test('⭐ giao dịch trong [mở − 2 phút, rời + 30 phút] → không nhắc; 30 phút 1 giây → nhắc', () {
      final p = phien();
      BangChungGiaoDich gd(DateTime ngay) => (ngay: ngay, walletId: 'w', walletTransfer: null);
      expect(nhac([p], gd: [gd(_t(11, 17))]), isEmpty);
      expect(nhac([p], gd: [gd(_t(11, 50, 44))]), isEmpty);
      expect(nhac([p], gd: [gd(_t(11, 50, 45))]), [p]);
    });

    test('⭐ đã biết ví của nguồn → chỉ giao dịch dính ví ấy; chuyển khoản tự ghi (ví đến) là bằng chứng', () {
      final p = phien();
      const vi = {'MB Bank': 'w-mb'};
      expect(nhac([p], vi: vi, gd: [(ngay: _t(11, 21), walletId: 'w-tm', walletTransfer: null)]), [p],
          reason: 'mua cà phê bằng tiền mặt lúc ấy không phải giao dịch của MB');
      expect(nhac([p], vi: vi, gd: [(ngay: _t(11, 21), walletId: 'w-mb', walletTransfer: null)]), isEmpty);
      expect(nhac([p], vi: vi, gd: [(ngay: _t(11, 21), walletId: 'w-momo', walletTransfer: 'w-mb')]), isEmpty,
          reason: 'chuyển khoản người dùng tự ghi — đúng thứ hay đi sau một phiên ngân hàng');
    });
  });

  group('docSuKien', () {
    test('đúng bốn khoá → sự kiện', () {
      final e = docSuKien({'goi': _mb, 'lop': _main, 'loai': 'vao', 'luc': _t(11, 19).millisecondsSinceEpoch})!;
      expect((e.goi, e.lop, e.vao, e.luc), (_mb, _main, true, _t(11, 19)));
      expect(docSuKien({'goi': _mb, 'lop': _main, 'loai': 'ra', 'luc': 1})!.vao, isFalse);
    });

    test('sai hình dạng → null, không ném', () {
      for (final hong in <Object?>[
        null,
        'x',
        <String, Object?>{},
        {'goi': _mb, 'lop': _main, 'loai': 'len', 'luc': 1},
        {'goi': '', 'lop': _main, 'loai': 'vao', 'luc': 1},
        {'goi': _mb, 'lop': _main, 'loai': 'vao', 'luc': '1'},
        {'goi': _mb, 'loai': 'vao', 'luc': 1},
      ]) {
        expect(docSuKien(hong), isNull, reason: '$hong');
      }
    });
  });

  group('khoá, deeplink, tiêu đề', () {
    final p = PhienNganHang(
        goi: _mb, batDau: _t(11, 19), ketThuc: _t(11, 20, 44), trenMan: const Duration(seconds: 95));

    test('khoá mang tiền tố bienDong:phien| và PHÚT mở; bắt đầu bằng bienDong: để form xoá cứng được', () {
      final k = dedupeKeyPhien('MB Bank', _t(11, 19, 30));
      expect(k, 'bienDong:phien|MB Bank|2026-10-03T11:19');
      expect(k.startsWith(kTienToKhoaBienDong), isTrue);
      expect(laKhoaPhien(k), isTrue);
      expect(laKhoaPhien('bienDong:M1'), isFalse);
      expect(laKhoaPhien('bienDong:bienLai|aaaa.jpg'), isFalse);
    });

    test('deeplink mở /add với giờ mở, nguồn, giờ rời, khoá; KHÔNG amount → không vào phép gộp trùng D1', () {
      final k = dedupeKeyPhien('MB Bank', p.batDau);
      final link = deeplinkPhien(p, nguon: 'MB Bank', dedupeKey: k);
      final u = Uri.parse(link);
      expect(u.path, '/add');
      expect(u.queryParameters, {
        'date': '2026-10-03T11:19:00.000',
        'nguon': 'MB Bank',
        'phien': '2026-10-03T11:20:44.000',
        'khoa': k,
      });
      expect(dauTuDeeplink(link, maGiaoDich: null), isNull);
    });

    test('tiêu đề: cùng phút một mốc; khác phút hai mốc', () {
      expect(tieuDePhien('MB Bank', _t(11, 19, 2), _t(11, 19, 40)), 'MB Bank · 11:19');
      expect(tieuDePhien('MB Bank', _t(11, 19), _t(11, 20, 44)), 'MB Bank · 11:19 – 11:20');
    });
  });
}
