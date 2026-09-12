import 'package:flutter/material.dart';
import 'package:autohub_b2b/widgets/auth/auth_design.dart';

/// Выбор роли при регистрации: владелец или мастер.
class AuthRoleSelector extends StatelessWidget {
  const AuthRoleSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const owner = 'owner';
  static const worker = 'worker';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Роль',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AuthDesign.text,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _RoleChip(
                label: 'Владелец',
                selected: value == owner,
                onTap: () => onChanged(owner),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RoleChip(
                label: 'Мастер',
                selected: value == worker,
                onTap: () => onChanged(worker),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AuthDesign.primary.withValues(alpha: 0.08) : AuthDesign.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AuthDesign.primary : AuthDesign.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AuthDesign.primary : AuthDesign.text,
            ),
          ),
        ),
      ),
    );
  }
}
