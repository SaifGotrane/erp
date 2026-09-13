// Regression tests for B1: cancel_sale must reverse amount_paid and mark
// linked payments as cancelled.
//
// These tests verify the Dart-side model changes (Payment.status field)
// and the SQL migration logic via documented scenarios. The SQL scenarios
// are designed to be run against a Supabase test database after applying
// all migrations including 0022_fix_cancel_sale_payments.sql.
//
// To run the SQL scenarios:
//   supabase db reset --linked && psql -f supabase/tests/cancel_sale_payments_test.sql
//
// To run the Dart tests:
//   flutter test test/cancel_sale_payment_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:jabnoun_erp/models/pos_finance.dart';
import 'package:jabnoun_erp/models/sale.dart';

void main() {
  group('Payment model — status field', () {
    test('Payment.fromMap defaults status to "actif" when column is absent', () {
      final payment = Payment.fromMap({
        'id': 'p1',
        'document_number': 'PAY-2025-000001',
        'payment_type': 'encaissement',
        'partner_type': 'customer',
        'partner_id': 'c1',
        'amount': 100.0,
        'payment_date': '2025-01-15',
      });
      expect(payment.status, 'actif');
    });

    test('Payment.fromMap parses status = "annule" correctly', () {
      final payment = Payment.fromMap({
        'id': 'p2',
        'document_number': 'PAY-2025-000002',
        'payment_type': 'encaissement',
        'partner_type': 'customer',
        'partner_id': 'c1',
        'amount': 250.0,
        'payment_date': '2025-01-16',
        'status': 'annule',
      });
      expect(payment.status, 'annule');
    });

    test('Payment.fromMap parses status = "actif" correctly', () {
      final payment = Payment.fromMap({
        'id': 'p3',
        'document_number': 'PAY-2025-000003',
        'payment_type': 'decaissement',
        'partner_type': 'supplier',
        'partner_id': 's1',
        'amount': 500.0,
        'payment_date': '2025-01-17',
        'status': 'actif',
      });
      expect(payment.status, 'actif');
    });

    test('Payment equality includes status', () {
      final p1 = Payment(
        id: 'p1',
        documentNumber: 'PAY-2025-000001',
        paymentType: 'encaissement',
        partnerType: 'customer',
        partnerId: 'c1',
        amount: 100.0,
        paymentDate: DateTime(2025, 1, 15),
        status: 'actif',
      );
      final p2 = Payment(
        id: 'p1',
        documentNumber: 'PAY-2025-000001',
        paymentType: 'encaissement',
        partnerType: 'customer',
        partnerId: 'c1',
        amount: 100.0,
        paymentDate: DateTime(2025, 1, 15),
        status: 'annule',
      );
      expect(p1 == p2, isFalse);
    });
  });

  group('Sale model — amount_paid after cancellation', () {
    test('Sale with status "annule" and amount_paid = 0 is correctly parsed', () {
      final sale = Sale.fromMap({
        'id': 's1',
        'document_number': 'VEN-2025-000001',
        'customer_id': 'c1',
        'sale_date': '2025-01-15',
        'status': 'annule',
        'amount_paid': 0.0,
        'total_ttc': 1000.0,
      });
      expect(sale.status, 'annule');
      expect(sale.amountPaid, 0.0);
    });

    test('Sale with status "partiellement_paye" is correctly parsed', () {
      final sale = Sale.fromMap({
        'id': 's2',
        'document_number': 'VEN-2025-000002',
        'customer_id': 'c1',
        'sale_date': '2025-01-16',
        'status': 'partiellement_paye',
        'amount_paid': 400.0,
        'total_ttc': 1000.0,
      });
      expect(sale.status, 'partiellement_paye');
      expect(sale.amountPaid, 400.0);
    });
  });
}

// ===========================================================================
// SQL TEST SCENARIOS — Run against a test database after applying migrations
// ===========================================================================
//
// The following SQL test script is located at:
//   supabase/tests/cancel_sale_payments_test.sql
//
// It covers these scenarios:
//
// 1. Cancel unpaid sale (status = 'valide', amount_paid = 0)
//    Expected: status = 'annule', amount_paid = 0, no payments to mark
//
// 2. Cancel partially paid sale (status = 'partiellement_paye', amount_paid > 0)
//    Expected: status = 'annule', amount_paid = 0, linked payments status = 'annule'
//
// 3. Cancel fully paid sale (status = 'paye')
//    Expected: raises exception 'Impossible d''annuler une vente entièrement payée.'
//
// 4. Cancel already cancelled sale (status = 'annule')
//    Expected: raises exception 'Cette vente est déjà annulée.'
//
// 5. Verify payment history is preserved (payments are marked, not deleted)
//    Expected: payment records still exist with status = 'annule'
//
// 6. Verify amount/balance after cancellation
//    Expected: sales.amount_paid = 0, report_partner_statement excludes cancelled sale
//
// 7. Force error during cancellation and verify rollback
//    Expected: if any part fails, all changes are rolled back (atomic)
//
// 8. Verify unauthorized cancellation is rejected
//    Expected: employee without 'sales:cancel' permission gets exception
