import 'package:flutter_test/flutter_test.dart';
import 'package:flowmoney/core/sync/sync_payload_normalizer.dart';

void main() {
  test('maps local income and expense types to Backend sync enums', () {
    expect(SyncPayloadNormalizer.transactionType('thu'), 'Income');
    expect(SyncPayloadNormalizer.transactionType('chi'), 'Expense');
  });

  test('keeps an already normalized transaction type unchanged', () {
    expect(SyncPayloadNormalizer.transactionType('Transfer'), 'Transfer');
  });

  test('renames updated_at to the update_at field required by Sync API', () {
    final payload = SyncPayloadNormalizer.forPush({
      'id': 'wallet-id',
      'updated_at': '2026-09-01T08:01:42.355Z',
    });

    expect(payload['update_at'], '2026-09-01T08:01:42.355Z');
    expect(payload.containsKey('updated_at'), isFalse);
  });

  test('maps local transaction field names to the Sync API contract', () {
    final payload = SyncPayloadNormalizer.transactionForPush({
      'wallet_id': 'wallet-uuid',
      'category_id': 'category-uuid',
      'date': '2026-09-01T08:09:57.427Z',
    });

    expect(payload['walletId'], 'wallet-uuid');
    expect(payload['categoryId'], 'category-uuid');
    expect(payload['dateTransaction'], '2026-09-01T08:09:57.427Z');
    expect(payload.containsKey('wallet_id'), isFalse);
    expect(payload.containsKey('category_id'), isFalse);
    expect(payload.containsKey('date'), isFalse);
  });

  test('matches local and Backend category classifications', () {
    expect(SyncPayloadNormalizer.sameCategoryClassify('thu', 'Thu'), isTrue);
    expect(SyncPayloadNormalizer.sameCategoryClassify('chi', 'Chi'), isTrue);
    expect(
      SyncPayloadNormalizer.sameCategoryClassify('vay_no', 'Vay/nợ'),
      isTrue,
    );
  });

  test('maps the local debt category to the canonical backend value', () {
    // Không hard-code 'Vay/nợ' ở đây: giá trị gửi lên PHẢI khớp với CHECK
    // constraint `ck_category_classify` đang chạy trên PostgreSQL, hiện là
    // 'Vay/no'. Bám vào hằng số nên test vẫn đúng sau khi backend migrate sang
    // 'Vay/nợ' và hằng số được đổi theo.
    // Xem docs/superpowers/backend/CAN-LAM/CATEGORY_CLASSIFY_ALIGNMENT.md
    for (final localValue in ['vay_no', 'vay_nợ', 'Vay/no', 'Vay/nợ']) {
      final payload =
          SyncPayloadNormalizer.categoryForPush({'classify': localValue});
      expect(
        payload['classify'],
        SyncPayloadNormalizer.canonicalDebtClassify,
        reason: '"$localValue" phải được chuẩn hoá về đúng một giá trị gửi lên',
      );
    }

    // Chốt chặn: hằng số chỉ được phép là một trong hai dạng đã biết.
    expect(
      SyncPayloadNormalizer.canonicalDebtClassify,
      anyOf('Vay/no', 'Vay/nợ'),
    );
  });

  test('maps the canonical backend debt category to the local value', () {
    expect(
      SyncPayloadNormalizer.categoryClassifyFromBackend('Vay/nợ'),
      'vay_no',
    );
  });

  test('converts local expense to a signed canonical transaction', () {
    final payload = SyncPayloadNormalizer.transactionForPush({
      'type': 'chi',
      'amount': 50000,
    });

    expect(payload['type'], 'Transaction');
    expect(payload['amount'], -50000);
  });

  test('converts local wallet types to canonical database values', () {
    final payload = SyncPayloadNormalizer.walletForPush({'type': 'saving'});

    expect(payload['type'], 'Saving');
  });
}
