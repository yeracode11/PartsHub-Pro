import 'package:flutter/material.dart';

import 'package:autohub_b2b/core/theme.dart';
import 'package:autohub_b2b/models/item_model.dart';
import 'package:autohub_b2b/screens/warehouse/donor_detail_screen.dart';

/// «Из какой машины деталь» — ведёт в карточку донора.
class DonorOriginTile extends StatelessWidget {
  final ItemModel item;

  const DonorOriginTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final donorId = item.donorId;
    if (donorId == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppTheme.borderColor),
        ),
        title: const Text('Снято с донора'),
        subtitle: Text(item.donorTitle ?? 'Донор #$donorId'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DonorDetailScreen(donorId: donorId),
          ),
        ),
      ),
    );
  }
}
