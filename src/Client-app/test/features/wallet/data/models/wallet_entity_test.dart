/// `WalletEntity.fromDrift` — dời từ `WalletLocalDataSourceImpl._toEntity` (spec Entity Giao dịch + Ví 2026-10-14, 4.1).
/// Đếm cột bằng máy: Entity = cột bảng − 5 (`bankCassoId` · `deletedAt` · `syncRetryCount` · `syncError` · `syncBlockedUntil`).
library;

import 'package:drift/native.dart';
import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moc = DateTime(2026, 10, 14, 7);
  // Mọi trường khác mặc định của Entity (currency 'VND', icon 'wallet', colour '#4CAF50', isDefault false, isDeleted false,
  // includeInTotal true, status 'active', allowNegative false, biTuChoiTrungTen false, syncStatus 'pending').
  final hang = Wallet(
    id: 'w-1',
    idaccount: 10,
    name: 'Ví MB',
    type: 'bank',
    balance: 987654,
    currency: 'USD',
    icon: 'bank',
    colour: '#123456',
    isDefault: true,
    isDeleted: true,
    includeInTotal: false,
    status: 'inactive',
    allowNegative: true,
    biTuChoiTrungTen: true,
    bankCassoId: 'casso-1',
    syncStatus: 'synced',
    syncRetryCount: 3,
    syncError: 'lỗi',
    syncBlockedUntil: moc,
    updatedAt: moc,
    deletedAt: moc,
  );

  test('fromDrift chép đủ 16 trường, không chép 6 cột ngoài Entity', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final e = WalletEntity.fromDrift(hang);
    expect(e.props.length, db.wallets.$columns.length - 6,
        reason:
            'Thêm cột vào bảng Wallets thì quyết định: vào Entity, hay ghi vào danh sách 6 cột không chép.');
    expect(e.id, 'w-1');
    expect(e.idaccount, 10);
    expect(e.name, 'Ví MB');
    expect(e.type, 'bank');
    expect(e.balance, 987654);
    expect(e.currency, 'USD');
    expect(e.icon, 'bank');
    expect(e.colour, '#123456');
    expect(e.isDefault, isTrue);
    expect(e.isDeleted, isTrue);
    expect(e.includeInTotal, isFalse);
    expect(e.status, 'inactive');
    expect(e.allowNegative, isTrue);
    expect(e.biTuChoiTrungTen, isTrue);
    expect(e.syncStatus, 'synced');
    expect(e.updatedAt, moc);
  });
}
