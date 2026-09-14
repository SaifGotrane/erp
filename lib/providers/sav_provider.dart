import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sav_ticket.dart';
import '../repositories/sav_repository.dart';

final savRepositoryProvider = Provider<SavRepository>((ref) => SavRepository());

final savSearchProvider = StateProvider<String>((ref) => '');
final savStatusFilterProvider = StateProvider<String?>((ref) => null);
final savCustomerFilterProvider = StateProvider<String?>((ref) => null);
final savSupplierFilterProvider = StateProvider<String?>((ref) => null);
final savArticleFilterProvider = StateProvider<String?>((ref) => null);
final savDateFromFilterProvider = StateProvider<DateTime?>((ref) => null);
final savDateToFilterProvider = StateProvider<DateTime?>((ref) => null);

final savTicketListProvider = FutureProvider<List<SavTicket>>((ref) async {
  final search = ref.watch(savSearchProvider);
  final status = ref.watch(savStatusFilterProvider);
  final customerId = ref.watch(savCustomerFilterProvider);
  final supplierId = ref.watch(savSupplierFilterProvider);
  final articleId = ref.watch(savArticleFilterProvider);
  final from = ref.watch(savDateFromFilterProvider);
  final to = ref.watch(savDateToFilterProvider);
  return ref.watch(savRepositoryProvider).fetchAll(
        search: search,
        status: status,
        customerId: customerId,
        supplierId: supplierId,
        articleId: articleId,
        from: from,
        to: to,
      );
});

final savTicketNotesProvider = FutureProvider.family<List<SavTicketNote>, String>((ref, ticketId) {
  return ref.watch(savRepositoryProvider).fetchNotes(ticketId);
});
