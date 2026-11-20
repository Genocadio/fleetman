import 'package:flutter/material.dart';

/// Static placeholder blocks used instead of circular progress indicators.
///
/// Loading states keep the shape of the content that is about to appear, and
/// because there is no animation ticker widget tests settle immediately.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.color,
    this.opacity,
  });

  final double? width;
  final double height;
  final double radius;
  final Color? color;
  final double? opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? (isDark ? Colors.white : const Color(0xFF0E5A57));
    final alpha = opacity ?? (isDark ? 0.12 : 0.09);

    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// A card-shaped placeholder that mirrors a list row (avatar + two lines).
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 40, height: 40, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSkeleton(width: 140, height: 14),
                    const SizedBox(height: 8),
                    const AppSkeleton(width: 200, height: 11),
                    if (lines > 2) ...const [
                      SizedBox(height: 8),
                      AppSkeleton(width: 110, height: 11),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scrollable list of card placeholders for full-page loading states.
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({super.key, this.items = 5});

  final int items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: AppSkeletonCard(),
      ),
    );
  }
}
