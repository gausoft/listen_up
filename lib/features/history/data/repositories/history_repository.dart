import 'package:hive_ce/hive_ce.dart';

import '../models/history_item.dart';

/// Repository for managing reading history persistence
class HistoryRepository {
  static const String _boxName = 'history';
  static const int _maxItems = 100;

  Box<HistoryItem>? _box;

  /// Initialize the repository and open the Hive box
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<HistoryItem>(_boxName);
  }

  /// Get all history items sorted by lastPlayedAt (most recent first)
  List<HistoryItem> getAll() {
    if (_box == null) return [];
    final items = _box!.values.toList();
    items.sort((a, b) => b.lastPlayedAt.compareTo(a.lastPlayedAt));
    return items;
  }

  /// Get a history item by its ID
  HistoryItem? getById(String id) {
    if (_box == null) return null;
    try {
      return _box!.values.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find an existing item by content hash or URL
  HistoryItem? findExisting({String? sourceUrl, required String content}) {
    if (_box == null) return null;

    // First try to match by URL if available
    if (sourceUrl != null) {
      try {
        return _box!.values.firstWhere((item) => item.sourceUrl == sourceUrl);
      } catch (_) {
        // Not found by URL, continue
      }
    }

    // Then try to match by content (exact match)
    try {
      return _box!.values.firstWhere((item) => item.content == content);
    } catch (_) {
      return null;
    }
  }

  /// Add a new item or update if already exists
  /// Returns the saved/updated item
  Future<HistoryItem> addOrUpdate({
    required String title,
    required String content,
    String? sourceUrl,
    String? imageUrl,
  }) async {
    if (_box == null) {
      throw StateError('Repository not initialized. Call init() first.');
    }

    // Check if item already exists
    final existing = findExisting(sourceUrl: sourceUrl, content: content);

    if (existing != null) {
      // Update existing item
      existing.markAsPlayed();
      await existing.save();
      return existing;
    }

    // Create new item
    final item = HistoryItem.create(
      title: title,
      content: content,
      sourceUrl: sourceUrl,
      imageUrl: imageUrl,
    );

    await _box!.add(item);

    // Cleanup old items if we exceed max
    await _cleanupOldItems();

    return item;
  }

  /// Delete a history item by key
  Future<void> delete(HistoryItem item) async {
    await item.delete();
  }

  /// Delete all history items
  Future<void> clearAll() async {
    if (_box == null) return;
    await _box!.clear();
  }

  /// Get the count of history items
  int get count => _box?.length ?? 0;

  /// Check if repository is empty
  bool get isEmpty => count == 0;

  /// Clean up old items when exceeding max limit
  Future<void> _cleanupOldItems() async {
    if (_box == null || _box!.length <= _maxItems) return;

    final items = getAll();
    // Items are already sorted by lastPlayedAt desc
    // Remove items beyond max limit
    final toRemove = items.skip(_maxItems).toList();
    for (final item in toRemove) {
      await item.delete();
    }
  }

  /// Close the repository
  Future<void> close() async {
    await _box?.close();
  }
}
