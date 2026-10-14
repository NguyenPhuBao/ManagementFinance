/// Hai trường CHỈ ĐỌC `billId` / `deletedAt` của `TransactionEntity` (spec Entity Giao dịch + Ví 2026-10-14, mục 4.0):
/// `fromDrift` chép, `toCompanion` KHÔNG mang — đường ghi không đổi (`updateRow` ghi bằng `write`, cột không mang thì không
/// đụng). Cùng khuôn `WalletEntity.biTuChoiTrungTen`.
library;

import 'package:flowmoney/core/database/app_database.dart';
import 'package:flowmoney/features/transaction/data/models/transaction_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final moc = DateTime(2026, 10, 14, 9, 30);
  final xoa = DateTime(2026, 10, 13, 8);
  // Mọi trường khác mặc định — ca "chép đủ" mới nhìn thấy từng trường (bài học review đợt Hoá đơn).
  final hang = Transaction(
    id: 't-1',
    walletId: 'v-1',
    idaccount: 10,
    categoryId: 'c-1',
    walletTransfer: 'v-2',
    goalId: 'g-1',
    billId: 'b-1',
    amount: 123456,
    type: 'transfer',
    status: 'completed',
    provider: 'Manual',
    note: 'ghi chú',
    date: moc,
    images: '["a.jpg","b.jpg"]',
    syncStatus: 'synced',
    syncRetryCount: 2,
    updatedAt: moc,
    isDeleted: true,
    deletedAt: xoa,
  );

  test('fromDrift chép billId và deletedAt', () {
    final e = TransactionEntity.fromDrift(hang);
    expect(e.billId, 'b-1');
    expect(e.deletedAt, xoa);
    expect(e.isDeleted, isTrue);
    expect(e.images, ['a.jpg', 'b.jpg']);
  });

  test('toCompanion KHÔNG mang billId / deletedAt — hai cột chỉ đọc', () {
    final c = TransactionEntity.fromDrift(hang).toCompanion();
    expect(c.billId.present, isFalse,
        reason:
            'Mang billId là mỗi lần sửa giao dịch dựng từ form (billId null) ghi NULL đè lên khoản trả hoá đơn.');
    expect(c.deletedAt.present, isFalse);
    expect(c.id.value, 't-1');
  });

  test('copyWith chuyền nguyên billId / deletedAt, không có tham số đặt', () {
    final e = TransactionEntity.fromDrift(hang).copyWith(note: 'khác');
    expect(e.billId, 'b-1');
    expect(e.deletedAt, xoa);
    expect(e.note, 'khác');
  });

  test('dựng tay không có hai trường → null', () {
    final e = TransactionEntity(
        id: 'x',
        walletId: 'v',
        idaccount: 1,
        amount: 1,
        type: 'chi',
        date: moc,
        updatedAt: moc);
    expect(e.billId, isNull);
    expect(e.deletedAt, isNull);
  });
}
