import 'package:flowmoney/features/wallet/data/models/wallet_entity.dart';
import 'package:flowmoney/features/wallet/domain/rang_buoc_vi.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ràng buộc PostgreSQL thi hành trên bảng `wallet` bằng partial
/// unique index (đo `pg_indexes` 2026-09-10 — chúng KHÔNG hiện ở
/// `pg_constraint`, nên phép đo 2026-09-09 kết luận sai là "không có"):
///
/// - `uq_wallet_account_name_active (Idaccount, Name) WHERE Delete_at IS NULL`
///
/// Luật thứ hai từng có, `uq_wallet_saving_active` (một ví Tiết kiệm mỗi tài
/// khoản), backend bỏ ở `database/12` và client gỡ chốt ngày 2026-09-11 (G30) —
/// nhóm test của nó đi cùng. Ca "nhiều ví Tiết kiệm" nằm ở
/// `wallet_unique_constraints_test.dart`.
///
/// Client vi phạm là server trả 23505 → `UNIQUE_VIOLATION` → bản ghi bị xếp
/// **vĩnh viễn**, ví không bao giờ lên server, và mọi giao dịch trong ví ấy vỡ
/// khoá ngoại rồi thử lại mãi. Không lỗi, không log. Đây là định nghĩa duy nhất
/// của luật ấy phía client.
void main() {
  WalletEntity vi(
    String id, {
    required String name,
    String type = 'cash',
    bool isDeleted = false,
    String status = 'active',
  }) =>
      WalletEntity(
        id: id,
        idaccount: 7,
        name: name,
        type: type,
        balance: 0,
        isDeleted: isDeleted,
        status: status,
        updatedAt: DateTime(2026, 9, 10),
      );

  group('trùng tên ví', () {
    test('tên giống hệt thì trùng', () {
      final co = [vi('a', name: 'Tiền mặt')];
      expect(viTrungTen(co, 'Tiền mặt')?.id, 'a');
    });

    test('khác hoa/thường và khoảng trắng thừa vẫn trùng', () {
      final co = [vi('a', name: 'Tiền mặt')];
      expect(viTrungTen(co, '  tiền   MẶT '), isNotNull,
          reason: 'Server so khớp chính xác từng ký tự, nên client SIẾT HƠN là '
              'an toàn; siết bằng đúng phép chuẩn hoá của tên danh mục để dự '
              'án chỉ có một định nghĩa "hai tên là một".');
    });

    test('tên khác thì không trùng', () {
      final co = [vi('a', name: 'Tiền mặt')];
      expect(viTrungTen(co, 'Tiền mặt 2'), isNull);
    });

    test('ví đã xoá mềm không giữ chỗ tên', () {
      final co = [vi('a', name: 'Tiền mặt', isDeleted: true)];
      expect(viTrungTen(co, 'Tiền mặt'), isNull,
          reason: 'Index phía server là partial `WHERE Delete_at IS NULL`; '
              'chặn theo hàng đã xoá là từ chối một tên server cho phép.');
    });

    test('ví lưu trữ VẪN giữ chỗ tên', () {
      final co = [vi('a', name: 'Tiền mặt', status: 'inactive')];
      expect(viTrungTen(co, 'Tiền mặt'), isNotNull,
          reason: 'Lưu trữ là đóng băng, không phải xoá: hàng vẫn còn '
              '`Delete_at IS NULL` trên server nên vẫn nằm trong index.');
    });

    test('sửa ví thì bỏ qua chính nó', () {
      final co = [vi('a', name: 'Tiền mặt')];
      expect(viTrungTen(co, 'Tiền mặt', boQuaId: 'a'), isNull,
          reason: 'Không có ngoại lệ này thì màn Sửa ví từ chối cả việc lưu '
              'mà không đổi tên.');
    });
  });

}
