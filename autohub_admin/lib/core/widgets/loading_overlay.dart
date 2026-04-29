import 'package:flutter/material.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    super.key,
    required this.loading,
    required this.child,
    this.message,
  });

  final bool loading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (loading)
          Positioned.fill(
            child: AbsorbPointer(
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.05)),
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          if (message != null) ...[
                            const SizedBox(width: 16),
                            Text(message!),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
