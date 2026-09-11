// Regression tests for B5: cancel_purchase payment reversal.
//
// These tests verify the Dart-side model parsing for cancelled purchases
// and payment status. The SQL behavioral tests are in:
//   supabase/tests/cancel_purchase_payments_test.sql
//
// To run:
//   flutter test test/cancel_purchase_payment_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:jabnoun_erp/models/purchase.dart';
import 'package:jabnoun_erp/models/pos_finance.dart';

void main() {
  group('Purchase model — cancelled state', () {
    test('Purchase.fromMap parses status="annule" with amount_paid=0', () {
      final purchase = Purchase.fromMap({
        'id': 'p1',
        'document_number': 'ACH-2025-000001',
        'supplier_id': 's1',
        'depot_id': 'd1',
        'purchase_date': '2025-01-15',
        'status': 'annule',
        'total_ht': 100.0,
        'total_tva': 19.0,
        'total_ttc': 120.0,
        'amount_paid': 0.0,
      });
      expect(purchase.status, 'annule');
      expect(purchase.amountPaid, 0.0);
    });

    test('Purchase.fromMap parses status="partiellement_paye" correctly', () {
      final purchase = Purchase.fromMap({
        'id': 'p2',
        'document_number': 'ACH-2025-000002',
        'supplier_id': 's1',
        'depot_id': 'd1',
        'purchase_date': '2025-01-16',
        'status': 'partiellement_paye',
        'total_ht': 100.0,
        'total_tva': 19.0,
        'total_ttc': 120.0,
        'amount_paid': 50.0,
      });
      expect(purchase.status, 'partiellement_paye');
      expect(purchase.amountPaid, 50.0);
    });

    test('Purchase.fromMap parses status="paye" correctly', () {
      final purchase = Purchase.fromMap({
        'id': 'p3',
        'document_number': 'ACH-2025-000003',
        'supplier_id': 's1',
        'depot_id': 'd1',
        'purchase_date': '2025-01-17',
        'status': 'paye',
        'total_ht': 100.0,
        'total_tva': 19.0,
        'total_ttc': 120.0,
        'amount_paid': 120.0,
      });
      expect(purchase.status, 'paye');
      expect(purchase.amountPaid, 120.0);
    });
  });

  group('Payment model — purchase-linked cancelled payment', () {
    test('Payment.fromMap parses cancelled payment linked to purchase', () {
      final payment = Payment.fromMap({
        'id': 'pay1',
        'document_number': 'PAY-2025-000001',
        'payment_type': 'decaissement',
        'partner_type': 'supplier',
        'partner_id': 's1',
        'purchase_id': 'p1',
        'amount': 50.0,
        'payment_date': '2025-01-15',
        'status': 'annule',
      });
      expect(payment.status, 'annule');
      expect(payment.purchaseId, 'p1');
      expect(payment.paymentType, 'decaissement');
    });

    test('Payment.fromMap defaults status to "actif" for purchase payment', () {
      final payment = Payment.fromMap({
        'id': 'pay2',
        'document_number': 'PAY-2025-000002',
        'payment_type': 'decaissement',
        'partner_type': 'supplier',
        'partner_id': 's1',
        'purchase_id': 'p2',
        'amount': 75.0,
        'payment_date': '2025-01-16',
      });
      expect(payment.status, 'actif');
      expect(payment.purchaseId, 'p2');
    });
  });
}
