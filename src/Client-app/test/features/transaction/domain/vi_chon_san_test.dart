import 'package:flowmoney/features/transaction/domain/vi_chon_san.dart';
import 'package:flutter_test/flutter_test.dart';

/// Luật chọn sẵn ví khi mở trang thêm giao dịch.
///
/// Trước bản này trang ấy lấy `_wallets.first` làm ví nguồn, và `getAll` sắp
/// theo `updatedAt DESC` — nên ví được chọn sẵn là ví **vừa bị đổi gần nhất**,
/// không phải ví mặc định. Cờ "Ví mặc định" có phụ đề *"Tự động chọn khi ghi
/// chép giao dịch"* trong thiết kế Stitch, nhưng ngoài chính vùng ví thì
/// `getDefault` không được gọi ở đâu trong `lib/`: cờ được đặt, được đồng bộ,
/// được vẽ badge "MẶC ĐỊNH", và không có tác dụng nào.
///
/// Tách thành hàm thuần để test được ở đây: trang thêm giao dịch là một
/// `StatefulWidget` 800 dòng, còn luật thì chỉ có mấy dòng.
class _Vi {
  const _Vi(this.id, {this.macDinh = false});
  final String id;
  final bool macDinh;
}

void main() {
  ViChonSan<_Vi> chon(List<_Vi> ds) =>
      chonViChonSan(ds, laMacDinh: (v) => v.macDinh);

  test('ví mặc định KHÔNG ở đầu danh sách vẫn được chọn làm ví nguồn', () {
    // Ca phân biệt được hai cách cài đặt: `.first` trả 'a', luật đúng trả 'c'.
    // Thứ tự này là thứ tự thật của `getAll` — ví mặc định không hề được ưu
    // tiên lên đầu ở mọi bộ chọn ví trong app.
    final r = chon(const [_Vi('a'), _Vi('b'), _Vi('c', macDinh: true)]);

    expect(r.nguon?.id, 'c',
        reason: 'Cờ mặc định phải quyết định ví nguồn. Đây là toàn bộ mục đích '
            'của cờ ấy theo thiết kế, và là chỗ nó chưa từng có tác dụng.');
  });

  test('không ví nào mặc định thì lấy ví đầu danh sách', () {
    final r = chon(const [_Vi('a'), _Vi('b')]);

    expect(r.nguon?.id, 'a',
        reason: 'Không có cờ thì giữ hành vi cũ, không được để trống — trang '
            'thêm giao dịch chặn lưu khi chưa chọn ví.');
  });

  test('ví đích không được trùng ví nguồn khi ví mặc định ở giữa danh sách', () {
    // Chốt chống hồi quy do CHÍNH bản sửa này có thể sinh ra: luật cũ lấy
    // `_wallets[1]` làm ví đích một cách vô điều kiện. Đổi ví nguồn sang ví
    // mặc định mà giữ nguyên chỉ số 1 là khoản chuyển tiền có ví nguồn trùng
    // ví đích — chuyển tiền vào chính nó.
    final r = chon(const [_Vi('a'), _Vi('b', macDinh: true), _Vi('c')]);

    expect(r.nguon?.id, 'b');
    expect(r.dich?.id, isNot('b'),
        reason: 'Ví đích phải là ví KHÁC ví nguồn, không phải ví ở chỉ số 1.');
  });

  test('danh sách rỗng thì cả hai đều trống', () {
    final r = chon(const []);

    expect(r.nguon, isNull);
    expect(r.dich, isNull);
  });

  test('chỉ có một ví thì ví đích trùng ví nguồn, như trước', () {
    // Hành vi cũ, cố ý giữ: trang thêm giao dịch tự chặn khoản chuyển khi chỉ
    // có một ví, nên không cần luật thứ hai ở đây.
    final r = chon(const [_Vi('a')]);

    expect(r.nguon?.id, 'a');
    expect(r.dich?.id, 'a');
  });
}
