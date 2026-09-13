import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifie GoRouter à chaque changement d'état d'authentification afin que
/// les redirections (login <-> app) soient réévaluées automatiquement.
class RouterRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  RouterRefreshNotifier(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  void refresh() => notifyListeners();

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
