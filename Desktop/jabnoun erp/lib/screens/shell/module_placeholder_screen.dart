import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/page_scaffold.dart';

/// Écran affiché pour les modules dont l'implémentation complète arrive
/// dans une phase ultérieure (voir plan de développement par phases).
/// Permet de garder la navigation cohérente dès le départ.
class ModulePlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;

  const ModulePlaceholderScreen({super.key, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: title,
      child: ContentCard(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.construction_outlined, size: 40, color: AppColors.textMuted),
              const SizedBox(height: 14),
              Text('Module en cours de développement',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
              const SizedBox(height: 6),
              Text(description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
