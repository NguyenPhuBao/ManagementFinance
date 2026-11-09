/// Bộ điều phối khi nhà ĐỔI (spec gia đình 2026-10-23 mục 4.3 + 4.6 đường 2; kế hoạch lát 1 — một bộ thay cho
/// `tham_gia_nha` + `don_du_lieu_nha` của spec 7.1): rời nhà [DoiNha.tu] → xoá trên máy mọi hàng của nhà ấy; vào nhà
/// [DoiNha.den] → kéo lại toàn bộ. Tuần tự: dọn trước, kéo sau; sự kiện sau chờ sự kiện trước.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/household/application/dieu_phoi_doi_nha.dart';
import 'package:flowmoney/features/household/data/models/nha_cua_toi.dart';
import 'package:flutter_test/flutter_test.dart';

class _DbDonHongLanDau extends AppDatabase {
  _DbDonHongLanDau() : super.forTesting(NativeDatabase.memory());
  var _lan = 0;
  @override
  Future<int> xoaHangCuaNha(int idhousehold) async {
    if (_lan++ == 0) throw StateError('dọn hỏng');
    return super.xoaHangCuaNha(idhousehold);
  }
}

Future<void> _dungViThu(AppDatabase d) async {
  for (final (id, nha) in [('vi-rieng', null), ('vi-nha-5', 5), ('vi-nha-7', 7)]) {
    await d.walletDao.insert(WalletsCompanion(
        id: Value(id),
        idaccount: const Value(10),
        name: Value(id),
        idhousehold: Value(nha),
        updatedAt: Value(DateTime(2026, 10, 24))));
  }
}

void main() {
  late AppDatabase db;
  late List<String> nhatKy;
  late DieuPhoiDoiNha dieuPhoi;
  Completer<void>? giuKeo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nhatKy = [];
    giuKeo = null;
    dieuPhoi = DieuPhoiDoiNha(
      db: db,
      keoLaiToanBo: (id) async {
        nhatKy.add('keo:$id');
        final g = giuKeo;
        if (g != null) await g.future;
      },
    );
    await _dungViThu(db);
  });
  tearDown(() async {
    await dieuPhoi.dung();
    await db.close();
  });

  Future<Set<String>> idVi() async => (await db.select(db.wallets).get()).map((w) => w.id).toSet();

  test('rời nhà 5 → chỉ xoá hàng của nhà 5, không kéo', () async {
    await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 5, den: null));
    expect(await idVi(), {'vi-rieng', 'vi-nha-7'});
    expect(nhatKy, isEmpty);
  });

  test('DoiNha xếp hàng từ tài khoản CŨ khi phiên đã sang tài khoản khác: bỏ qua, không dọn, không kéo, không ghi dấu', () async {
    final dau = <String>[];
    final phienKhac = DieuPhoiDoiNha(
      db: db,
      keoLaiToanBo: (id) async => nhatKy.add('keo:$id'),
      ghiDau: (id, nha) async => dau.add('dau:$id:$nha'),
      taiKhoanPhien: () => 11,
    );
    await phienKhac.xuLy(const DoiNha(idaccount: 10, tu: 5, den: 12));
    expect(await idVi(), hasLength(3), reason: 'dọn theo sự kiện của tài khoản khác là xoá nhầm hàng nhà của phiên hiện tại');
    expect(nhatKy, isEmpty);
    expect(dau, isEmpty, reason: 'dấu còn nguyên nên phiên sau của tài khoản 10 phát lại đúng cặp này');
    // Cùng tài khoản thì chạy bình thường.
    await DieuPhoiDoiNha(
      db: db,
      keoLaiToanBo: (id) async => nhatKy.add('keo:$id'),
      ghiDau: (id, nha) async => dau.add('dau:$id:$nha'),
      taiKhoanPhien: () => 10,
    ).xuLy(const DoiNha(idaccount: 10, tu: 5, den: 12));
    expect(await idVi(), isNot(contains('vi-nha-5')));
    expect(dau, ['dau:10:12']);
  });

  test('vào nhà 12 → kéo lại toàn bộ cho đúng tài khoản, không xoá gì', () async {
    await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: null, den: 12));
    expect(nhatKy, ['keo:10']);
    expect(await idVi(), hasLength(3));
  });

  test('đổi nhà 5 → 12: dọn trước, kéo sau', () async {
    await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 5, den: 12));
    expect(await idVi(), isNot(contains('vi-nha-5')));
    expect(nhatKy, ['keo:10']);
  });

  test('nghe luồng: sự kiện sau chờ sự kiện trước; lỗi không giết hàng đợi', () async {
    final luong = StreamController<DoiNha>();
    dieuPhoi.batDauNghe(luong.stream);
    giuKeo = Completer<void>();
    luong.add(const DoiNha(idaccount: 10, tu: null, den: 12));
    luong.add(const DoiNha(idaccount: 10, tu: 5, den: null));
    await Future<void>.delayed(Duration.zero);
    expect(nhatKy, ['keo:10']);
    expect(await idVi(), contains('vi-nha-5'), reason: 'sự kiện thứ hai CHỜ lượt kéo của sự kiện đầu xong mới chạy');
    giuKeo!.complete();
    await dieuPhoi.choXong();
    expect(await idVi(), isNot(contains('vi-nha-5')));

    // Lỗi ở một lượt không chặn lượt sau.
    final dieuPhoiLoi = DieuPhoiDoiNha(db: db, keoLaiToanBo: (_) async => throw StateError('mạng'));
    final luong2 = StreamController<DoiNha>();
    dieuPhoiLoi.batDauNghe(luong2.stream);
    luong2.add(const DoiNha(idaccount: 10, tu: null, den: 12));
    luong2.add(const DoiNha(idaccount: 10, tu: 7, den: null));
    await Future<void>.delayed(Duration.zero);
    await dieuPhoiLoi.choXong();
    expect(await idVi(), isNot(contains('vi-nha-7')), reason: 'lượt hỏng trước không được làm mất lượt dọn sau');
    await dieuPhoiLoi.dung();
    await luong.close();
    await luong2.close();
  });

  test('giao dịch NULL trỏ ví nhà 5 đi theo ví khi đổi 5 → 12: dọn không ném, vẫn kéo', () async {
    // Giao dịch RIÊNG (idhousehold NULL) trỏ vào ví của nhà 5: nay bị xoá cùng ví (G113 lỗ hổng 3).
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: 'gd-mac-ket',
        walletId: 'vi-nha-5',
        idaccount: 10,
        amount: 1000,
        type: 'chi',
        date: DateTime(2026, 10, 24),
        updatedAt: DateTime(2026, 10, 24)));
    final luong = StreamController<DoiNha>();
    dieuPhoi.batDauNghe(luong.stream);
    luong.add(const DoiNha(idaccount: 10, tu: 5, den: 12));
    luong.add(const DoiNha(idaccount: 10, tu: 7, den: null));
    await Future<void>.delayed(Duration.zero);
    await dieuPhoi.choXong();
    expect(nhatKy, ['keo:10']);
    final ids = await idVi();
    expect(ids, isNot(contains('vi-nha-5')), reason: 'ví nhà 5 đã bị dọn');
    expect(ids, isNot(contains('vi-nha-7')), reason: 'lượt sau trong hàng đợi vẫn chạy');
    final gds = (await db.select(db.transactions).get()).map((t) => t.id);
    expect(gds, isNot(contains('gd-mac-ket')), reason: 'neo NULL đi theo ví, không khoá phép xoá ví');
    await luong.close();
  });

  test('dọn nhà 5 hỏng khi đổi 5 → 12: VẪN kéo lại, lượt sau vẫn chạy', () async {
    final dbHong = _DbDonHongLanDau();
    addTearDown(dbHong.close);
    await _dungViThu(dbHong);
    final dp = DieuPhoiDoiNha(db: dbHong, keoLaiToanBo: (id) async => nhatKy.add('keo:$id'));
    addTearDown(dp.dung);
    final luong = StreamController<DoiNha>();
    dp.batDauNghe(luong.stream);
    luong.add(const DoiNha(idaccount: 10, tu: 5, den: 12));
    luong.add(const DoiNha(idaccount: 10, tu: 7, den: null));
    await Future<void>.delayed(Duration.zero);
    await dp.choXong();
    expect(nhatKy, ['keo:10'],
        reason: 'lỗi dọn không được nuốt lượt kéo của CÙNG sự kiện — kho đã mang nhà 12, không ai phát lại');
    final con = (await dbHong.select(dbHong.wallets).get()).map((w) => w.id);
    expect(con, isNot(contains('vi-nha-7')), reason: 'lượt sau trong hàng đợi vẫn chạy');
    await luong.close();
  });

  group('G113 lỗ hổng 1: dấu bền', () {
    late List<(int, int?)> dau;
    setUp(() {
      dau = [];
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (id) async => nhatKy.add('keo:$id'),
        ghiDau: (id, nha) async => dau.add((id, nha)),
      );
    });

    test('xử lý xong mới ghi dấu; dấu = nhà đến', () async {
      await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: null, den: 5));
      expect(dau, [(10, 5)]);
      expect(nhatKy, ['keo:10']);
    });

    test('rời nhà: dấu về null', () async {
      await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 5, den: null));
      expect(dau, [(10, null)]);
    });

    test('keoLaiToanBo ném: KHÔNG ghi dấu, lần mở phiên sau chạy lại', () async {
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (_) async => throw StateError('mạng'),
        ghiDau: (id, nha) async => dau.add((id, nha)),
      );
      await expectLater(dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: null, den: 5)), throwsStateError);
      expect(dau, isEmpty);
    });

    test('dọn hỏng: KHÔNG ghi dấu dù kéo xong', () async {
      await db.close();
      await expectLater(dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 5, den: 7)), throwsA(anything));
      expect(dau, isEmpty);
      expect(nhatKy, ['keo:10'], reason: 'dọn hỏng vẫn phải xin kéo');
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
  });

  group('gia đình 1A Task 9: trả tiền trước khi dọn', () {
    late List<String> trinhTu;
    setUp(() {
      trinhTu = [];
    });

    DieuPhoiDoiNha dung({Future<void> Function(int, int)? truoc}) => dieuPhoi = DieuPhoiDoiNha(
          db: db,
          keoLaiToanBo: (id) async => nhatKy.add('keo:$id'),
          truocKhiDon: truoc ??
              (idNha, id) async {
                // Lúc này hàng của nhà PHẢI còn: xoá trước là mất dấu khoản góp chưa đẩy.
                final con = (await idVi()).contains('vi-nha-$idNha');
                trinhTu.add('truoc:$idNha:$id:conHang=$con');
              },
        );

    test('rời nhà 7: truocKhiDon(7, 10) chạy TRƯỚC xoaHangCuaNha', () async {
      dung();
      await dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 7, den: null));
      expect(trinhTu, ['truoc:7:10:conHang=true'],
          reason: 'xoá hàng trước là mất dấu khoản góp chưa đẩy, tiền không về ví riêng');
      expect(await idVi(), isNot(contains('vi-nha-7')));
    });

    test('truocKhiDon ném: KHÔNG xoá nhà ấy (lỗi nhất thời không được làm mất tiền), vẫn kéo cho nhà đến, không ghi dấu', () async {
      final dau = <(int, int?)>[];
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (id) async => nhatKy.add('keo:$id'),
        ghiDau: (id, nha) async => dau.add((id, nha)),
        truocKhiDon: (_, __) async => throw StateError('database is locked'),
      );
      await expectLater(dieuPhoi.xuLy(const DoiNha(idaccount: 10, tu: 5, den: 12)), throwsStateError);
      expect(await idVi(), contains('vi-nha-5'), reason: 'xoá hàng khi chưa trả tiền là mất tiền');
      expect(nhatKy, ['keo:10'], reason: 'lượt kéo của cùng sự kiện không bị chặn');
      expect(dau, isEmpty, reason: 'chưa xử lý xong thì chưa ghi dấu');
    });
  });

  group('gia đình 1A Task 9: dọn hàng nhà kẹt sau mỗi lần /me được áp', () {
    late List<String> truoc;
    setUp(() {
      truoc = [];
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (id) async {
          nhatKy.add('keo:$id');
          final g = giuKeo;
          if (g != null) await g.future;
        },
        truocKhiDon: (idNha, id) async => truoc.add('$idNha:$id'),
      );
    });

    test('/me không nhà: dọn MỌI nhà còn trên máy (5 và 7), trả tiền trước từng nhà', () async {
      await dieuPhoi.donHangKet(const NhaDaDoc(idaccount: 10, idNha: null));
      expect(await idVi(), {'vi-rieng'});
      expect(truoc, ['5:10', '7:10']);
    });

    test('/me = nhà 7: hàng nhà 7 NGUYÊN, hàng nhà 5 bị dọn', () async {
      await dieuPhoi.donHangKet(const NhaDaDoc(idaccount: 10, idNha: 7));
      expect(await idVi(), {'vi-rieng', 'vi-nha-7'}, reason: 'dọn nhầm nhà hiện tại là mất dữ liệu đang dùng');
      expect(truoc, ['5:10']);
    });

    test('không có hàng nhà nào: không làm gì, không trả tiền', () async {
      await db.xoaHangCuaNha(5);
      await db.xoaHangCuaNha(7);
      truoc.clear();
      await dieuPhoi.donHangKet(const NhaDaDoc(idaccount: 10, idNha: null));
      expect(truoc, isEmpty);
      expect(await idVi(), {'vi-rieng'});
    });

    test('lỗi một nhà (5) không chặn nhà khác (7)', () async {
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (_) async {},
        truocKhiDon: (idNha, _) async {
          if (idNha == 5) throw StateError('hỏng');
        },
      );
      await dieuPhoi.donHangKet(const NhaDaDoc(idaccount: 10, idNha: null));
      expect(await idVi(), {'vi-rieng', 'vi-nha-5'}, reason: 'nhà 5 trả tiền hỏng nên GIỮ; nhà 7 vẫn được dọn');
    });

    test('qua luồng: tuần tự với xuLy — vào nhà 12 đang kéo thì lượt dọn chờ', () async {
      final doi = StreamController<DoiNha>();
      final daDoc = StreamController<NhaDaDoc>();
      dieuPhoi.batDauNghe(doi.stream, daDocNha: daDoc.stream);
      giuKeo = Completer<void>();
      doi.add(const DoiNha(idaccount: 10, tu: null, den: 12));
      daDoc.add(const NhaDaDoc(idaccount: 10, idNha: 12));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(nhatKy, ['keo:10']);
      expect(await idVi(), hasLength(3), reason: 'lượt dọn CHỜ lượt kéo của DoiNha trước nó xong');
      giuKeo!.complete();
      await dieuPhoi.choXong();
      expect(await idVi(), {'vi-rieng'}, reason: '/me = 12 nên cả 5 và 7 đều không còn thuộc người dùng');
      await doi.close();
      await daDoc.close();
    });

    test('sự kiện cũ của tài khoản đã đổi (hàng việc đang bận): bỏ, không xoá hàng của tài khoản mới', () async {
      var phien = 10;
      dieuPhoi = DieuPhoiDoiNha(
        db: db,
        keoLaiToanBo: (id) async {
          nhatKy.add('keo:$id');
          await giuKeo?.future;
        },
        taiKhoanPhien: () => phien,
      );
      final doi = StreamController<DoiNha>();
      final daDoc = StreamController<NhaDaDoc>();
      dieuPhoi.batDauNghe(doi.stream, daDocNha: daDoc.stream);
      giuKeo = Completer<void>();
      doi.add(const DoiNha(idaccount: 10, tu: null, den: 12));
      daDoc.add(const NhaDaDoc(idaccount: 10, idNha: null)); // xếp hàng sau lượt kéo đang bận
      await Future<void>.delayed(Duration.zero);
      phien = 11; // tài khoản B đăng nhập trong lúc chờ
      giuKeo!.complete();
      await dieuPhoi.choXong();
      expect(await idVi(), hasLength(3), reason: 'NhaDaDoc của tài khoản 10 chạy khi phiên là 11: xoá hàng của B là sai');
      await doi.close();
      await daDoc.close();
    });

    test('sự kiện cũ bị lần đọc /me mới hơn thay thế (hàng việc đang bận): chỉ lần mới nhất được dọn', () async {
      final doi = StreamController<DoiNha>();
      final daDoc = StreamController<NhaDaDoc>();
      dieuPhoi.batDauNghe(doi.stream, daDocNha: daDoc.stream);
      giuKeo = Completer<void>();
      doi.add(const DoiNha(idaccount: 10, tu: null, den: 12));
      daDoc.add(const NhaDaDoc(idaccount: 10, idNha: null)); // cũ: dọn theo nó sẽ xoá cả nhà 7
      daDoc.add(const NhaDaDoc(idaccount: 10, idNha: 7)); // mới: đã vào nhà 7
      await Future<void>.delayed(Duration.zero);
      giuKeo!.complete();
      await dieuPhoi.choXong();
      expect(await idVi(), {'vi-rieng', 'vi-nha-7'}, reason: 'bản cũ NhaDaDoc(null) xoá hàng pending của nhà vừa vào');
      expect(truoc, ['5:10']);
      await doi.close();
      await daDoc.close();
    });
  });
}
