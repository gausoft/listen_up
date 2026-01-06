import 'package:hive_ce/hive_ce.dart';

part 'history_item.g.dart';

/// Represents a text/content item in the reading history
@HiveType(typeId: 0)
class HistoryItem extends HiveObject {
  /// Unique identifier
  @HiveField(0)
  late String id;

  /// Title of the content (extracted from URL or first line of text)
  @HiveField(1)
  late String title;

  /// The actual text content
  @HiveField(2)
  late String content;

  /// Source URL if content was extracted from web, null for pasted text
  @HiveField(3)
  String? sourceUrl;

  /// Preview image URL from the source
  @HiveField(4)
  String? imageUrl;

  /// When this item was first added
  @HiveField(5)
  late DateTime createdAt;

  /// When this item was last played
  @HiveField(6)
  late DateTime lastPlayedAt;

  /// Number of times this item has been played
  @HiveField(7)
  late int playCount;

  /// Whether this content came from a URL
  bool get isFromUrl => sourceUrl != null;

  /// Get a short preview of the content (first 100 chars)
  String get preview {
    final cleaned = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 100) return cleaned;
    return '${cleaned.substring(0, 100)}...';
  }

  /// Create a new history item
  static HistoryItem create({
    required String title,
    required String content,
    String? sourceUrl,
    String? imageUrl,
  }) {
    final now = DateTime.now();
    return HistoryItem()
      ..id = '${now.millisecondsSinceEpoch}_${content.hashCode}'
      ..title = title
      ..content = content
      ..sourceUrl = sourceUrl
      ..imageUrl = imageUrl
      ..createdAt = now
      ..lastPlayedAt = now
      ..playCount = 1;
  }

  /// Update play statistics
  void markAsPlayed() {
    lastPlayedAt = DateTime.now();
    playCount++;
  }
}
