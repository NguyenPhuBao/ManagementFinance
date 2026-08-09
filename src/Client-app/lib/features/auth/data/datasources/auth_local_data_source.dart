import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';

abstract class AuthLocalDataSource {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final FlutterSecureStorage secureStorage;

  AuthLocalDataSourceImpl({required this.secureStorage});

  @override
  Future<void> saveToken(String token) async {
    await secureStorage.write(key: AppConstants.accessTokenKey, value: token);
  }

  @override
  Future<String?> getToken() async {
    return await secureStorage.read(key: AppConstants.accessTokenKey);
  }

  @override
  Future<void> deleteToken() async {
    await secureStorage.delete(key: AppConstants.accessTokenKey);
  }
}
