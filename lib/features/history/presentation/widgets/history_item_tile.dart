import 'package:flutter/material.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import '../../data/models/history_item.dart';

/// A tile widget that displays a history item
class HistoryItemTile extends StatelessWidget {
  final HistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const HistoryItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(
          HugeIconsStroke.delete02,
          color: theme.colorScheme.onError,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: item.isFromUrl
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            item.isFromUrl ? HugeIconsStroke.link01 : HugeIconsStroke.text,
            color: item.isFromUrl
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSecondaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  HugeIconsStroke.clock01,
                  size: 12,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(item.lastPlayedAt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                if (item.playCount > 1) ...[
                  const SizedBox(width: 12),
                  Icon(
                    HugeIconsStroke.playCircle,
                    size: 12,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.playCount}x',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Icon(
          HugeIconsStroke.arrowRight01,
          size: 20,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
