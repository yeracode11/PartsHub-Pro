import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';

class AuthFormField extends StatelessWidget {
  const AuthFormField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
    this.textInputAction,
    this.onFieldSubmitted,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 16, color: AuthDesign.text),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AuthDesign.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: AuthDesign.fieldRadius,
          borderSide: const BorderSide(color: AuthDesign.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AuthDesign.fieldRadius,
          borderSide: const BorderSide(color: AuthDesign.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AuthDesign.fieldRadius,
          borderSide: const BorderSide(color: AuthDesign.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AuthDesign.fieldRadius,
          borderSide: const BorderSide(color: AuthDesign.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AuthDesign.fieldRadius,
          borderSide: const BorderSide(color: AuthDesign.error, width: 1.5),
        ),
      ),
    );
  }
}
