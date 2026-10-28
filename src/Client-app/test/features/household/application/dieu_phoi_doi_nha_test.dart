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
    for (final (id, nha) in [('vi-rieng', null), ('vi-nha-5', 5), ('vi-nha-7', 7)]) {
      await db.walletDao.insert(WalletsCompanion(
          id: Value(id),
          idaccount: const Value(10),
          name: Value(id),
          idhousehold: Value(nha),
          updatedAt: Value(DateTime(2026, 10, 24))));
    }
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
}
