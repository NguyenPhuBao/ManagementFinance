class UserModel {
  final String id;       // idaccount từ backend
  final String username; // username
  final String name;     // fullname
  final String email;
  final String rolename;

  /// Trạng thái tài khoản theo server: `Active`, `PendingDelete`, … JSON thiếu
  /// trường này (bộ nhớ đệm của bản cũ) đọc thành `Active`.
  final String status;

  /// Số ngày chờ xoá còn lại **lúc client nhận** — từ `/auth/login` hoặc
  /// `DELETE /auth/account`. `null` = không biết số (yêu cầu gửi từ máy khác;
  /// `/auth/profile` chưa trả trường này — CAN-LAM 19).
  final int? countdown;

  /// Lúc client nhận [countdown]. **Cục bộ**, server không có. Số ngày còn lại
  /// tính bằng `soNgayConLai` ở `core/auth/dem_nguoc_xoa.dart`.
  final DateTime? countdownNhanLuc;

  /// Loại tài khoản theo server: `Basic` | `Premium` — `type` của
  /// `/auth/login` và `/auth/profile`. Không mang hạn. Chỉ `GoiRepository` đọc,
  /// làm nhánh rơi về khi kho gói trống và `/payment/*` hỏng (spec Premium
  /// 2026-10-06 mục 6.6); không màn nào đọc thẳng. JSON thiếu (bộ nhớ đệm bản
  /// cũ) đọc thành `Basic`.
  final String loaiTaiKhoan;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.rolename = 'user',
    this.status = 'Active',
    this.countdown,
    this.countdownNhanLuc,
    this.loaiTaiKhoan = 'Basic',
  });

  /// Không phân biệt hoa thường — cùng cách `middleware/auth.js` của backend.
  bool get dangChoXoa => status.toLowerCase() == 'pendingdelete';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final status = json['status'];
    final countdown = json['countdown'];
    final nhanLuc = json['countdown_nhan_luc'];
    final type = json['type'];
    return UserModel(
      id:       json['idaccount']?.toString() ?? '',
      username: json['username']  as String? ?? '',
      name:     json['fullname']  as String? ?? '',
      email:    json['email']     as String? ?? '',
      rolename: json['rolename']  as String? ?? 'user',
      status:   status is String && status.isNotEmpty ? status : 'Active',
      countdown: countdown is num ? countdown.toInt() : null,
      countdownNhanLuc: nhanLuc is String ? DateTime.tryParse(nhanLuc) : null,
      loaiTaiKhoan: type is String && type.isNotEmpty ? type : 'Basic',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idaccount': id,
      'username':  username,
      'fullname':  name,
      'email':     email,
      'rolename':  rolename,
      'status':    status,
      'countdown': countdown,
      'countdown_nhan_luc': countdownNhanLuc?.toUtc().toIso8601String(),
      'type': loaiTaiKhoan,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? rolename,
  }) {
    return UserModel(
      id:       id ?? this.id,
      username: username ?? this.username,
      name:     name ?? this.name,
      email:    email ?? this.email,
      rolename: rolename ?? this.rolename,
      status:   status,
      countdown: countdown,
      countdownNhanLuc: countdownNhanLuc,
      loaiTaiKhoan: loaiTaiKhoan,
    );
  }

  /// Bản sao mang trạng thái chờ xoá mới. Tách khỏi [copyWith] vì ở đây `null`
  /// có nghĩa: huỷ yêu cầu xoá là **bỏ** `countdown`, không phải giữ nguyên.
  /// Riêng [loaiTaiKhoan] thì `null` = giữ nguyên (server luôn trả `type`, và
  /// không có thao tác nào "bỏ" loại tài khoản).
  UserModel voiTrangThai({
    required String status,
    int? countdown,
    DateTime? countdownNhanLuc,
    String? loaiTaiKhoan,
  }) {
    return UserModel(
      id: id,
      username: username,
      name: name,
      email: email,
      rolename: rolename,
      status: status,
      countdown: countdown,
      countdownNhanLuc: countdownNhanLuc,
      loaiTaiKhoan: loaiTaiKhoan ?? this.loaiTaiKhoan,
    );
  }
}
