import '../datasources/auth_local_data_source.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/user_model.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final user = await remoteDataSource.login(email, password);
      final token = await remoteDataSource.getMockToken();
      await localDataSource.saveToken(token);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    try {
      final user = await remoteDataSource.register(name, email, password);
      final token = await remoteDataSource.getMockToken();
      await localDataSource.saveToken(token);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await localDataSource.deleteToken();
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await localDataSource.getToken();
    return token != null && token.isNotEmpty;
  }
}
