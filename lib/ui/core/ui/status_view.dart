import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import 'accents.dart';
import 'empty_state.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FCircularProgress(),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(message!, style: TextStyle(color: colors.mutedForeground)),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.title = 'Something went wrong', this.onRetry});

  final String title;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: FIcons.cloudOff,
        accent: Accent.red,
        title: title,
        message: message,
        action: onRetry == null
            ? null
            : FButton(
                mainAxisSize: MainAxisSize.min,
                style: FButtonStyle.outline(),
                prefix: const Icon(FIcons.refreshCw),
                onPress: onRetry,
                child: const Text('Try again'),
              ),
      );
}
