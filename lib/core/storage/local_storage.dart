import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get _instance {
    if (_prefs == null) {
      throw Exception(
        'LocalStorage not initialized. Call LocalStorage.init() first.',
      );
    }
    return _prefs!;
  }

  // String
  static Future<bool> setString(String key, String value) async {
    return _instance.setString(key, value);
  }

  static String? getString(String key) {
    return _instance.getString(key);
  }

  // Int
  static Future<bool> setInt(String key, int value) async {
    return _instance.setInt(key, value);
  }

  static int? getInt(String key) {
    return _instance.getInt(key);
  }

  // Bool
  static Future<bool> setBool(String key, bool value) async {
    return _instance.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _instance.getBool(key);
  }

  // Double
  static Future<bool> setDouble(String key, double value) async {
    return _instance.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _instance.getDouble(key);
  }

  // Remove
  static Future<bool> remove(String key) async {
    return _instance.remove(key);
  }

  // Clear all
  static Future<bool> clear() async {
    return _instance.clear();
  }

  // Check existence
  static bool containsKey(String key) {
    return _instance.containsKey(key);
  }
}
