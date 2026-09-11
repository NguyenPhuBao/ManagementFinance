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
    // Xem docs/superpowers/backend/DA-XONG/CATEGORY_CLASSIFY_ALIGNMENT.md
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

  test('màu danh mục đẩy lên bằng khoá `color` — khoá duy nhất backend đọc (G24)',
      () {
    // Backend nhận `color` (`sync.repository.js:149`) và không có nhánh nào đọc
    // `colour`. Gửi `colour` thì màu bị bỏ qua IM LẶNG — quy tắc 4 `CLAUDE.md`.
    // `walletForPush` đổi khoá này từ lâu; `categoryForPush` thì chưa, nên màu
    // danh mục chưa bao giờ lên được server dù cột `category.Color` đã có từ
    // `database/12`.
    final payload = SyncPayloadNormalizer.categoryForPush({
      'classify': 'chi',
      'colour': '#FF5722',
    });

    expect(payload['color'], '#FF5722',
        reason: 'Màu phải đi dưới khoá `color` thì backend mới ghi vào cột.');
    expect(payload.containsKey('colour'), isFalse,
        reason: 'Còn sót `colour` là dấu hiệu phép đổi khoá chỉ làm một nửa.');
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

  test('loại ví lạ KHÔNG được gửi nguyên si lên server', () {
    // `chk_wallet_type` trên PostgreSQL chỉ nhận đúng bốn chuỗi này (đo thẳng
    // trên CSDL 2026-09-09). Bản trước để giá trị lạ đi qua nguyên vẹn, nên ví
    // tạo bằng "Ví điện tử" hoặc "Thẻ tín dụng" trên giao diện cũ vỡ CHECK ở
    // mỗi lần đẩy và **kẹt hàng đợi vĩnh viễn**, không một dòng nào báo ra.
    const choPhep = {'Cash', 'Bank', 'Saving', 'Banking'};
    for (final la in ['ewallet', 'debt', 'investment', 'linh tinh', '']) {
      final payload = SyncPayloadNormalizer.walletForPush({'type': la});
      expect(choPhep.contains(payload['type']), isTrue,
          reason: 'Loại "$la" bị đẩy lên nguyên si là vỡ chk_wallet_type.');
    }
  });

  test('hai loại đã bỏ đẩy lên thành Bank', () {
    expect(SyncPayloadNormalizer.walletForPush({'type': 'ewallet'})['type'],
        'Bank');
    expect(SyncPayloadNormalizer.walletForPush({'type': 'debt'})['type'],
        'Bank',
        reason: 'Phải khớp với `WalletType.tuKhoa` và với migration cục bộ — '
            'ba chỗ cùng một phép ánh xạ thì mới không lệch nhau.');
  });

  test('ví Banking kéo từ server vẫn quay lại đúng chữ khi đẩy lên', () {
    expect(SyncPayloadNormalizer.walletForPush({'type': 'banking'})['type'],
        'Banking',
        reason: 'Client không TẠO được Banking, nhưng ví kéo về rồi sửa tên thì '
            'vẫn phải đẩy lại đúng loại — đổi nó sang Bank là vỡ '
            'chk_wallet_banking_link vì Id_bank_casso vẫn còn.');
  });
}
