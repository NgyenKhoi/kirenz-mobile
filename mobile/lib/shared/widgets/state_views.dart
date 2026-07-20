import 'package:flutter/material.dart';

class KirenzStateView extends StatelessWidget {
  const KirenzStateView({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    this.padding = const EdgeInsets.all(24),
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isError ? colorScheme.error : colorScheme.primary;
    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class KirenzSkeletonList extends StatelessWidget {
  const KirenzSkeletonList({
    this.itemCount = 5,
    this.itemHeight = 84,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView.separated(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: padding,
    itemCount: itemCount,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, index) => ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(height: itemHeight),
      ),
    ),
  );
}

class KirenzInlineNotice extends StatelessWidget {
  const KirenzInlineNotice({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
    super.key,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = isError
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerLow;
    final foreground = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
