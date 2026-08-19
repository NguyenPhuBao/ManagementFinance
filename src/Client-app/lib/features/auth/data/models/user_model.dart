class UserModel {
  final String id;       // idaccount từ backend
  final String username; // username
  final String name;     // fullname
  final String email;
  final String rolename;
  /// true nếu tài khoản vừa được khôi phục tự động từ trạng thái PendingDelete
  /// khi người dùng đăng nhập lại trong thời gian ân hạn 30 ngày.
  final bool pendingDeleteCancelled;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.rolename = 'user',
    this.pendingDeleteCancelled = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:       json['idaccount']?.toString() ?? '',
      username: json['username']  as String? ?? '',
      name:     json['fullname']  as String? ?? '',
      email:    json['email']     as String? ?? '',
      rolename: json['rolename']  as String? ?? 'user',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'idaccount': id,
      'username':  username,
      'fullname':  name,
      'email':     email,
      'rolename':  rolename,
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? name,
    String? email,
    String? rolename,
    bool? pendingDeleteCancelled,
  }) {
    return UserModel(
      id:                     id ?? this.id,
      username:               username ?? this.username,
      name:                   name ?? this.name,
      email:                  email ?? this.email,
      rolename:               rolename ?? this.rolename,
      pendingDeleteCancelled: pendingDeleteCancelled ?? this.pendingDeleteCancelled,
    );
  }
}

