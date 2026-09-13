import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Badge de statut compact, style ERP (pas de couleurs criardes).
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const StatusBadge({super.key, required this.label, required this.color, required this.background});

  factory StatusBadge.active(bool active) {
    return active
        ? const StatusBadge(label: 'Actif', color: AppColors.success, background: AppColors.successBg)
        : const StatusBadge(label: 'Inactif', color: AppColors.textMuted, background: AppColors.surfaceAlt);
  }

  factory StatusBadge.docStatus(String status) {
    switch (status) {
      case 'valide':
        return const StatusBadge(label: 'Validé', color: AppColors.success, background: AppColors.successBg);
      case 'livre':
        return const StatusBadge(label: 'Livré', color: AppColors.success, background: AppColors.successBg);
      case 'paye':
        return const StatusBadge(label: 'Payé', color: AppColors.primary, background: AppColors.primaryLight);
      case 'partiellement_paye':
        return const StatusBadge(label: 'Partiellement payé', color: AppColors.warning, background: AppColors.warningBg);
      case 'impaye':
        return const StatusBadge(label: 'Impayé', color: AppColors.danger, background: AppColors.dangerBg);
      case 'annule':
        return const StatusBadge(label: 'Annulé', color: AppColors.danger, background: AppColors.dangerBg);
      default:
        return const StatusBadge(label: 'Brouillon', color: AppColors.textMuted, background: AppColors.surfaceAlt);
    }
  }

  factory StatusBadge.sav(String status) {
    switch (status) {
      case 'ouvert':
        return const StatusBadge(label: 'Ouvert', color: AppColors.danger, background: AppColors.dangerBg);
      case 'en_cours':
        return const StatusBadge(label: 'En cours', color: AppColors.warning, background: AppColors.warningBg);
      case 'en_attente_fournisseur':
        return const StatusBadge(label: 'En attente fournisseur', color: AppColors.warning, background: AppColors.warningBg);
      case 'resolu':
        return const StatusBadge(label: 'Résolu', color: AppColors.primary, background: AppColors.primaryLight);
      case 'termine':
        return const StatusBadge(label: 'Terminé', color: AppColors.success, background: AppColors.successBg);
      default:
        return StatusBadge(label: status, color: AppColors.textMuted, background: AppColors.surfaceAlt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
