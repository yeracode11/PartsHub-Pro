import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/user_entity.dart';

/// Create / edit — sends JSON maps to the repository; backend validates fields.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.existing});

  final UserEntity? existing;

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  late final TextEditingController _name;
  late final TextEditingController _password;
  late final TextEditingController _organizationId;
  late final TextEditingController _role;
  late bool _active;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _email = TextEditingController(text: u?.email ?? '');
    _name = TextEditingController(text: u?.name ?? '');
    _password = TextEditingController();
    _organizationId = TextEditingController(text: u?.organizationId ?? '');
    _role = TextEditingController(text: u?.role ?? 'owner');
    _active = u?.isActive ?? true;
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _password.dispose();
    _organizationId.dispose();
    _role.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit user' : 'Create user'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  enabled: !_isEdit,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: InputDecoration(
                    labelText: _isEdit ? 'New password (optional)' : 'Password',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (!_isEdit && (v == null || v.isEmpty)) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _organizationId,
                  decoration: const InputDecoration(labelText: 'Organization ID'),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F\-]'))],
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Active'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final body = <String, dynamic>{
              'email': _email.text.trim(),
              'name': _name.text.trim(),
              'role': _role.text.trim(),
              'isActive': _active,
              if (_organizationId.text.trim().isNotEmpty)
                'organizationId': _organizationId.text.trim(),
              if (!_isEdit || _password.text.isNotEmpty) 'password': _password.text,
            };
            Navigator.pop<Map<String, dynamic>>(context, body);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
