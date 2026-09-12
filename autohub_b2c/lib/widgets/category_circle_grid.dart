import 'package:flutter/material.dart';
import '../core/constants/part_categories.dart';
import '../core/design/app_colors.dart';
import '../core/design/app_effects.dart';
import '../core/design/app_spacing.dart';

/// Сетка категорий — строки по горизонтали (4 в ряд), ячейки растягиваются по ширине.
class CategoryCircleGrid extends StatelessWidget {
  final List<PartCategory> categories;
  final ValueChanged<PartCategory>? onCategoryTap;
  final int crossAxisCount;

  const CategoryCircleGrid({
    super.key,
    this.categories = PartCategories.featured,
    this.onCategoryTap,
    this.crossAxisCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryHorizontalTile(
          category: category,
          onTap: onCategoryTap == null
              ? null
              : () => onCategoryTap!(category),
        );
      },
    );
  }
}

class _CategoryHorizontalTile extends StatelessWidget {
  final PartCategory category;
  final VoidCallback? onTap;

  const _CategoryHorizontalTile({
    required this.category,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      label: category.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      boxShadow: AppEffects.categoryCircleShadow,
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: category.tint,
                        ),
                        child: Icon(
                          category.icon,
                          size: 22,
                          color: category.iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
