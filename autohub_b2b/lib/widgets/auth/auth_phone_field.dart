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
    this.initialCountry = PhoneCountry.kazakhstan,
    this.onCountryChanged,
    this.variant = PhoneFieldVariant.auth,
    this.label = 'Телефон',
  });

  final TextEditingController controller;
  final String label;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final PhoneCountry initialCountry;
  final ValueChanged<PhoneCountry>? onCountryChanged;
  final PhoneFieldVariant variant;

  @override
  State<AuthPhoneField> createState() => AuthPhoneFieldState();
}

class AuthPhoneFieldState extends State<AuthPhoneField> {
  late PhoneCountry _country;

  PhoneCountry get country => _country;

  String? toE164() {
    return PhoneUtils.normalizeToE164(
      widget.controller.text,
      country: _country,
      nationalDigitsOnly: true,
    );
  }

  bool get _isProfile => widget.variant == PhoneFieldVariant.profile;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry;
  }

  void _setCountry(PhoneCountry value) {
    if (_country.iso == value.iso && _country.dial == value.dial) return;
    setState(() {
      _country = value;
      widget.controller.clear();
    });
    widget.onCountryChanged?.call(value);
  }

  Future<void> _pickCountry() async {
    final picked = await showPhoneCountryPicker(context, selected: _country);
    if (picked != null) _setCountry(picked);
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      inputFormatters: [NationalPhoneInputFormatter(_country)],
      style: TextStyle(
        fontSize: 16,
        color: _isProfile ? AppTheme.textPrimary : AuthDesign.text,
      ),
      decoration: _isProfile
          ? InputDecoration(
              labelText: widget.label,
              hintText: _country.example,
            )
          : InputDecoration(
              labelText: widget.label,
              hintText: _country.example,
              filled: true,
              fillColor: AuthDesign.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: _border(AuthDesign.border),
              enabledBorder: _border(AuthDesign.border),
              focusedBorder: _border(AuthDesign.primary, width: 1.5),
              errorBorder: _border(AuthDesign.error),
              focusedErrorBorder: _border(AuthDesign.error, width: 1.5),
            ),
      validator: (value) => PhoneUtils.validationMessage(
        value,
        country: _country,
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CountryButton(
          country: _country,
          profile: _isProfile,
          onPressed: _pickCountry,
        ),
        const SizedBox(width: 8),
        Expanded(child: field),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AuthDesign.fieldRadius,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _CountryButton extends StatelessWidget {
  const _CountryButton({
    required this.country,
    required this.profile,
    required this.onPressed,
  });

  final PhoneCountry country;
  final bool profile;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = profile ? AppTheme.borderColor : AuthDesign.border;
    final background = profile ? Colors.transparent : AuthDesign.surface;
    return Material(
      color: background,
      borderRadius: AuthDesign.fieldRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AuthDesign.fieldRadius,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: AuthDesign.fieldRadius,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                country.buttonLabel,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: profile ? AppTheme.textPrimary : AuthDesign.text,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more,
                size: 18,
                color: profile ? AppTheme.textSecondary : AuthDesign.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<PhoneCountry?> showPhoneCountryPicker(
  BuildContext context, {
  required PhoneCountry selected,
}) {
  final content = _PhoneCountryList(selected: selected);
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 600) {
    return showDialog<PhoneCountry>(
      context: context,
      builder: (context) => Dialog(
        child: SizedBox(width: 420, height: 520, child: content),
      ),
    );
  }
  return showModalBottomSheet<PhoneCountry>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: content,
    ),
  );
}

class _PhoneCountryList extends StatefulWidget {
  const _PhoneCountryList({required this.selected});

  final PhoneCountry selected;

  @override
  State<_PhoneCountryList> createState() => _PhoneCountryListState();
}

class _PhoneCountryListState extends State<_PhoneCountryList> {
  final _query = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<PhoneCountry> get _visible {
    final query = _filter.trim().toLowerCase();
    if (query.isEmpty) return PhoneCountry.all;
    return PhoneCountry.all.where((country) {
      return country.name.toLowerCase().contains(query) ||
          country.iso.toLowerCase().contains(query) ||
          country.dialLabel.contains(query) ||
          country.dial.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final countries = _visible;
    final cis = countries.where((c) => c.group == PhoneCountryGroup.cis);
    final usa = countries.where((c) => c.group == PhoneCountryGroup.usa);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Страна',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _query,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Поиск',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _filter = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(
            children: [
              if (cis.isNotEmpty) ...[
                const _GroupLabel('СНГ'),
                ...cis.map(_tile),
              ],
              if (usa.isNotEmpty) ...[
                const _GroupLabel('США'),
                ...usa.map(_tile),
              ],
              if (countries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ничего не найдено'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tile(PhoneCountry country) {
    final selected = country.iso == widget.selected.iso;
    return ListTile(
      title: Text(country.name),
      trailing: Text(
        country.dialLabel,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? AuthDesign.primary : AuthDesign.textMuted,
        ),
      ),
      selected: selected,
      onTap: () => Navigator.pop(context, country),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AuthDesign.textMuted,
        ),
      ),
    );
  }
}
