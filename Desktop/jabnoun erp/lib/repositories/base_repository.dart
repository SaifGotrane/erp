import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/errors/app_exception.dart';
import '../core/supabase/supabase_client_provider.dart';

/// Base commune pour les repositories Supabase.
/// Centralise l'accès au client et la traduction des erreurs.
abstract class BaseRepository {
  SupabaseClient get client => SupabaseService.client;

  Future<T> guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      throw mapErrorToAppException(e);
    }
  }
}
