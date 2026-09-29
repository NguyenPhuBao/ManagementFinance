/// Tệp hàng chờ của nhật ký B5a: nút "Hoãn" chạy trong isolate nền không có
/// CSDL, nên nó nối một dòng JSON vào tệp; lần mở app sau bộ nhập đưa vào bảng —
/// CHỈ những dòng thuộc tài khoản đang đăng nhập.
///
/// ⚠️ Spike Realme 2026-09-29: trên Android nút Hoãn vào isolate nền KỂ CẢ khi app
/// còn sống, nên đây là đường của MỌI hàng `hoan` trên Android, không riêng lúc
/// app đóng.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/hang_cho_su_kien.dart';
import 'package:flowmoney/core/notification/nhat_ky_thong_bao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dòng JSON', () {
    test('dựng rồi đọc lại đúng khoá và lúc', () {
      final d = dongHangCho(dedupeKey: 'billDue:b1:2026-10-01:1', luc: DateTime(2026, 10, 1, 8, 5));
      final r = docDongHangCho(d);
      expect(r?.dedupeKey, 'billDue:b1:2026-10-01:1');
      expect(r?.luc, DateTime(2026, 10, 1, 8, 5));
      expect(d.contains('\n'), isFalse, reason: 'một sự kiện một dòng');
    });

    test('dòng hỏng / thiếu trường → null, không ném', () {
      expect(docDongHangCho(''), isNull);
      expect(docDongHangCho('{không phải json'), isNull);
      expect(docDongHangCho('{"k":"a"}'), isNull);
      expect(docDongHangCho('{"k":"a","t":"không phải ngày"}'), isNull);
      expect(docDongHangCho('{"k":"","t":"2026-10-01T08:00:00.000"}'), isNull);
    });
  });

  test('locHangCho: giữ dòng thuộc tài khoản, bỏ dòng không thuộc và dòng hỏng', () async {
    final dong = [
      dongHangCho(dedupeKey: 'cua-toi', luc: DateTime(2026, 10, 1)),
      dongHangCho(dedupeKey: 'nguoi-khac', luc: DateTime(2026, 10, 1)),
      'rác',
    ];
    final r = await locHangCho(dong, (k) async => k == 'cua-toi');
    expect(r.map((e) => e.dedupeKey), ['cua-toi']);
  });

  group('NhapHangCho', () {
    late Directory tam;
    late AppDatabase db;
    late NhapHangCho nhap;

    setUp(() async {
      tam = await Directory.systemTemp.createTemp('hang_cho_');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final nhatKy = NhatKyThongBao(dao: db.notificationEventDao, idaccountPhien: () => null);
      nhap = NhapHangCho(
        thuMuc: () async => tam,
        nhatKy: nhatKy,
        thuocTaiKhoan: (id, k) async => id == 7 && k.startsWith('billDue:'),
      );
    });
    tearDown(() async {
      await db.close();
      await tam.delete(recursive: true);
    });

    test('không có tệp → 0, không ném', () async {
      expect(await nhap.nhap(7), 0);
    });

    test('nhập dòng thuộc tài khoản thành hàng hoan với ĐÚNG lúc bấm, rồi xoá tệp', () async {
      await File('${tam.path}/$kTepHangCho').writeAsString([
        dongHangCho(dedupeKey: 'billDue:b1:2026-10-01:1', luc: DateTime(2026, 10, 1, 8, 5)),
        dongHangCho(dedupeKey: 'walletNeg:x', luc: DateTime(2026, 10, 1, 9)),
      ].join('\n'));
      expect(await nhap.nhap(7), 1);
      final r = await db.notificationEventDao.getAll(7);
      expect(r.single.suKien, 'hoan');
      expect(r.single.luc, DateTime(2026, 10, 1, 8, 5), reason: 'lúc BẤM, không phải lúc nhập');
      expect(File('${tam.path}/$kTepHangCho').existsSync(), isFalse);
      expect(File('${tam.path}/$kTepHangCho.dang_nhap').existsSync(), isFalse);
    });

    test('tài khoản khác đăng nhập → không nhập dòng nào, tệp vẫn bị dọn', () async {
      await File('${tam.path}/$kTepHangCho')
          .writeAsString(dongHangCho(dedupeKey: 'billDue:b1:2026-10-01:1', luc: DateTime(2026, 10, 1)));
      expect(await nhap.nhap(8), 0);
      expect(await db.notificationEventDao.getAll(8), isEmpty);
      expect(File('${tam.path}/$kTepHangCho').existsSync(), isFalse,
          reason: 'giữ lại là tài khoản cũ đăng nhập lại sẽ nhận sự kiện đã quá hạn');
    });
  });
}
