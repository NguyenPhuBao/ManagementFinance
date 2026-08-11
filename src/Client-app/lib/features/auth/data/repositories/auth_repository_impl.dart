import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';
import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

/// AuthRepositoryImpl — lớp triển khai duy nhất, kết nối Remote + Local.
///
/// Nguyên tắc:
/// - Login / Register: bắt buộc online → lưu tokens + cache offline
/// - Logout: xóa sạch mọi token và offline cache → buộc login online lần sau
/// - checkAuthStatus: chỉ kiểm tra có accessToken không (offline-safe)
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final FlutterSecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.secureStorage,
  });

  // ─── Login online → lưu token + cache offline credential ────────────────
  @override
  Future<UserModel> login(String username, String password) async {
    final data = await remoteDataSource.login(username, password);

    // Lưu cả 2 tokens qua abstraction
    await localDataSource.saveTokens(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
    );

    final userJson = data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    // Cache thông tin offline (để app hoạt động khi mất mạng SAU KHI đã login)
    await _cacheOfflineCredentials(username, password, userJson);

    return user;
  }

  // ─── Register (chỉ online) ───────────────────────────────────────────────
  @override
  Future<UserModel> register(
    String username,
    String fullname,
    String email,
    String password,
  ) async {
    final data = await remoteDataSource.register(
      username,
      fullname,
      email,
      password,
    );

    await localDataSource.saveTokens(
      accessToken:  data['accessToken']  as String,
      refreshToken: data['refreshToken'] as String,
    );

    final userJson = data['user'] as Map<String, dynamic>;
    await _cacheOfflineCredentials(username, password, userJson);

    return UserModel.fromJson(userJson);
  }

  // ─── Logout: xóa tất cả token + offline cache ───────────────────────────
  @override
  Future<void> logout() async {
    // Xóa qua abstraction (accessToken + refreshToken)
    await localDataSource.deleteTokens();

    // Xóa offline cache → bắt buộc đăng nhập online lần sau
    await secureStorage.delete(key: AppConstants.offlineUsernameKey);
    await secureStorage.delete(key: AppConstants.offlinePasswordHashKey);
    await secureStorage.delete(key: AppConstants.offlineUserDataKey);
  }

  // ─── Kiểm tra có token không (offline-safe) ─────────────────────────────
  @override
  Future<bool> checkAuthStatus() async {
    final token = await localDataSource.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final userDataStr = await secureStorage.read(key: AppConstants.offlineUserDataKey);
    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final json = jsonDecode(userDataStr) as Map<String, dynamic>;
        return UserModel.fromJson(json);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ─── Private: cache offline credentials ─────────────────────────────────
  Future<void> _cacheOfflineCredentials(
    String username,
    String password,
    Map<String, dynamic> userJson,
  ) async {
    await secureStorage.write(
      key:   AppConstants.offlineUsernameKey,
      value: username,
    );
    await secureStorage.write(
      key:   AppConstants.offlinePasswordHashKey,
      value: _hashPassword(password),
    );
    await secureStorage.write(
      key:   AppConstants.offlineUserDataKey,
      value: jsonEncode(userJson),
    );
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
