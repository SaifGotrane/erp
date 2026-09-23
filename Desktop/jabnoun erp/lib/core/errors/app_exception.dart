import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Exception métier avec message français prêt à afficher à l'utilisateur.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Traduit les erreurs techniques (Postgrest/Supabase) en messages français
/// compréhensibles. Ne jamais afficher les erreurs brutes de la base.
AppException mapErrorToAppException(Object error) {
  if (error is AppException) return error;
  debugPrint('Erreur applicative: $error');

  if (error is AuthException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return const AppException('Email ou mot de passe incorrect.');
    }
    if (msg.contains('email not confirmed')) {
      return const AppException('Adresse email non confirmée.');
    }
    return const AppException('Une erreur est survenue. Veuillez réessayer.');
  }

  if (error is PostgrestException) {
    final code = error.code;
    final msg = error.message.toLowerCase();

    if (code == '23505' || msg.contains('duplicate key')) {
      if (msg.contains('reference')) {
        return const AppException('La référence article existe déjà.');
      }
      if (msg.contains('code')) {
        return const AppException('Ce code existe déjà.');
      }
      return const AppException('Cet enregistrement existe déjà.');
    }
    if (code == '23503') {
      if (msg.contains('articles') && msg.contains('category')) {
        return const AppException('Impossible de supprimer cette catégorie car elle est utilisée par un ou plusieurs articles.');
      }
      return const AppException(
        'Impossible d\'effectuer cette opération : des données liées existent.',
      );
    }
    if (code == '23514') {
      return const AppException(
        'Les données saisies ne respectent pas les règles de gestion.',
      );
    }
    if (code == '42501' ||
        msg.contains('permission denied') ||
        msg.contains('row-level security')) {
      return const AppException(
        'Vous n\'avez pas l\'autorisation d\'effectuer cette opération.',
      );
    }
    if (msg.contains('insufficient_stock') ||
        msg.contains('stock insuffisant')) {
      return const AppException('Stock insuffisant pour cet article.');
    }
    if (msg.contains('already_validated')) {
      return const AppException('Ce document a déjà été validé.');
    }
    if (msg.contains('session_already_open')) {
      return const AppException('Cette caisse est déjà ouverte.');
    }
    if (msg.contains('session_already_closed')) {
      return const AppException('Cette caisse a déjà été clôturée.');
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
      return const AppException('Impossible de contacter le serveur. Vérifiez votre connexion.');
    }
    // Les exceptions métier levées côté base (RAISE EXCEPTION dans les
    // fonctions RPC) portent le code P0001 et contiennent déjà un message
    // français prêt à afficher (ex: "Stock insuffisant...", "Coût
    // indisponible...", "Seul un brouillon peut être validé..."). On les
    // affiche directement plutôt que de les masquer par un message générique.
    if (code == 'P0001' && error.message.trim().isNotEmpty) {
      return AppException(error.message.trim());
    }
    return const AppException('Une erreur est survenue lors de l’opération.');
  }

  return const AppException('Une erreur est survenue. Veuillez réessayer.');
}
