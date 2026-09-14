import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';
import '../repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

/// Émet l'état d'authentification Supabase brut (session courante).
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChange;
});

/// Employé courant (profil + rôle), reconstruit à chaque changement de session.
final currentEmployeeProvider = FutureProvider<Employee?>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  if (repo.currentUser == null) return null;
  return repo.fetchCurrentEmployee();
});

/// Ensemble des permissions "module:action" accordées à l'employé courant.
/// Un administrateur possède implicitement toutes les permissions.
final currentPermissionsProvider = FutureProvider<Set<String>>((ref) async {
  final employee = await ref.watch(currentEmployeeProvider.future);
  if (employee == null) return {};
  if (employee.isAdmin) return {'*'};

  final repo = ref.watch(authRepositoryProvider);
  final perms = await repo.fetchPermissions(employee.id);
  return perms.where((p) => p.allowed).map((p) => '${p.module}:${p.action}').toSet();
});

/// Helper pour vérifier une permission dans l'UI.
/// Usage: ref.watch(hasPermissionProvider(('articles','create')))
final hasPermissionProvider = FutureProvider.family<bool, (String module, String action)>(
  (ref, params) async {
    final perms = await ref.watch(currentPermissionsProvider.future);
    if (perms.contains('*')) return true;
    return perms.contains('${params.$1}:${params.$2}');
  },
);
