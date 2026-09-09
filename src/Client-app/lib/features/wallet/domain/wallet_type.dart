/// Loại ví — **nguồn duy nhất** cho cả nhãn, biểu tượng, khoá lưu cục bộ và
/// khoá đẩy lên server.
///
/// ## Vì sao chỉ ba loại chọn được
///
/// PostgreSQL có ràng buộc, đo thẳng trên CSDL ngày 2026-09-09:
///
/// ```
/// chk_wallet_type CHECK (Type = ANY (ARRAY['Cash','Bank','Saving','Banking']))
/// ```
///
/// Trước bản này, giao diện cho chọn `cash | bank | ewallet | debt`, hardcode
/// **trùng lặp** ở `wallet_add_page` và `wallet_edit_page`, còn
/// `wallet_list_page` lại biết thêm cả `investment` — bốn danh sách, không cái
/// nào khớp cái nào. Hai giá trị `ewallet` và `debt` không nằm trong ràng buộc,
/// nên ví tạo bằng chúng **đẩy lên là vỡ CHECK** và kẹt hàng đợi vĩnh viễn, mà
/// không một dòng nào trên màn hình nói ra.
///
/// [banking] vẫn nằm trong enum vì server có thể trả về nó, nhưng **không**
/// nằm trong [chonDuoc]: ràng buộc `chk_wallet_banking_link` đòi nó đi kèm
/// `Id_bank_casso`, thứ chỉ luồng liên kết ngân hàng mới tạo ra.
///
/// ## Vì sao tệp này KHÔNG import Flutter
///
/// `sync_payload_normalizer.dart` — tầng hợp đồng giữa client và server —
/// không import gì cả, và đó là tính chất đáng giữ. Nó cần đúng phép ánh xạ
/// khoá ở đây, nên tệp này phải là Dart thuần. Biểu tượng nằm riêng ở
/// `presentation/widgets/wallet_type_icon.dart`.
enum WalletType {
  cash,
  bank,
  saving,

  /// Ví sinh ra từ luồng liên kết ngân hàng. **Chỉ đọc** với client.
  banking;

  /// Ba loại người dùng được chọn khi tạo hoặc sửa ví.
  static const List<WalletType> chonDuoc = [cash, bank, saving];

  /// Khoá lưu trong SQLite — chữ thường.
  String get khoa => name;

  /// Khoá gửi lên server. Bốn chuỗi này là **toàn bộ** những gì
  /// `chk_wallet_type` cho phép; đừng thêm giá trị nào không có ở đó.
  String get khoaGuiLen => switch (this) {
        WalletType.cash => 'Cash',
        WalletType.bank => 'Bank',
        WalletType.saving => 'Saving',
        WalletType.banking => 'Banking',
      };

  String get nhan => switch (this) {
        WalletType.cash => 'Tiền mặt',
        WalletType.bank => 'Ngân hàng',
        WalletType.saving => 'Tiết kiệm',
        WalletType.banking => 'Ngân hàng liên kết',
      };

  /// Đọc một khoá bất kỳ về loại ví.
  ///
  /// Giá trị **không nhận ra thì về [cash]**, cố ý không giữ nguyên: giữ nguyên
  /// là để nó đi thẳng lên server rồi vỡ `chk_wallet_type`, đúng cái bẫy mà tệp
  /// này sinh ra để đóng. Về tiền mặt thì ví vẫn đồng bộ được và người dùng sửa
  /// lại được bằng một cú chạm.
  ///
  /// Hai loại đã bỏ đọc thành [bank] chứ không phải [cash], và migration cục bộ
  /// chuyển hàng cũ sang đúng loại ấy — **hai chỗ phải khớp nhau**.
  static WalletType tuKhoa(String? khoa) => switch (khoa?.toLowerCase()) {
        'cash' => WalletType.cash,
        'bank' => WalletType.bank,
        'saving' => WalletType.saving,
        'banking' => WalletType.banking,
        // Ví điện tử giữ tiền dưới dạng điện tử, và thẻ tín dụng gắn với ngân
        // hàng — cả hai gần "ngân hàng" hơn "tiền mặt".
        'ewallet' => WalletType.bank,
        'debt' => WalletType.bank,
        _ => WalletType.cash,
      };
}
