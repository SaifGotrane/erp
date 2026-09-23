import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee.dart';
import 'base_repository.dart';

class AuthRepository extends BaseRepository {
  Session? get currentSession => client.auth.currentSession;
  User? get currentUser => client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) {
    return guard(() async {
      await client.auth.signInWithPassword(email: email, password: password);
    });
  }

  Future<void> signOut() {
    return guard(() => client.auth.signOut());
  }

  Future<void> resetPasswordForEmail(String email) {
    return guard(() => client.auth.resetPasswordForEmail(email));
  }

  /// Charge le profil employé lié à l'utilisateur connecté.
  Future<Employee?> fetchCurrentEmployee() {
    return guard(() async {
      final uid = currentUser?.id;
      if (uid == null) return null;
      final data = await client.from('employees').select().eq('id', uid).maybeSingle();
      if (data == null) return null;
      return Employee.fromMap(data);
    });
  }

  /// Charge toutes les permissions de l'employé (module/action -> autorisé).
  Future<List<EmployeePermission>> fetchPermissions(String employeeId) {
    return guard(() async {
      final data = await client
          .from('employee_permissions')
          .select()
          .eq('employee_id', employeeId);
      return (data as List)
          .map((e) => EmployeePermission.fromMap(e as Map<String, dynamic>))
          .toList();
    });
  }
}
