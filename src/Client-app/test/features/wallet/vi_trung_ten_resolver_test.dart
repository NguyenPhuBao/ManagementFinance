/// G63 — `ViTrungTenResolver` đặt cờ cho ví bị server từ chối vì trùng tên (spec mục 4.3).
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/core/sync/sync_models.dart';
import 'package:flowmoney/features/wallet/data/services/vi_trung_ten_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late StreamController<SyncResult> day;
  late ViTrungTenResolver resolver;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    day = StreamController<SyncResult>.broadcast();
    resolver = ViTrungTenResolver(db: db)..batDauNghe(day.stream);
    await db.walletDao.insert(WalletsCompanion.insert(
        id: 'r', idaccount: 7, name: 'Ví MB Bank', updatedAt: DateTime(2026, 10, 5)));
  });

  tearDown(() async {
    await resolver.dung();
    await day.close();
    await db.close();
  });

  Future<void> phat({required String? code, SyncEntityType entity = SyncEntityType.wallet}) async {
    day.add(SyncResult(totalOps: 1, succeeded: 0, failed: 1, failures: [
      SyncOpFailure(
          localId: 'r', entity: entity, message: 'Tên ví đã tồn tại', kind: SyncFailureKind.permanent, code: code),
    ]));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<bool> co() async => (await db.walletDao.getById('r'))!.biTuChoiTrungTen;

  test('⭐ WALLET_NAME_DUPLICATE trên ví → đặt cờ', () async {
    await phat(code: 'WALLET_NAME_DUPLICATE');
    expect(await co(), isTrue);
  });

  test('UNIQUE_VIOLATION trên ví → đặt cờ (backend nhận diện bằng chuỗi, có thể rơi về mã chung)', () async {
    await phat(code: 'UNIQUE_VIOLATION');
    expect(await co(), isTrue);
  });

  test('mã khác trên ví → KHÔNG đặt cờ', () async {
    await phat(code: 'WALLET_DEFAULT_DUPLICATE');
    expect(await co(), isFalse);
  });

  test('⭐ đúng mã nhưng thực thể khác → KHÔNG đặt cờ (bẫy 3)', () async {
    await phat(code: 'UNIQUE_VIOLATION', entity: SyncEntityType.category);
    expect(await co(), isFalse, reason: 'UNIQUE_VIOLATION của danh mục / hoá đơn không nói gì về tên ví.');
  });

  test('thất bại không mang mã (backend cũ, lỗi truyền tải) → KHÔNG đặt cờ', () async {
    await phat(code: null);
    expect(await co(), isFalse);
  });

  test('hai lượt phát cho cùng một thất bại (trước Pull và sau lần thử lại) — luỹ đẳng', () async {
    await phat(code: 'WALLET_NAME_DUPLICATE');
    await phat(code: 'WALLET_NAME_DUPLICATE');
    expect(await co(), isTrue);
  });
}
