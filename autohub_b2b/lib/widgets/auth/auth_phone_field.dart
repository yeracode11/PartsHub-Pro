import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/phone/phone_utils.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';

class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: [KazakhstanPhoneInputFormatter()],
      style: const TextStyle(fontSize: 16, color: AuthDesign.text),
      decoration: InputDecoration(
        labelText: 'Телефон',
        hintText: '+7 (777) 123-45-67',
        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
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
      validator: PhoneUtils.validationMessage,
    );
  }
}
