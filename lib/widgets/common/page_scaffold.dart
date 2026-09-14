import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Structure standard pour une page de module: titre, sous-titre, actions,
/// puis contenu (généralement une carte contenant filtres + tableau).
class PageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const PageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(subtitle!,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Carte de contenu standard (bordure fine, fond blanc, coins peu arrondis).
class ContentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ContentCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: padding,
      child: child,
    );
  }
}
