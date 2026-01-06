import 'package:flutter/material.dart';

/// A widget that displays text with word-by-word highlighting
/// synchronized with TTS playback, with auto-scroll support.
class HighlightedTextView extends StatefulWidget {
  const HighlightedTextView({
    super.key,
    required this.text,
    this.currentWordStart,
    this.currentWordEnd,
    this.isPlaying = false,
    this.textStyle,
    this.highlightColor,
    this.highlightTextColor,
    this.padding = const EdgeInsets.all(16),
  });

  /// The full text to display
  final String text;

  /// Start position of the current word being spoken
  final int? currentWordStart;

  /// End position of the current word being spoken
  final int? currentWordEnd;

  /// Whether TTS is currently playing
  final bool isPlaying;

  /// Base text style
  final TextStyle? textStyle;

  /// Background color for highlighted word
  final Color? highlightColor;

  /// Text color for highlighted word
  final Color? highlightTextColor;

  /// Padding around the text
  final EdgeInsets padding;

  @override
  State<HighlightedTextView> createState() => _HighlightedTextViewState();
}

class _HighlightedTextViewState extends State<HighlightedTextView> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();

  @override
  void didUpdateWidget(HighlightedTextView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll when word position changes
    if (widget.isPlaying &&
        widget.currentWordStart != null &&
        widget.currentWordStart != oldWidget.currentWordStart) {
      _scrollToHighlight();
    }
  }

  void _scrollToHighlight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _highlightKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.3, // Keep highlighted word in upper third of view
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultTextStyle = widget.textStyle ??
        theme.textTheme.bodyLarge?.copyWith(
          height: 1.8,
          fontSize: 18,
        );
    final highlightColor =
        widget.highlightColor ?? theme.colorScheme.primaryContainer;
    final highlightTextColor =
        widget.highlightTextColor ?? theme.colorScheme.onPrimaryContainer;

    return SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding,
      child: RichText(
        text: TextSpan(
          children: _buildTextSpans(
            defaultTextStyle,
            highlightColor,
            highlightTextColor,
          ),
        ),
      ),
    );
  }

  List<InlineSpan> _buildTextSpans(
    TextStyle? baseStyle,
    Color highlightColor,
    Color highlightTextColor,
  ) {
    final text = widget.text;
    final start = widget.currentWordStart;
    final end = widget.currentWordEnd;

    // No highlighting needed if positions are null or invalid
    if (start == null ||
        end == null ||
        start < 0 ||
        end > text.length ||
        start >= end ||
        !widget.isPlaying) {
      return [
        TextSpan(text: text, style: baseStyle),
      ];
    }

    return [
      // Text before current word
      if (start > 0)
        TextSpan(
          text: text.substring(0, start),
          style: baseStyle,
        ),

      // Current word (highlighted) with GlobalKey for scroll targeting
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Container(
          key: _highlightKey,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          decoration: BoxDecoration(
            color: highlightColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            text.substring(start, end),
            style: baseStyle?.copyWith(
              color: highlightTextColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),

      // Text after current word
      if (end < text.length)
        TextSpan(
          text: text.substring(end),
          style: baseStyle,
        ),
    ];
  }
}
