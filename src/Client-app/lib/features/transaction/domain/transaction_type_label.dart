/// Nhãn hiển thị cho `transactions.type` khi dòng giao dịch không có ghi chú.
///
/// Tách riêng vì trang sổ giao dịch từng viết `type == 'chi' ? 'Khoản chi'
/// : 'Khoản thu'` — hai nhánh cho ba loại — nên khoản chuyển ví không ghi chú
/// hiện thành "Khoản thu".
String transactionTypeLabel(String type) => switch (type) {
      'chi' => 'Khoản chi',
      'thu' => 'Khoản thu',
      'transfer' => 'Chuyển khoản',
      _ => 'Giao dịch',
    };
