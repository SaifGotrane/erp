import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Boîte de dialogue de confirmation pour les opérations sensibles
/// (validation, annulation, clôture de caisse, ajustement de stock...).
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  String cancelLabel = 'Annuler',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.navy)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: danger ? AppColors.danger : AppColors.primary,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Affiche une notification (succès/erreur) en bas de l'écran.
void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: isError ? AppColors.danger : AppColors.navy,
      content: Text(message),
    ),
  );
}
