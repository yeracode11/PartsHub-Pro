import 'package:flutter/material.dart';

class PartCategory {
  final String name;
  final IconData icon;
  final Color iconColor;
  final Color tint;

  const PartCategory({
    required this.name,
    required this.icon,
    required this.iconColor,
    required this.tint,
  });
}

/// Категории запчастей для главной и каталога.
abstract final class PartCategories {
  static const featured = [
    PartCategory(
      name: 'Тормоза',
      icon: Icons.album_outlined,
      iconColor: Color(0xFFDC2626),
      tint: Color(0xFFFEE2E2),
    ),
    PartCategory(
      name: 'Двигатель',
      icon: Icons.precision_manufacturing_outlined,
      iconColor: Color(0xFF2563EB),
      tint: Color(0xFFDBEAFE),
    ),
    PartCategory(
      name: 'Кузов',
      icon: Icons.directions_car_outlined,
      iconColor: Color(0xFFEA580C),
      tint: Color(0xFFFFEDD5),
    ),
    PartCategory(
      name: 'Подвеска',
      icon: Icons.height_outlined,
      iconColor: Color(0xFF7C3AED),
      tint: Color(0xFFEDE9FE),
    ),
    PartCategory(
      name: 'Освещение',
      icon: Icons.lightbulb_outline_rounded,
      iconColor: Color(0xFFD97706),
      tint: Color(0xFFFEF3C7),
    ),
    PartCategory(
      name: 'Электрика',
      icon: Icons.electrical_services_outlined,
      iconColor: Color(0xFF0891B2),
      tint: Color(0xFFCFFAFE),
    ),
    PartCategory(
      name: 'Шины',
      icon: Icons.tire_repair_outlined,
      iconColor: Color(0xFF475569),
      tint: Color(0xFFF1F5F9),
    ),
    PartCategory(
      name: 'Фильтры',
      icon: Icons.filter_alt_outlined,
      iconColor: Color(0xFF16A34A),
      tint: Color(0xFFDCFCE7),
    ),
  ];

  static List<String> get marketplaceFilters => [
        'Все',
        ...featured.map((c) => c.name),
      ];

  static PartCategory? byName(String name) {
    for (final c in featured) {
      if (c.name == name) return c;
    }
    return null;
  }
}
