import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> cacheUser(UserModel user);
  UserModel? getCachedUser();
  Future<void> saveTokens({required String token, String? refreshToken});
  String? getAuthToken();
  Future<void> clearAuthData();
}

@Injectable(as: AuthLocalDataSource)
class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  @override
  Future<void> cacheUser(UserModel user) async {
    // Store user data - in a real app use Hive or JSON encode
    await LocalStorage.setString('cached_user_id', user.id);
    await LocalStorage.setString('cached_user_email', user.email);
    await LocalStorage.setString('cached_user_name', user.name);
  }

  @override
  UserModel? getCachedUser() {
    final id = LocalStorage.getString('cached_user_id');
    final email = LocalStorage.getString('cached_user_email');
    final name = LocalStorage.getString('cached_user_name');

    if (id == null || email == null || name == null) return null;

    return UserModel(
      id: id,
      email: email,
      name: name,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> saveTokens({
    required String token,
    String? refreshToken,
  }) async {
    await LocalStorage.setString(AppConstants.authTokenKey, token);
    if (refreshToken != null) {
      await LocalStorage.setString(AppConstants.refreshTokenKey, refreshToken);
    }
  }

  @override
  String? getAuthToken() {
    return LocalStorage.getString(AppConstants.authTokenKey);
  }

  @override
  Future<void> clearAuthData() async {
    await LocalStorage.remove(AppConstants.authTokenKey);
    await LocalStorage.remove(AppConstants.refreshTokenKey);
    await LocalStorage.remove('cached_user_id');
    await LocalStorage.remove('cached_user_email');
    await LocalStorage.remove('cached_user_name');
  }
}
