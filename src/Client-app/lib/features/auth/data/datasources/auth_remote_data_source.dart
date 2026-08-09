import '../models/user_model.dart';
import 'package:dio/dio.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> login(String email, String password);
  Future<UserModel> register(String name, String email, String password);
  Future<String> getMockToken();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final Dio dio;

  AuthRemoteDataSourceImpl({required this.dio});

  @override
  Future<UserModel> login(String email, String password) async {
    // TODO: Remote integration when backend ready
    // final response = await dio.post('/auth/login', data: {'email': email, 'password': password});
    
    // MOCK DELAY
    await Future.delayed(const Duration(seconds: 2));
    
    if (email == 'test@abc.com' && password == '123456') {
      return UserModel(id: '1', name: 'John Doe', email: email);
    } else {
      throw Exception('Email hoặc mật khẩu không đúng!');
    }
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    // MOCK DELAY
    await Future.delayed(const Duration(seconds: 2));
    return UserModel(id: '2', name: name, email: email);
  }

  @override
  Future<String> getMockToken() async {
    return 'mock_jwt_token_here_12345';
  }
}
