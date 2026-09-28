import 'package:flutter/material.dart';
import 'package:autohub_b2b/core/phone/phone_utils.dart';
import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';

enum PhoneFieldVariant { auth, profile }

class AuthPhoneField extends StatefulWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onFieldSubmitted,
    this.initialRegion = AuthPhoneRegion.kz,
    this.onRegionChanged,
    this.variant = PhoneFieldVariant.auth,
  });

  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final AuthPhoneRegion initialRegion;
  final ValueChanged<AuthPhoneRegion>? onRegionChanged;
  final PhoneFieldVariant variant;

  @override
  State<AuthPhoneField> createState() => AuthPhoneFieldState();
}

class AuthPhoneFieldState extends State<AuthPhoneField> {
  late AuthPhoneRegion _region;

  AuthPhoneRegion get region => _region;

  bool get _isProfile => widget.variant == PhoneFieldVariant.profile;

  bool get _nationalOnly => _isProfile;

  @override
  void initState() {
    super.initState();
    _region = widget.initialRegion;
  }

  void _setRegion(AuthPhoneRegion value) {
    if (_region == value) return;
    setState(() {
      _region = value;
      widget.controller.clear();
    });
    widget.onRegionChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final isUs = _region == AuthPhoneRegion.us;

    final countrySelector = _isProfile
        ? _ProfileCountrySelector(
            region: _region,
            onChanged: _setRegion,
          )
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AuthPhoneRegion>(
                value: _region,
                borderRadius: AuthDesign.fieldRadius,
                items: const [
                  DropdownMenuItem(
                    value: AuthPhoneRegion.kz,
                    child: Text('+7'),
                  ),
                  DropdownMenuItem(
                    value: AuthPhoneRegion.us,
                    child: Text('+1'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) _setRegion(value);
                },
              ),
            ),
          );

    final field = TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: [
        if (_nationalOnly)
          isUs
              ? NationalUsPhoneInputFormatter()
              : NationalKzPhoneInputFormatter()
        else
          isUs ? UsPhoneInputFormatter() : KazakhstanPhoneInputFormatter(),
      ],
      style: TextStyle(
        fontSize: 16,
        color: _isProfile ? AppTheme.textPrimary : AuthDesign.text,
      ),
      decoration: _isProfile
          ? InputDecoration(
              labelText: 'Телефон',
              hintText: isUs ? '(555) 123-4567' : '(777) 123-45-67',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
            )
          : InputDecoration(
              labelText: 'Телефон',
              hintText: isUs ? '+1 (555) 123-4567' : '+7 (777) 123-45-67',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              filled: true,
              fillColor: AuthDesign.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
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
                borderSide:
                    const BorderSide(color: AuthDesign.primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: AuthDesign.fieldRadius,
                borderSide: const BorderSide(color: AuthDesign.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: AuthDesign.fieldRadius,
                borderSide:
                    const BorderSide(color: AuthDesign.error, width: 1.5),
              ),
            ),
      validator: (value) => PhoneUtils.validationMessage(
        value,
        region: _region,
        nationalDigitsOnly: _nationalOnly,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        countrySelector,
        const SizedBox(width: 8),
        Expanded(child: field),
      ],
    );
  }
}

class _ProfileCountrySelector extends StatelessWidget {
  const _ProfileCountrySelector({
    required this.region,
    required this.onChanged,
  });

  final AuthPhoneRegion region;
  final ValueChanged<AuthPhoneRegion> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          labelText: 'Код',
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<AuthPhoneRegion>(
            isExpanded: true,
            value: region,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            icon: const Icon(Icons.expand_more, size: 20),
            items: const [
              DropdownMenuItem(
                value: AuthPhoneRegion.kz,
                child: Text('+7'),
              ),
              DropdownMenuItem(
                value: AuthPhoneRegion.us,
                child: Text('+1'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            },
          ),
        ),
      ),
    );
  }
}
