import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

/// Initialise et expose le client Supabase unique de l'application.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
    );
    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;
}
