/// Chia sẻ biên lai — phần Dart của hàng chờ (spec `2026-10-02-chia-se-bien-lai-design.md`).
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/notification/kho_bien_lai.dart';
import 'package:flowmoney/core/notification/nhap_bien_dong.dart';
import 'package:flowmoney/core/notification/nhap_bien_lai.dart';
import 'package:flowmoney/core/notification/notification_rules.dart';
import 'package:flowmoney/core/ocr/doc_chu_anh.dart';
import 'package:flowmoney/core/ocr/dong_ocr.dart';
import 'package:flowmoney/features/transaction/domain/doc_tin_bien_dong.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bộ đọc chữ giả gọi một hàm ở lần đọc ĐẦU — để giả lập Kotlin ghi thêm biên lai giữa lượt nhập.
class _DocGoi implements DocChuAnh {
  _DocGoi(this.khiDoc);
  final void Function() khiDoc;
  var _lan = 0;

  @override
  Future<List<DongOcr>> doc(String duongDan) async {
    if (_lan++ == 0) khiDoc();
    return const [DongOcr('Số tiền 10.000 đ', trai: 0, tren: 0, phai: 9, duoi: 9)];
  }
}

/// Bộ đọc chữ giả: trả các dòng đã dựng sẵn theo TÊN TỆP ảnh.
class _DocGia implements DocChuAnh {
  _DocGia(this.theoTep, {this.nem = false});
  final Map<String, List<DongOcr>> theoTep;
  final bool nem;
  final daDoc = <String>[];

  @override
  Future<List<DongOcr>> doc(String duongDan) async {
    if (nem) throw StateError('bộ đọc hỏng /data/user/0/bien_lai/bi-mat.jpg');
    daDoc.add(duongDan);
    return theoTep[duongDan.split(RegExp(r'[\\/]')).last] ?? const [];
  }
}

DongOcr _d(String chu, double tren) => DongOcr(chu, trai: 0, tren: tren, phai: 100, duoi: tren + 10);

void main() {
  group('thuMauBienLai — chế độ thu mẫu, chỉ bản debug', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('bienlai_thu'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('⭐ in tên gói và HÌNH DẠNG ĐÃ CHE từng hàng — không chữ số thật, không tên riêng; KHÔNG xoá hàng chờ', () async {
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync('{"tep":"abcd.jpg","goi":"com.mbmobile","luc":1}\n');
      final ra = <String>[];
      final doc = _DocGia({
        'abcd.jpg': [_d('Số tiền 150.000 VND', 0), _d('Người nhận TRAN VAN B', 20)],
      });
      await thuMauBienLai(thuMuc: () async => dir, docChu: doc, inRa: ra.add);
      final tat = ra.join('\n');
      expect(doc.daDoc.single, endsWith('$kThuMucBienLai/abcd.jpg'));
      expect(tat, contains('com.mbmobile'));
      expect(tat, contains('Số tiền 999.999 VND'));
      expect(tat, isNot(contains('150')), reason: '§13.6: con số thật không bao giờ ra log');
      expect(tat, isNot(contains('TRAN')));
      expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isTrue, reason: 'thu mẫu chỉ ĐỌC — nhập là việc khác');
    });

    test('không có hàng chờ → không in gì, không gọi bộ đọc', () async {
      final ra = <String>[];
      final doc = _DocGia({});
      await thuMauBienLai(thuMuc: () async => dir, docChu: doc, inRa: ra.add);
      expect(ra, isEmpty);
      expect(doc.daDoc, isEmpty);
    });

    test('bộ đọc ném → MỘT dòng báo hỏng chỉ mang kiểu lỗi (thông báo lỗi có thể chứa đường dẫn), không ném ra ngoài',
        () async {
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync('{"tep":"abcd.jpg","goi":"","luc":1}\n');
      final ra = <String>[];
      await thuMauBienLai(thuMuc: () async => dir, docChu: _DocGia({}, nem: true), inRa: ra.add);
      expect(ra.single, contains('hỏng'));
      expect(ra.single, isNot(contains('bi-mat')));
    });
  });

  group('docDongBienLai', () {
    test('dòng đúng → tep, goi, luc', () {
      final r = docDongBienLai('{"tep":"a1b2.jpg","goi":"com.mbmobile","luc":1790940000000}');
      expect(r, isNotNull);
      expect(r!.tep, 'a1b2.jpg');
      expect(r.goi, 'com.mbmobile');
      expect(r.luc, DateTime.fromMillisecondsSinceEpoch(1790940000000));
    });

    test('goi rỗng vẫn nhận (không lấy được app gửi)', () {
      expect(docDongBienLai('{"tep":"abcd.png","goi":"","luc":1}')!.goi, '');
    });

    test('tên tệp Kotlin đặt (UUID + đuôi) hợp lệ', () {
      expect(tenTepBienLaiHopLe('3f2b8c1e-7a4d-4e0b-9c2a-1d5e6f7a8b9c.jpg'), isTrue);
      expect(tenTepBienLaiHopLe('0f3a-9c.jpeg'), isTrue);
    });

    test('⭐ tên tệp có dấu gạch chéo / .. bị từ chối — tên tệp đi vào deeplink rồi thành đường dẫn', () {
      expect(docDongBienLai('{"tep":"../x.jpg","goi":"","luc":1}'), isNull);
      expect(docDongBienLai('{"tep":"a/b.jpg","goi":"","luc":1}'), isNull);
      expect(docDongBienLai(r'{"tep":"a\\b.jpg","goi":"","luc":1}'), isNull);
      expect(tenTepBienLaiHopLe('x'), isFalse);
      expect(tenTepBienLaiHopLe('abcd.jpg.exe.toolongext'), isFalse);
    });

    test('JSON hỏng, thiếu khoá, sai kiểu → null, không ném', () {
      expect(docDongBienLai('không phải json'), isNull);
      expect(docDongBienLai('{"tep":"abcd.jpg"}'), isNull);
      expect(docDongBienLai('{"tep":"abcd.jpg","goi":1,"luc":1}'), isNull);
      expect(docDongBienLai('[1,2]'), isNull);
    });
  });

  group('NhapBienLai', () {
    late Directory dir;
    late AppDatabase db;
    late KhoBienLai kho;
    final bay = DateTime(2026, 10, 2, 19, 0);
    const mbGoi = 'com.mbmobile';

    setUp(() {
      dir = Directory.systemTemp.createTempSync('nhap_bien_lai');
      db = AppDatabase.forTesting(NativeDatabase.memory());
      kho = KhoBienLai(thuMuc: () async => dir);
    });
    tearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });

    /// Như `NhanBienLaiActivity`: một ảnh trong thư mục + một dòng hàng chờ.
    void choNhan(String tep, {String goi = mbGoi, DateTime? luc}) {
      File('${dir.path}/$kThuMucBienLai/$tep')
        ..createSync(recursive: true)
        ..writeAsStringSync('anh');
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync(
          '{"tep":"$tep","goi":"$goi","luc":${(luc ?? bay).millisecondsSinceEpoch}}\n',
          mode: FileMode.append);
    }

    /// Mỗi dòng chữ một hàng riêng trên ảnh.
    List<DongOcr> chu(String vanBan) => [
          for (final (i, d) in vanBan.split('\n').indexed)
            DongOcr(d, trai: 0, tren: i * 20.0, phai: 100, duoi: i * 20.0 + 10),
        ];

    var soId = 0;
    NhapBienLai tao(Map<String, List<DongOcr>> anh, {List<bool>? huy, DocChuAnh? doc}) => NhapBienLai(
          thuMuc: () async => dir,
          dao: db.notificationDao,
          docChu: doc ?? _DocGia(anh),
          kho: kho,
          nguonCuaGoi: nguonCuaGoi,
          huyTomTat: () async => huy?.add(true),
          clock: () => bay,
          idGenerator: () => 'bl-${soId++}',
        );

    Future<List<AppNotification>> hang() => db.notificationDao.getAll(1);

    /// Một hàng loại 20 sinh từ TIN NGÂN HÀNG (D1), như `NhapBienDong` ghi.
    Future<String> coTin(String id, {double tien = 150000, required DateTime luc, String? vt, String chieu = 'chi'}) async {
      final t = TinBienDong(
          soTien: tien, chieu: chieu, thoiGian: luc, noiDung: 'tin ngan hang', nguon: kNguonMb, vanTaySoDu: vt);
      final khoa = dedupeKeyBienDong(t);
      await db.notificationDao.insertAllIfAbsent([
        AppNotificationsCompanion.insert(
          id: id,
          idaccount: 1,
          kind: NotificationKind.bienDongSoDu.name,
          dedupeKey: khoa,
          title: 't',
          body: 'b',
          severity: NotificationSeverity.info.name,
          deeplink: Value(deeplinkBienDong(t, dedupeKey: khoa)),
          createdAt: luc,
        ),
      ]);
      return khoa;
    }

    const bienLai = 'Số tiền 150.000 VND\nThời gian 02/10/2026 18:45\nNội dung tien nha';

    test('⭐ biên lai đọc được → MỘT hàng loại 20: tiêu đề có số tiền + nguồn, deeplink có anh + doc, giờ theo ảnh', () async {
      choNhan('aaaa.jpg');
      expect(await tao({'aaaa.jpg': chu(bienLai)}).nhap(1), 1);
      final h = (await hang()).single;
      expect(h.kind, NotificationKind.bienDongSoDu.name);
      expect(h.title, contains('150.000'));
      expect(h.title, contains(kNguonMb), reason: 'gói com.mbmobile → cùng tên nguồn với D1 (bảng nguồn → ví dùng chung)');
      expect(h.dedupeKey, startsWith('bienDong:'), reason: 'tiền tố này mở đường Lưu / Bỏ qua → xoá cứng hàng trên form');
      expect(h.body, 'tien nha');
      final q = Uri.parse(h.deeplink!).queryParameters;
      expect(q['anh'], 'aaaa.jpg');
      expect(q['doc'], 'chung');
      expect(q['amount'], '150000');
      expect(q['huong'], 'chi');
      expect(h.createdAt, DateTime(2026, 10, 2, 18, 45));
      expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isFalse, reason: 'hàng chờ đã nhập thì xoá');
      expect(await kho.duongDan('aaaa.jpg'), isNotNull, reason: 'ảnh ở lại tới khi Lưu / Bỏ qua — form cần nó để đối chiếu');
    });

    test('app gửi không thuộc danh sách của D1 (hoặc không rõ) → nguồn "Biên lai"', () async {
      choNhan('aaaa.jpg', goi: 'com.app.la');
      choNhan('bbbb.jpg', goi: '');
      await tao({
        'aaaa.jpg': chu('Số tiền 10.000 đ\nNgày 01/10/2026'),
        'bbbb.jpg': chu('Số tiền 20.000 đ\nNgày 01/10/2026'),
      }).nhap(1);
      expect((await hang()).map((h) => h.title.split(' · ').last).toSet(), {kNguonBienLai});
    });

    test('⭐ không đọc ra số tiền → vẫn một hàng "Biên lai chưa đọc được", ảnh GIỮ, không amount trong deeplink', () async {
      choNhan('bbbb.jpg', goi: '');
      expect(await tao({'bbbb.jpg': chu('Hôm nay trời đẹp')}).nhap(1), 1);
      final h = (await hang()).single;
      expect(h.title, 'Biên lai chưa đọc được · $kNguonBienLai');
      expect(h.dedupeKey, 'bienDong:bienLai|bbbb.jpg');
      final q = Uri.parse(h.deeplink!).queryParameters;
      expect(q['doc'], 'khong');
      expect(q.containsKey('amount'), isFalse);
      expect(await kho.duongDan('bbbb.jpg'), isNotNull);
    });

    test('bộ đọc chữ ném → biên lai vẫn thành hàng "chưa đọc được", không mất', () async {
      choNhan('aaaa.jpg');
      expect(await tao(const {}, doc: _DocGia(const {}, nem: true)).nhap(1), 1);
      expect((await hang()).single.title, startsWith('Biên lai chưa đọc được'));
    });

    test('⭐ tin ngân hàng của CÙNG giao dịch đã có hàng (≤ 5 phút) → không hàng mới, hàng tin được GẮN ảnh', () async {
      final khoa = await coTin('tin', luc: DateTime(2026, 10, 2, 18, 45, 20), vt: 'abc123');
      choNhan('aaaa.jpg');
      expect(await tao({'aaaa.jpg': chu(bienLai)}).nhap(1), 0);
      final h = (await hang()).single;
      expect(h.id, 'tin');
      expect(h.dedupeKey, khoa);
      final q = Uri.parse(h.deeplink!).queryParameters;
      expect(q['anh'], 'aaaa.jpg');
      expect(q['vt'], 'abc123', reason: 'gắn ảnh không được làm rơi tham số cũ của hàng tin');
      expect(q['note'], 'tin ngan hang');
      expect(await kho.duongDan('aaaa.jpg'), isNotNull);
    });

    test('⭐ chia sẻ LẠI cùng biên lai (giờ in y hệt) → không hàng thứ hai, ảnh thừa bị xoá — kể cả ở lượt sau', () async {
      choNhan('aaaa.jpg');
      choNhan('bbbb.jpg');
      expect(await tao({'aaaa.jpg': chu(bienLai), 'bbbb.jpg': chu(bienLai)}).nhap(1), 1);
      expect(await kho.duongDan('bbbb.jpg'), isNull);
      choNhan('cccc.jpg');
      expect(await tao({'cccc.jpg': chu(bienLai)}).nhap(1), 0);
      expect((await hang()).length, 1);
      expect(await kho.duongDan('aaaa.jpg'), isNotNull);
      expect(await kho.duongDan('cccc.jpg'), isNull);
    });

    test('⭐ chia sẻ lại biên lai ĐÃ GẮN vào hàng tin → nhận ra là lặp, không đẻ hàng thứ hai', () async {
      // Hàng tin mang vân tay số dư nên KHOÁ của nó khác khoá một hàng biên lai — `insertAllIfAbsent` không cứu được;
      // thứ nhận ra lần lặp là giờ in trên biên lai (`blt`) đã ghi vào hàng tin lúc gắn ảnh.
      await coTin('tin', luc: DateTime(2026, 10, 2, 18, 45, 20), vt: 'abc123');
      choNhan('aaaa.jpg');
      await tao({'aaaa.jpg': chu(bienLai)}).nhap(1);
      choNhan('bbbb.jpg');
      expect(await tao({'bbbb.jpg': chu(bienLai)}).nhap(1), 0);
      final h = (await hang()).single;
      expect(anhTuDeeplink(h.deeplink), 'aaaa.jpg');
      expect(await kho.duongDan('bbbb.jpg'), isNull);
    });

    test('⭐ HAI lần chuyển cùng số tiền cách 3 phút (hai biên lai in hai giờ) → HAI hàng — không gộp theo cửa sổ 5 phút',
        () async {
      choNhan('aaaa.jpg');
      choNhan('bbbb.jpg');
      final n = await tao({
        'aaaa.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:45'),
        'bbbb.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:48'),
      }).nhap(1);
      expect(n, 2, reason: 'gộp là mất khoản sau, im lặng — đúng lỗi D1 từng vấp trên Realme 30/09');
      expect(await kho.duongDan('bbbb.jpg'), isNotNull);
    });

    test('hai biên lai khác nhau + hai hàng tin: mỗi biên lai gắn vào hàng tin GẦN GIỜ nó nhất, không dồn vào một hàng',
        () async {
      await coTin('tinA', tien: 10000, luc: DateTime(2026, 10, 2, 18, 45, 10), vt: 'a');
      await coTin('tinB', tien: 10000, luc: DateTime(2026, 10, 2, 18, 48, 10), vt: 'b');
      choNhan('aaaa.jpg');
      choNhan('bbbb.jpg');
      await tao({
        'aaaa.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:48'),
        'bbbb.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:45'),
      }).nhap(1);
      final theoId = {for (final h in await hang()) h.id: anhTuDeeplink(h.deeplink)};
      expect(theoId, {'tinA': 'bbbb.jpg', 'tinB': 'aaaa.jpg'});
    });

    test('⭐ hai biên lai KHÁC nhau mà chỉ có MỘT hàng tin: một cái gắn vào hàng tin, cái kia thành hàng mới — không đè ảnh',
        () async {
      await coTin('tin', tien: 10000, luc: DateTime(2026, 10, 2, 18, 46));
      choNhan('aaaa.jpg');
      choNhan('bbbb.jpg');
      final n = await tao({
        'aaaa.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:45'),
        'bbbb.jpg': chu('Số tiền 10.000 VND\nThời gian 02/10/2026 18:48'),
      }).nhap(1);
      expect(n, 1);
      expect((await hang()).map((h) => anhTuDeeplink(h.deeplink)).toSet(), {'aaaa.jpg', 'bbbb.jpg'},
          reason: 'đè ảnh thứ hai lên hàng tin là ảnh thứ nhất thành mồ côi rồi bị dọn — mất một biên lai, im lặng');
      expect(await kho.duongDan('aaaa.jpg'), isNotNull);
      expect(await kho.duongDan('bbbb.jpg'), isNotNull);
    });

    test('⭐ dọn mồ côi: ảnh không hàng nào trỏ tới bị xoá; ảnh của dòng hàng chờ MỚI (Kotlin vừa ghi) thì GIỮ', () async {
      File('${dir.path}/$kThuMucBienLai/mocoi.jpg')
        ..createSync(recursive: true)
        ..writeAsStringSync('x');
      choNhan('aaaa.jpg');
      await tao(const {}, doc: _DocGoi(() => choNhan('moii.jpg'))).nhap(1);
      expect(await kho.duongDan('mocoi.jpg'), isNull);
      expect(await kho.duongDan('aaaa.jpg'), isNotNull);
      expect(await kho.duongDan('moii.jpg'), isNotNull, reason: 'xoá ảnh vừa nhận là mất biên lai người dùng vừa chia sẻ');
      expect(File('${dir.path}/$kTepBienLaiCho').readAsStringSync(), contains('moii.jpg'));
    });

    test('dọn mồ côi chạy cả khi KHÔNG có hàng chờ (ảnh của hàng đã bị vuốt xoá ở trung tâm thông báo)', () async {
      choNhan('aaaa.jpg');
      final nhap = tao({'aaaa.jpg': chu(bienLai)});
      await nhap.nhap(1);
      await db.notificationDao.xoaCung(1, (await hang()).single.dedupeKey);
      await nhap.nhap(1);
      expect(await kho.duongDan('aaaa.jpg'), isNull);
    });

    test('dòng quá 30 ngày → bỏ, ảnh bị dọn; tệp ảnh đã mất → bỏ dòng; dòng hỏng → bỏ; không ném', () async {
      choNhan('cuuu.jpg', luc: bay.subtract(const Duration(days: 31)));
      File('${dir.path}/$kTepBienLaiCho').writeAsStringSync(
          '{"tep":"matt.jpg","goi":"","luc":${bay.millisecondsSinceEpoch}}\nrác\n',
          mode: FileMode.append);
      expect(await tao({'cuuu.jpg': chu('Số tiền 10.000 đ')}).nhap(1), 0);
      expect(await hang(), isEmpty);
      expect(await kho.duongDan('cuuu.jpg'), isNull);
    });

    test('gỡ tóm tắt sau lượt có hàng chờ; không có hàng chờ → 0, không gọi bộ đọc, không gỡ gì', () async {
      final huy = <bool>[];
      final doc = _DocGia(const {});
      expect(await tao(const {}, huy: huy, doc: doc).nhap(1), 0);
      expect(doc.daDoc, isEmpty);
      expect(huy, isEmpty);
      choNhan('aaaa.jpg');
      await tao({'aaaa.jpg': chu('Số tiền 10.000 đ')}, huy: huy).nhap(1);
      expect(huy, [true]);
    });

    test('⭐ donKhiDangXuat: ảnh, hàng chờ và hàng loại 20 MANG ẢNH đều mất; hàng D1 thường thì GIỮ', () async {
      choNhan('aaaa.jpg');
      final nhap = tao({'aaaa.jpg': chu(bienLai)});
      await nhap.nhap(1);
      await coTin('d1', tien: 9000, luc: bay, chieu: 'thu');
      choNhan('bbbb.jpg');
      await nhap.donKhiDangXuat(1);
      expect((await hang()).map((h) => h.id), ['d1'],
          reason: 'hàng chờ gắn MÁY: người đăng nhập sau không được thấy biên lai của người trước');
      expect(Directory('${dir.path}/$kThuMucBienLai').existsSync(), isFalse);
      expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isFalse);
    });

    test('donKhiDangXuat không có phiên (id null) vẫn xoá sạch ảnh và hàng chờ', () async {
      choNhan('aaaa.jpg');
      await tao(const {}).donKhiDangXuat(null);
      expect(Directory('${dir.path}/$kThuMucBienLai').existsSync(), isFalse);
      expect(File('${dir.path}/$kTepBienLaiCho').existsSync(), isFalse);
    });
  });
}
