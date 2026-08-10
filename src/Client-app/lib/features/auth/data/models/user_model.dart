class UserModel {
  final String id;       // idaccount từ backend
  final String username; // username
  final String name;     // fullname
  final String email;
  final String rolename;

  UserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.email,
    this.rolename = 'user',
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
}
