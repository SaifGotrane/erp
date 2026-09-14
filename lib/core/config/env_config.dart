import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Accès centralisé aux variables d'environnement (.env).
class EnvConfig {
  EnvConfig._();

  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT_REF') &&
      !supabaseAnonKey.contains('YOUR_ANON_KEY');
}
