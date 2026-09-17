/// Trạng thái ví — **nguồn duy nhất** cho nhãn, khoá lưu cục bộ, khoá đẩy lên,
/// và phép hỏi "ví này còn dùng được không".
///
/// ## Vì sao cần tệp này
///
/// Cột `status` đã có ở **cả hai đầu** từ trước tính năng lưu trữ ví, nhưng
/// viết khác nhau: SQLite mặc định `'active'` (chữ thường, xem
/// `wallets_table.dart`), còn PostgreSQL có ràng buộc:
///
/// ```
/// chk_wallet_status CHECK (Status = ANY (ARRAY['Active','Inactive']))
/// ```
///
/// Cột đi qua đồng bộ **hai chiều** từ 2026-09-14 (G28 đóng): [khoaGuiLen] là
/// thứ `sync_payload_normalizer.dart` gửi lên, [tuKhoa] + [khoa] là thứ nhánh
/// kéo về lưu xuống. Hai từ vựng phải dịch qua lại ở đúng hai chỗ ấy và không
/// đâu khác.
///
/// ⚠️ **Lý do lịch sử, giữ vì nó giải thích hình dạng hôm nay:** trước ngày ấy
/// `status` là cột **cục bộ** và [khoaGuiLen] không được dùng ở đâu ngoài
/// test. Lược đồ PostgreSQL khi ấy tự mâu thuẫn ở đúng cột này — CHECK cho
/// phép `'Inactive'` trong khi kiểu cột là `varchar(7)`, chuỗi ấy dài **8 ký
/// tự** — nên ví lưu trữ đẩy lên là **kẹt hàng đợi đẩy**, đo được trên máy ảo
/// ngày 2026-09-10. Tối cùng ngày CSDL dev áp `database/7` và cột nới lên
/// `varchar(20)`; việc nối lại người dùng chốt để sau, và làm ngày 2026-09-14.
/// Đo lại hôm ấy: `varchar(20)`, `NOT NULL`, `DEFAULT 'Active'`.
///
/// ⚠️ Máy chủ nào **chưa áp `database/7`** vẫn `varchar(7)` và sẽ từ chối
/// `'Inactive'` — ví lưu trữ kẹt hàng đợi đẩy vĩnh viễn, im lặng. Đó là thứ
/// duy nhất còn có thể làm G28 hỏng, và client không chặn trước được.
/// Xem `docs/superpowers/backend/DA-XONG/WALLET_STATUS_COLUMN_WIDTH.md`.
///
/// ## Vì sao tệp này KHÔNG import Flutter
///
/// Cùng lý do với `wallet_type.dart`: nó được `wallet_dao.dart` và tầng đồng
/// bộ dùng tới — trong đó có `sync_payload_normalizer.dart`, tầng hợp đồng
/// giữa client và server, thứ không import gì cả. Giữ Dart thuần là giữ khả
/// năng ấy, và từ G28 thì đó không còn là dự phòng mà là chỗ dùng thật.
///
/// ## Lưu trữ nghĩa là gì
///
/// **Đóng băng**, không phải xoá. Ví lưu trữ biến khỏi mọi bộ chọn ví, không
/// cộng vào tổng tài sản, và hai bộ chạy tự động (trả hoá đơn, nạp mục tiêu)
/// bỏ qua nó. Lịch sử giao dịch cũ **không đụng tới**, và phép loại khỏi tổng
/// là **suy ra** chứ không ghi đè `includeInTotal` — nên bỏ lưu trữ là mọi con
/// số cũ tự quay lại.
enum WalletStatus {
  hoatDong,
  luuTru;

  /// Khoá lưu trong SQLite — chữ thường, khớp mặc định của cột.
  String get khoa => switch (this) {
        WalletStatus.hoatDong => 'active',
        WalletStatus.luuTru => 'inactive',
      };

  /// Khoá gửi lên server. Hai chuỗi này là **toàn bộ** những gì
  /// `chk_wallet_status` cho phép; đừng thêm giá trị nào không có ở đó.
  String get khoaGuiLen => switch (this) {
        WalletStatus.hoatDong => 'Active',
        WalletStatus.luuTru => 'Inactive',
      };

  String get nhan => switch (this) {
        WalletStatus.hoatDong => 'Đang hoạt động',
        WalletStatus.luuTru => 'Đã lưu trữ',
      };

  /// Đọc một khoá bất kỳ về trạng thái ví.
  ///
  /// `null`, chuỗi rỗng và giá trị lạ đều về [hoatDong], vì hai lý do khác
  /// nhau và **cả hai đều quan trọng**:
  ///
  /// 1. Server im lặng về cột này nghĩa là **chưa biết**, không phải "hãy lưu
  ///    trữ ví". Đọc thành [luuTru] là mọi ví của người dùng lặng lẽ biến khỏi
  ///    các bộ chọn ngay lượt pull đầu tiên gặp một payload thiếu khoá — cùng
  ///    bài học với `include_in_total` và `idgoal`.
  /// 2. Giá trị lạ **không** được giữ nguyên: giữ nguyên là để nó đi thẳng lên
  ///    server rồi vỡ `chk_wallet_status`, đúng cái bẫy tệp này đóng.
  static WalletStatus tuKhoa(String? khoa) =>
      switch (khoa?.toLowerCase().trim()) {
        'inactive' => WalletStatus.luuTru,
        _ => WalletStatus.hoatDong,
      };

  /// Phép hỏi **duy nhất** cho "ví này còn dùng được không".
  ///
  /// Mọi bộ chọn ví, phép cộng tổng tài sản, và hai bộ chạy tự động đều phải
  /// đi qua đây thay vì tự so chuỗi — so chuỗi là chép luật ra chỗ thứ hai,
  /// rồi một chỗ quên `.toLowerCase()` là ví lưu trữ hiện lại, im lặng.
  static bool laHoatDong(String? khoa) => tuKhoa(khoa) == WalletStatus.hoatDong;
}
