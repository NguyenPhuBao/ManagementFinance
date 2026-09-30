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
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gói giả → nguồn: bảng thật (tên gói đo trên máy) là việc của Task 1 / Task 3.
String? _nguonGia(String goi) => switch (goi) {
      'goi.mb' => kNguonMb,
      'goi.bidv' => kNguonBidv,
      _ => null,
    };

TinBienDong _tin({double soTien = 1200000, String chieu = 'thu', DateTime? luc, String? ma, String nguon = kNguonMb}) =>
    TinBienDong(
      soTien: soTien,
      chieu: chieu,
      thoiGian: luc ?? DateTime(2026, 9, 2, 15, 33),
      noiDung: 'ND',
      nguon: nguon,
      duoiTaiKhoan: '999',
      maGiaoDich: ma,
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

String _mb({String dau = '+', String tien = '1,200,000', String gio = '15:33', String nd = 'Chuyen tien', String? ma}) =>
    'TK 25xxx999|GD: $dau${tien}VND 02/09/26 $gio |SD: 1,200,007VND|ND: $nd${ma == null ? '' : ' Ma GD $ma'}';

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
    test('có mã GD → bienDong:<mã>; không mã → bienDong:<nguồn>|<tiền>|<chiều>|<phút>', () {
      expect(dedupeKeyBienDong(_tin(ma: 'ACSP/ 9l191181')), 'bienDong:ACSP/ 9l191181');
      expect(dedupeKeyBienDong(_tin()), 'bienDong:MB Bank|1200000|thu|2026-09-02T15:33');
    });
    test('⭐ cùng mã → trùng; cùng tiền + chiều cách ≤ 5 phút → trùng; 6 phút / khác chiều → không', () {
      final a = dauBienDong(_tin(ma: 'M1'));
      expect(trungBienDong(a, dauBienDong(_tin(soTien: 5, chieu: 'chi', ma: 'M1'))), isTrue,
          reason: 'mã GD thắng mọi trường khác');
      final goc = dauBienDong(_tin(luc: DateTime(2026, 9, 2, 15, 33)));
      expect(trungBienDong(goc, dauBienDong(_tin(luc: DateTime(2026, 9, 2, 15, 38)))), isTrue);
      expect(trungBienDong(goc, dauBienDong(_tin(luc: DateTime(2026, 9, 2, 15, 28)))), isTrue, reason: 'hai chiều');
      expect(trungBienDong(goc, dauBienDong(_tin(luc: DateTime(2026, 9, 2, 15, 39)))), isFalse);
      expect(trungBienDong(goc, dauBienDong(_tin(chieu: 'chi'))), isFalse);
      expect(trungBienDong(goc, dauBienDong(_tin(soTien: 1200001))), isFalse);
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
    late NhapBienDong nhap;

    setUp(() async {
      tam = await Directory.systemTemp.createTemp('bien_dong_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      soLanHuyTomTat = 0;
      bat = true;
      nhap = NhapBienDong(
        thuMuc: () async => tam,
        dao: db.notificationDao,
        nguonCuaGoi: _nguonGia,
        batBienDong: (_) async => bat,
        huyTomTat: () async => soLanHuyTomTat++,
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
}
