/// D1 — nhập hàng chờ tin biến động số dư (spec `2026-09-28-d1-doc-bien-dong-so-du-design.md` §3.2):
/// Kotlin nối từng tin (đã lọc thô) vào `files/bien_dong_cho.jsonl`; khi app mở, bộ nhập đọc, gộp
/// trùng, ghi hàng `AppNotifications` loại `bienDongSoDu`, rồi XOÁ tệp — tin thô không nằm lại đĩa.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/notification/ten_tep_bien_lai.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gói giả → nguồn: bảng thật (tên gói đo trên máy) là việc của Task 1 / Task 3.
String? _nguonGia(String goi) => switch (goi) {
      'goi.mb' => kNguonMb,
      'goi.bidv' => kNguonBidv,
      'goi.momo' => kNguonMomo,
      _ => null,
    };

TinBienDong _tin(
        {double soTien = 1200000, String chieu = 'thu', DateTime? luc, String? ma, String nguon = kNguonMb, String? vt}) =>
    TinBienDong(
      soTien: soTien,
      chieu: chieu,
      thoiGian: luc ?? DateTime(2026, 9, 2, 15, 33),
      noiDung: 'ND',
      nguon: nguon,
      duoiTaiKhoan: '999',
      maGiaoDich: ma,
      vanTaySoDu: vt,
    );

/// Một dòng Kotlin ghi — `luc` là mili giây epoch (`StatusBarNotification.postTime`).
String _dong({String goi = 'goi.mb', String tieuDe = 'Thông báo biến động số dư', required String noiDung,
        DateTime? luc, String khoa = 'k1'}) =>
    jsonEncode({
      'goi': goi,
      'tieuDe': tieuDe,
      'noiDung': noiDung,
      'luc': (luc ?? DateTime(2026, 9, 2, 15, 34)).millisecondsSinceEpoch,
      'khoa': khoa,
    });

String _mb(
        {String dau = '+', String tien = '1,200,000', String gio = '15:33', String nd = 'Chuyen tien', String? ma,
        String sd = '1,200,007'}) =>
    'TK 25xxx999|GD: $dau${tien}VND 02/09/26 $gio |SD: ${sd}VND|ND: $nd${ma == null ? '' : ' Ma GD $ma'}';

void main() {
  group('dòng JSON của Kotlin', () {
    test('đọc đúng năm trường; luc là mili giây epoch', () {
      final r = docDongBienDong(_dong(noiDung: 'x', luc: DateTime(2026, 9, 2, 15, 34)))!;
      expect((r.goi, r.tieuDe, r.noiDung, r.khoa), ('goi.mb', 'Thông báo biến động số dư', 'x', 'k1'));
      expect(r.luc, DateTime(2026, 9, 2, 15, 34));
    });
    test('dòng hỏng / thiếu trường / luc không phải số → null, không ném', () {
      expect(docDongBienDong(''), isNull);
      expect(docDongBienDong('{rác'), isNull);
      expect(docDongBienDong('{"goi":"a","noiDung":"b"}'), isNull);
      expect(docDongBienDong('{"goi":"a","tieuDe":"","noiDung":"b","luc":"hôm qua","khoa":"k"}'), isNull);
      expect(docDongBienDong('{"goi":"","tieuDe":"","noiDung":"b","luc":1,"khoa":"k"}'), isNull);
    });
  });

  group('khoá trùng và phép gộp', () {
    test('có mã GD → bienDong:<mã>; không mã, không vân tay → bienDong:<nguồn>|<tiền>|<chiều>|<giây>', () {
      expect(dedupeKeyBienDong(_tin(ma: 'ACSP/ 9l191181')), 'bienDong:ACSP/ 9l191181');
      expect(dedupeKeyBienDong(_tin()), 'bienDong:MB Bank|1200000|thu|2026-09-02T15:33:00');
    });
    test('⭐ hai tin MoMo CÙNG PHÚT, cùng số tiền → hai khoá khác nhau (insertAllIfAbsent không bỏ hàng thứ hai)', () {
      final a = dedupeKeyBienDong(_tin(nguon: kNguonMomo, luc: DateTime(2026, 10, 5, 8, 48, 10)));
      final b = dedupeKeyBienDong(_tin(nguon: kNguonMomo, luc: DateTime(2026, 10, 5, 8, 48, 40)));
      expect(a, isNot(b));
    });
    test('deeplink mang khoá thông báo đã băm (kt) và dauTuDeeplink đọc ngược nguồn, khoá, loại hàng', () {
      final d = deeplinkBienDong(_tin(nguon: kNguonMomo), dedupeKey: 'k', khoaTin: '0|goi.momo|7|null|0');
      final kt = Uri.parse(d).queryParameters['kt'];
      expect(kt, isNotNull);
      expect(kt, isNot(contains('goi.momo')), reason: 'khoá thông báo được băm, không nằm trần trong CSDL');
      final dau = dauTuDeeplink(d, maGiaoDich: null)!;
      expect((dau.nguon, dau.khoaTin, dau.tuTin), (kNguonMomo, kt, true));
      final bienLai = dauTuDeeplink('$d&doc=chung', maGiaoDich: null)!;
      expect(bienLai.tuTin, isFalse, reason: '`doc` có mặt ⇔ số liệu của hàng đọc từ ẢNH biên lai');
    });
    test('⭐ cùng mã → trùng; HAI KÊNH cùng tiền + chiều cách ≤ 5 phút → trùng; 6 phút / khác chiều → không', () {
      final a = dauBienDong(_tin(ma: 'M1'));
      expect(trungBienDong(a, dauBienDong(_tin(soTien: 5, chieu: 'chi', ma: 'M1'))), isTrue,
          reason: 'mã GD thắng mọi trường khác');
      // Cửa sổ 5 phút là để gộp HAI KÊNH báo cùng một giao dịch (SMS + app) — nên bên kia là nguồn khác.
      final goc = dauBienDong(_tin(luc: DateTime(2026, 9, 2, 15, 33)));
      DauBienDong sms({DateTime? luc, String chieu = 'thu', double soTien = 1200000}) =>
          dauBienDong(_tin(nguon: kNguonSms, luc: luc, chieu: chieu, soTien: soTien));
      expect(trungBienDong(goc, sms(luc: DateTime(2026, 9, 2, 15, 38))), isTrue);
      expect(trungBienDong(goc, sms(luc: DateTime(2026, 9, 2, 15, 28))), isTrue, reason: 'hai chiều');
      expect(trungBienDong(goc, sms(luc: DateTime(2026, 9, 2, 15, 39))), isFalse);
      expect(trungBienDong(goc, sms(chieu: 'chi')), isFalse);
      expect(trungBienDong(goc, sms(soTien: 1200001)), isFalse);
    });
    test('⭐ hai TIN của CÙNG app, không mã, không số dư (MoMo) → hai giao dịch, trừ khi là cùng thông báo đăng lại',
        () {
      // Người dùng báo 2026-10-05: hai khoản MoMo đến liên tiếp, app chỉ bắt được một. Tin MoMo không mang mã GD
      // lẫn số dư, nên cửa sổ 5 phút (dành cho hai KÊNH) gộp hai lần nhận tiền cùng số tiền làm một.
      DauBienDong momo(DateTime luc, {String? khoa}) =>
          dauBienDong(_tin(nguon: kNguonMomo, luc: luc), khoaTin: khoa);
      final goc = momo(DateTime(2026, 10, 5, 8, 48, 10), khoa: 'k1');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 49, 30), khoa: 'k2')), isFalse,
          reason: 'hai thông báo khác nhau của cùng app cách 80 giây là hai giao dịch thật');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 48, 15), khoa: 'k2')), isFalse,
          reason: 'khoá thông báo khác nhau → hai thông báo → hai giao dịch, dù chỉ cách 5 giây');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 48, 14), khoa: 'k1')), isTrue,
          reason: 'cùng khoá trong vài giây = app đăng lại / cập nhật chính thông báo ấy');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 50, 10), khoa: 'k1')), isFalse,
          reason: 'app dùng lại một id thông báo cho mọi tin thì cùng khoá chưa đủ — cách 2 phút là giao dịch mới');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 48, 15))), isTrue,
          reason: 'hàng cũ không mang khoá → chỉ cửa sổ ngắn');
      expect(trungBienDong(goc, momo(DateTime(2026, 10, 5, 8, 49, 10))), isFalse);
    });
    test('⭐ hai TÀI KHOẢN khác nhau (MB Bank · MoMo) cùng tiền + chiều cách 90 giây → KHÔNG trùng; SMS / biên lai '
        'không rõ app vẫn gộp với tin ngân hàng', () {
      // Nghiệm thu OnePlus 2026-10-08: MoMo → MB 10.000 (MB báo +10.000 lúc 16:53), rồi MB → MoMo 10.000 (MoMo báo
      // nhận +10.000 lúc 16:54:40) — cửa sổ 5 phút của "hai kênh" gộp tin MoMo vào hàng MB, khoản vào MoMo MẤT.
      final mb = dauBienDong(_tin(soTien: 10000, luc: DateTime(2026, 10, 8, 16, 53)), khoaTin: 'k-mb');
      final momo =
          dauBienDong(_tin(soTien: 10000, nguon: kNguonMomo, luc: DateTime(2026, 10, 8, 16, 54, 40)), khoaTin: 'k-momo');
      expect(trungBienDong(mb, momo), isFalse);
      expect(trungBienDong(momo, mb), isFalse);
      final bienLaiMomo =
          dauBienDong(_tin(soTien: 10000, nguon: kNguonMomo, luc: DateTime(2026, 10, 8, 16, 54)), tuTin: false);
      expect(trungBienDong(mb, bienLaiMomo), isFalse, reason: 'biên lai của app MoMo không phải giao dịch của tài khoản MB');
      final sms = dauBienDong(_tin(soTien: 10000, nguon: kNguonSms, luc: DateTime(2026, 10, 8, 16, 55)));
      expect(trungBienDong(mb, sms), isTrue, reason: 'SMS là KÊNH, không chỉ một tài khoản — vẫn là hai kênh của một GD');
      final bienLaiChung =
          dauBienDong(_tin(soTien: 10000, nguon: kNguonBienLai, luc: DateTime(2026, 10, 8, 16, 54)), tuTin: false);
      expect(trungBienDong(mb, bienLaiChung), isTrue, reason: 'biên lai từ app không rõ — giữ cửa sổ ghép ảnh');
    });

    test('biên lai (không phải tin) so với tin cùng nguồn vẫn dùng cửa sổ 5 phút — để ghép ảnh vào hàng tin', () {
      final tin = dauBienDong(_tin(nguon: kNguonMomo, luc: DateTime(2026, 10, 5, 8, 48, 37)), khoaTin: 'k1');
      final bienLai = dauBienDong(_tin(nguon: kNguonMomo, luc: DateTime(2026, 10, 5, 8, 48)), tuTin: false);
      expect(trungBienDong(tin, bienLai), isTrue);
      expect(trungBienDong(bienLai, tin), isTrue);
    });
    test('⭐ vân tay số dư KHÁC nhau → không trùng dù cùng tiền + chiều cách 4 phút; cùng vân tay → trùng', () {
      final goc = dauBienDong(_tin(chieu: 'chi', luc: DateTime(2026, 9, 30, 19, 17), vt: 'aaa'));
      expect(trungBienDong(goc, dauBienDong(_tin(chieu: 'chi', luc: DateTime(2026, 9, 30, 19, 21), vt: 'bbb'))),
          isFalse,
          reason: 'đo Realme 2026-09-30: hai lần chuyển −10.000 đ thật, khoản 19:21 bị gộp vào 19:17 và MẤT');
      expect(trungBienDong(goc, dauBienDong(_tin(chieu: 'chi', luc: DateTime(2026, 9, 30, 19, 18), vt: 'aaa'))),
          isTrue, reason: 'cùng số dư sau GD = cùng giao dịch (SMS + app)');
      expect(
          trungBienDong(
              goc, dauBienDong(_tin(nguon: kNguonSms, chieu: 'chi', luc: DateTime(2026, 9, 30, 19, 19)))),
          isTrue,
          reason: 'một bên không có số dư (nguồn khác khuôn) → giữ luật cửa sổ 5 phút');
    });
    test('⭐ khoá không mã GD mang vân tay khi có → hai giao dịch CÙNG PHÚT khác số dư không đè nhau', () {
      final a = dedupeKeyBienDong(_tin(chieu: 'chi', vt: 'aaa'));
      final b = dedupeKeyBienDong(_tin(chieu: 'chi', vt: 'bbb'));
      expect(a, isNot(b), reason: 'cùng khoá thì insertAllIfAbsent bỏ hàng thứ hai, im lặng');
      expect(a, 'bienDong:MB Bank|1200000|chi|2026-09-02T15:33|aaa');
    });
    test('deeplink mang vân tay (vt) và dauTuDeeplink đọc ngược được — để so với tin mới', () {
      final d = deeplinkBienDong(_tin(vt: 'aaa'), dedupeKey: 'k');
      expect(Uri.parse(d).queryParameters['vt'], 'aaa');
      expect(dauTuDeeplink(d, maGiaoDich: null)!.vanTay, 'aaa');
    });
    test('deeplink mở /add với đủ ô điền sẵn và khoá để xoá hàng khi Lưu / Bỏ qua', () {
      final u = Uri.parse(deeplinkBienDong(_tin(ma: 'M1'), dedupeKey: 'bienDong:M1'));
      expect(u.path, '/add');
      expect(u.queryParameters, {
        'amount': '1200000',
        'huong': 'thu',
        'date': '2026-09-02T15:33:00.000',
        'note': 'ND',
        'nguon': kNguonMb,
        'duoi': '999',
        'khoa': 'bienDong:M1',
      });
    });
    test('hàng loại 20 đọc ngược được dấu hiệu từ deeplink + subjectId (để gộp với tin mới)', () {
      final t = _tin(ma: 'M1');
      final b = dauTuDeeplink(deeplinkBienDong(t, dedupeKey: 'bienDong:M1'), maGiaoDich: 'M1')!;
      expect((b.soTien, b.chieu, b.thoiGian, b.ma), (1200000.0, 'thu', DateTime(2026, 9, 2, 15, 33), 'M1'));
      expect(dauTuDeeplink('/bills', maGiaoDich: null), isNull);
    });
  });

  group('NhapBienDong', () {
    late Directory tam;
    late AppDatabase db;
    late int soLanHuyTomTat;
    late bool bat;
    late List<bool> datBatGoi;
    late NhapBienDong nhap;

    setUp(() async {
      tam = await Directory.systemTemp.createTemp('bien_dong_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      soLanHuyTomTat = 0;
      bat = true;
      datBatGoi = [];
      nhap = NhapBienDong(
        thuMuc: () async => tam,
        dao: db.notificationDao,
        nguonCuaGoi: _nguonGia,
        batBienDong: (_) async => bat,
        huyTomTat: () async => soLanHuyTomTat++,
        datBat: (b) async => datBatGoi.add(b),
        clock: () => DateTime(2026, 9, 2, 16),
      );
    });
    tearDown(() async {
      await db.close();
      await tam.delete(recursive: true);
    });

    File tep() => File('${tam.path}/$kTepBienDongCho');
    Future<void> ghiTep(List<String> dong) => tep().writeAsString(dong.join('\n'));
    Future<List<AppNotification>> hang() async =>
        [for (final h in await db.notificationDao.getAll(7)) if (h.kind == NotificationKind.bienDongSoDu.name) h];

    test('không có tệp → 0, không ném, không gọi huỷ tóm tắt', () async {
      expect(await nhap.nhap(7), 0);
      expect(soLanHuyTomTat, 0);
    });

    test('⭐ Task 6: mỗi lượt nhập ghi cờ Kotlin theo cờ của tài khoản ĐANG đăng nhập — kể cả khi chưa có tệp',
        () async {
      await nhap.nhap(7);
      bat = false;
      await nhap.nhap(8);
      expect(datBatGoi, [true, false],
          reason: 'cờ Kotlin gắn MÁY, docBienDong gắn TÀI KHOẢN: A bật rồi đăng xuất, B (chưa từng đồng ý) '
              'đăng nhập thì dịch vụ phải thôi đọc — nếu không B nhận thông báo tóm tắt cho tính năng '
              'B chưa đồng ý; và "chưa có tệp" là ca THƯỜNG nhất nên không được thoát trước bước này');
    });

    test('Task 6: tatDocMay() tắt cờ Kotlin (đăng xuất — không ai đăng nhập thì không ai đồng ý)', () async {
      await nhap.tatDocMay();
      expect(datBatGoi, [false]);
    });

    test('⭐ một tin MB Bank → một hàng loại 20 đúng title / body / deeplink / subjectId, tệp bị xoá, tóm tắt bị huỷ',
        () async {
      await ghiTep([_dong(noiDung: _mb(ma: 'ACSP/ 9l191181'))]);
      expect(await nhap.nhap(7), 1);
      final h = (await hang()).single;
      expect(h.title, '+1.200.000 đ · MB Bank');
      expect(h.body, 'Chuyen tien Ma GD ACSP/ 9l191181');
      expect(h.dedupeKey, 'bienDong:ACSP/ 9l191181');
      expect(h.subjectType, 'bienDong');
      expect(h.subjectId, 'ACSP/ 9l191181');
      expect(h.createdAt, DateTime(2026, 9, 2, 15, 33), reason: 'mốc của SỰ KIỆN (giờ trong tin), không phải mốc nhập');
      expect(Uri.parse(h.deeplink!).queryParameters['khoa'], 'bienDong:ACSP/ 9l191181');
      expect(tep().existsSync(), isFalse);
      expect(File('${tep().path}.dang_nhap').existsSync(), isFalse, reason: 'tin thô không nằm lại đĩa');
      expect(soLanHuyTomTat, 1);
    });

    test('⭐ hai dòng cùng mã GD → một hàng; cùng tiền + chiều cách 4 phút → một; cách 6 phút → hai', () async {
      await ghiTep([
        _dong(noiDung: _mb(ma: 'M1'), khoa: 'a'),
        _dong(noiDung: _mb(ma: 'M1', nd: 'Ban khac'), khoa: 'b'),
        _dong(noiDung: _mb(tien: '50,000', gio: '10:00'), khoa: 'c'),
        _dong(noiDung: _mb(tien: '50,000', gio: '10:04'), khoa: 'd'),
        _dong(noiDung: _mb(tien: '50,000', gio: '10:10'), khoa: 'e'),
      ]);
      expect(await nhap.nhap(7), 3);
      expect((await hang()).map((h) => h.title).toList(),
          everyElement(anyOf('+1.200.000 đ · MB Bank', '+50.000 đ · MB Bank')));
    });

    test('⭐ báo lỗi 2026-10-05: hai lần nhận 10.000 đ qua MoMo liên tiếp → HAI hàng, cả trong lô lẫn khác lượt',
        () async {
      String momo(DateTime luc, String khoa) => _dong(
          goi: 'goi.momo',
          tieuDe: 'Nhận chuyển khoản từ NGUYEN VAN A',
          noiDung: 'Số tiền 10.000 ₫ đã được chuyển vào Ví. Lời nhắn: "chuyen tien"',
          luc: luc,
          khoa: khoa);
      await ghiTep([momo(DateTime(2026, 9, 2, 15, 48, 10), '0|goi.momo|1|null|0'),
        momo(DateTime(2026, 9, 2, 15, 48, 40), '0|goi.momo|2|null|0')]);
      expect(await nhap.nhap(7), 2, reason: 'cùng tiền, cùng chiều, cùng phút — nhưng hai thông báo khác nhau');
      await ghiTep([momo(DateTime(2026, 9, 2, 15, 50), '0|goi.momo|3|null|0')]);
      expect(await nhap.nhap(7), 1, reason: 'khác lượt nhập: so với hàng đã có cũng không được gộp');
      await ghiTep([momo(DateTime(2026, 9, 2, 15, 50, 3), '0|goi.momo|3|null|0')]);
      expect(await nhap.nhap(7), 0, reason: 'cùng thông báo app đăng lại vài giây sau → một giao dịch');
      expect((await hang()).length, 3);
    });

    test('⭐ nghiệm thu OnePlus 2026-10-08: MB nhận 10.000 rồi MoMo nhận 10.000 sau 100 giây → HAI hàng', () async {
      await ghiTep([
        _dong(noiDung: _mb(tien: '10,000', gio: '15:53', nd: 'MOMO-CASHOUT', sd: '30,000'),
            luc: DateTime(2026, 9, 2, 15, 53), khoa: '0|goi.mb|1|null|0'),
        _dong(
            goi: 'goi.momo',
            tieuDe: 'Nhận chuyển khoản từ TRAN VAN B',
            noiDung: 'Số tiền 10.000 ₫ đã được chuyển vào Ví. Lời nhắn: "chuyen tien"',
            luc: DateTime(2026, 9, 2, 15, 54, 40),
            khoa: '0|goi.momo|7|null|0'),
      ]);
      expect(await nhap.nhap(7), 2, reason: 'hai tài khoản khác nhau — không bao giờ là một giao dịch');
      expect([for (final h in await hang()) h.title]..sort(), ['+10.000 đ · MB Bank', '+10.000 đ · MoMo']);
    });

    test('⭐ sự cố Realme 2026-09-30: hai lần chuyển −10.000 đ khác số dư → HAI hàng, cả trong lô lẫn khác lượt',
        () async {
      await ghiTep([
        _dong(noiDung: _mb(dau: '-', tien: '10,000', gio: '19:17', sd: '5,027,757'), khoa: 'a'),
        _dong(noiDung: _mb(dau: '-', tien: '10,000', gio: '19:21', sd: '5,017,757'), khoa: 'b'),
      ]);
      expect(await nhap.nhap(7), 2, reason: 'cùng lô');
      await ghiTep([_dong(noiDung: _mb(dau: '-', tien: '10,000', gio: '19:23', sd: '5,007,757'), khoa: 'c')]);
      expect(await nhap.nhap(7), 1, reason: 'khác lượt: so với hàng ĐÃ CÓ phải đọc được vân tay từ deeplink');
      await ghiTep([_dong(noiDung: _mb(dau: '-', tien: '10,000', gio: '19:23', sd: '5,007,757'), khoa: 'd')]);
      expect(await nhap.nhap(7), 0, reason: 'cùng tin bắn lại (cùng số dư) vẫn gộp');
      expect(await hang(), hasLength(3));
    });

    test('dòng hỏng, gói lạ, tin không khớp khuôn → bỏ; dòng lành vẫn nhập', () async {
      await ghiTep([
        'rác không phải json',
        _dong(goi: 'goi.la', noiDung: _mb(ma: 'X')),
        _dong(goi: 'goi.bidv', noiDung: 'Ưu đãi giảm 50,000 VND'),
        _dong(noiDung: _mb(ma: 'M9')),
      ]);
      expect(await nhap.nhap(7), 1);
      expect((await hang()).single.subjectId, 'M9');
    });

    test('⭐ trùng với hàng loại 20 ĐÃ CÓ → không thêm (nguồn bắn lại cùng tin)', () async {
      await ghiTep([_dong(noiDung: _mb(ma: 'M1'))]);
      expect(await nhap.nhap(7), 1);
      // Mỗi lượt MỘT dòng: hai dòng cùng lô thì phép gộp trong lô bắt được, ca không còn canh phép gộp
      // với hàng ĐÃ CÓ (bản sai bỏ `daCo` từng xanh ở đây).
      await ghiTep([_dong(noiDung: _mb(gio: '15:36'), khoa: 'lan2')]);
      expect(await nhap.nhap(7), 0, reason: 'không mã nhưng cùng tiền + chiều, cách 3 phút hàng đã có');
      await ghiTep([_dong(noiDung: _mb(ma: 'M1', nd: 'khac'), khoa: 'lan3')]);
      expect(await nhap.nhap(7), 0, reason: 'cùng mã GD với hàng đã có');
      expect(await hang(), hasLength(1));
    });

    test('tài khoản khác đăng nhập → tin vào tài khoản ĐANG đăng nhập (hàng chờ gắn máy, không gắn tài khoản)', () async {
      await ghiTep([_dong(noiDung: _mb(ma: 'M1'))]);
      expect(await nhap.nhap(8), 1);
      expect(await db.notificationDao.getAll(8), hasLength(1));
      expect(await db.notificationDao.getAll(7), isEmpty);
    });

    test('⭐ công tắc tắt → không nhập hàng nào, tệp vẫn bị xoá (tin thô không ở lại đĩa), tóm tắt bị huỷ', () async {
      bat = false;
      await ghiTep([_dong(noiDung: _mb(ma: 'M1'))]);
      expect(await nhap.nhap(7), 0);
      expect(await hang(), isEmpty);
      expect(tep().existsSync(), isFalse);
      expect(soLanHuyTomTat, 1);
    });

    test('dọn: hàng loại 20 cũ hơn 30 ngày bị xoá cứng, hàng loại khác cùng tuổi giữ nguyên', () async {
      final cu = DateTime(2026, 8, 1);
      await db.notificationDao.insertAllIfAbsent([
        AppNotificationsCompanion.insert(
            id: 'a', idaccount: 7, kind: NotificationKind.bienDongSoDu.name, dedupeKey: 'bienDong:a',
            title: 't', body: 'b', severity: 'info', createdAt: cu),
        AppNotificationsCompanion.insert(
            id: 'b', idaccount: 7, kind: NotificationKind.billDueSoon.name, dedupeKey: 'billDue:b',
            title: 't', body: 'b', severity: 'info', createdAt: cu),
      ]);
      await db.notificationDao.purgeKindOlderThan(NotificationKind.bienDongSoDu.name, DateTime(2026, 9, 1));
      expect((await db.notificationDao.getAll(7)).map((h) => h.id), ['b']);
    });
  });

  group('deeplink có ảnh biên lai (chia sẻ biên lai, 2026-10-02)', () {
    final t = _tin(soTien: 150000, chieu: 'chi', luc: DateTime(2026, 10, 2, 18, 45), ma: 'FT1');

    test('⭐ không truyền anh / cachDoc → query Y NHƯ TRƯỚC (hàng D1 không đổi một tham số nào)', () {
      final q = Uri.parse(deeplinkBienDong(t, dedupeKey: 'bienDong:FT1')).queryParameters;
      expect(q.keys.toSet(), {'amount', 'huong', 'date', 'note', 'nguon', 'duoi', 'khoa'});
    });

    test('có anh → thêm anh, doc và blt (giờ in trên biên lai)', () {
      final q = Uri.parse(deeplinkBienDong(t, dedupeKey: 'bienDong:FT1', anh: 'aaaa.jpg', cachDoc: 'mau'))
          .queryParameters;
      expect(q['anh'], 'aaaa.jpg');
      expect(q['doc'], 'mau');
      expect(DateTime.parse(q['blt']!), DateTime(2026, 10, 2, 18, 45));
    });

    test('anhTuDeeplink: đọc lại tên tệp; tên bẩn / không có / deeplink null → null', () {
      expect(anhTuDeeplink('/add?khoa=bienDong:x&anh=aaaa.jpg'), 'aaaa.jpg');
      expect(anhTuDeeplink('/add?khoa=bienDong:x&anh=..%2Fx.jpg'), isNull,
          reason: 'tên tệp sẽ được ghép thành đường dẫn — không nhận tên có dấu gạch chéo');
      expect(anhTuDeeplink('/add?khoa=bienDong:x'), isNull);
      expect(anhTuDeeplink(null), isNull);
    });

    test('⭐ themAnhVaoDeeplink giữ mọi tham số cũ của hàng tin, ghi giờ biên lai riêng (blt ≠ date)', () {
      final goc = deeplinkBienDong(_tin(luc: DateTime(2026, 10, 2, 18, 45, 20), vt: 'abc'), dedupeKey: 'bienDong:k');
      final moi = themAnhVaoDeeplink(goc, 'aaaa.jpg', DateTime(2026, 10, 2, 18, 45));
      final q = Uri.parse(moi).queryParameters;
      expect(q['amount'], '1200000');
      expect(q['vt'], 'abc');
      expect(q['khoa'], 'bienDong:k');
      expect(DateTime.parse(q['date']!), DateTime(2026, 10, 2, 18, 45, 20), reason: 'giờ của TIN không bị đè');
      expect(gioBienLaiTuDeeplink(moi), DateTime(2026, 10, 2, 18, 45));
      expect(gioBienLaiTuDeeplink(goc), isNull, reason: 'hàng chưa mang biên lai nào');
      expect(dauTuDeeplink(moi, maGiaoDich: null)!.vanTay, 'abc', reason: 'phép gộp trùng của D1 vẫn đọc được hàng đã gắn ảnh');
    });

    test('⭐ biên lai chưa đọc: không amount, không huong → dauTuDeeplink trả null (không gộp trùng với gì)', () {
      final link = deeplinkBienLaiChuaDoc(
          nguon: 'Biên lai', luc: DateTime(2026, 10, 2), noiDung: '', anh: 'aaaa.jpg', dedupeKey: 'bienDong:bienLai|aaaa.jpg');
      final q = Uri.parse(link).queryParameters;
      expect(q['doc'], 'khong');
      expect(q.containsKey('amount'), isFalse);
      expect(anhTuDeeplink(link), 'aaaa.jpg');
      expect(dauTuDeeplink(link, maGiaoDich: null), isNull);
    });
  });
}
