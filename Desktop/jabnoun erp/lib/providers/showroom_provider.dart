import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/showroom.dart';
import '../repositories/showroom_repository.dart';

final showroomRepositoryProvider = Provider<ShowroomRepository>((ref) => ShowroomRepository());

final showroomSearchProvider = StateProvider<String>((ref) => '');

final showroomListProvider = FutureProvider<List<Showroom>>((ref) async {
  final search = ref.watch(showroomSearchProvider);
  return ref.watch(showroomRepositoryProvider).fetchAll(search: search);
});

final activeShowroomsProvider = FutureProvider<List<Showroom>>((ref) async {
  return ref.watch(showroomRepositoryProvider).fetchAll(activeOnly: true);
});
