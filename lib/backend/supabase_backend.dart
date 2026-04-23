import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBackend {
  static bool _initialized = false;

  static String get _url => dotenv.maybeGet('SUPABASE_URL', fallback: '') ?? '';
  static String get _publishableKey => dotenv.maybeGet('SUPABASE_PUBLISHABLE_KEY', fallback: '') ?? '';

  static bool get isConfigured =>
      _url.isNotEmpty &&
      _publishableKey.isNotEmpty &&
      !_url.contains('your-project') &&
      !_publishableKey.contains('your_key_here');

  static Future<void> initialize() async {
    if (!dotenv.isInitialized) {
      await dotenv.load(fileName: '.env', isOptional: true);
    }
    if (!isConfigured || _initialized) return;

    await Supabase.initialize(
      url: _url,
      anonKey: _publishableKey,
    );

    _initialized = true;
  }

  static SupabaseClient? get client {
    if (!_initialized || !isConfigured) return null;
    return Supabase.instance.client;
  }
}
