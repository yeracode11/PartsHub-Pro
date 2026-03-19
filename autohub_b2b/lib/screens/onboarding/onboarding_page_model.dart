import 'package:flutter/material.dart';

class OnboardingPageModel {
  final String title;
  final String description;
  final IconData icon;
  final LinearGradient gradient;

  const OnboardingPageModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}
