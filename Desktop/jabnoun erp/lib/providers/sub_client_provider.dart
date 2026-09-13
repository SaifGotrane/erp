import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sub_client.dart';
import '../repositories/sub_client_repository.dart';

final subClientRepositoryProvider =
    Provider<SubClientRepository>((ref) => SubClientRepository());

final subClientListProvider =
    FutureProvider<List<SubClient>>((ref) async {
  return ref.watch(subClientRepositoryProvider).fetchAll(activeOnly: false);
});

final subClientSearchProvider = StateProvider<String>((ref) => '');

final subClientFilteredProvider = FutureProvider<List<SubClient>>((ref) async {
  final search = ref.watch(subClientSearchProvider);
  return ref.watch(subClientRepositoryProvider).fetchAll(
        search: search,
        activeOnly: false,
      );
});
