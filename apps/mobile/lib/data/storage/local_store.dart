import "package:shared_preferences/shared_preferences.dart";

class LocalStore {
  static const _keyBaseUrl = "base_url";
  static const _keyToken = "api_token";
  static const _keyUndoToken = "undo_token";
  static const _keyDraftPolicy = "draft_policy";
  static const _keyTimezone = "default_timezone";

  Future<String?> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl);
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, value);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  Future<void> setToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, value);
  }

  Future<String?> getUndoToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUndoToken);
  }

  Future<void> setUndoToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUndoToken, value);
  }

  Future<void> clearUndoToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUndoToken);
  }

  Future<String?> getDraftPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyDraftPolicy);
  }

  Future<void> setDraftPolicy(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDraftPolicy, value);
  }

  Future<String?> getDefaultTimezone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyTimezone);
  }

  Future<void> setDefaultTimezone(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTimezone, value);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyBaseUrl);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUndoToken);
    await prefs.remove(_keyDraftPolicy);
    await prefs.remove(_keyTimezone);
  }
}
