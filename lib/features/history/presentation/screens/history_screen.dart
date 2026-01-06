import 'package:flutter/material.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import '../../data/models/history_item.dart';
import '../../data/repositories/history_repository.dart';
import '../widgets/history_item_tile.dart';

/// Screen that displays the reading history
class HistoryScreen extends StatefulWidget {
  final HistoryRepository repository;

  const HistoryScreen({
    super.key,
    required this.repository,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  void _loadItems() {
    setState(() {
      _items = widget.repository.getAll();
    });
  }

  Future<void> _deleteItem(HistoryItem item) async {
    await widget.repository.delete(item);
    _loadItems();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Item deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
          'Are you sure you want to delete all history items? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.repository.clearAll();
      _loadItems();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('History cleared'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _selectItem(HistoryItem item) {
    Navigator.pop(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(HugeIconsStroke.delete02),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _items.isEmpty ? _buildEmptyState(theme) : _buildList(),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HugeIconsStroke.clock01,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No history yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your reading history will appear here',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _items[index];
        return HistoryItemTile(
          item: item,
          onTap: () => _selectItem(item),
          onDelete: () => _deleteItem(item),
        );
      },
    );
  }
}
