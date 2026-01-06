import 'package:flutter/material.dart';

/// A custom TextEditingController that supports word-by-word highlighting
/// integrated directly into the TextField rendering via buildTextSpan().
///
/// This eliminates the need to switch between TextField and a separate
/// highlighting widget, preventing visual glitches during state changes.
class HighlightingTextEditingController extends TextEditingController {
  /// Start position of the highlighted word
  int? _highlightStart;

  /// End position of the highlighted word
  int? _highlightEnd;

  /// Whether highlighting is currently enabled
  bool _isHighlightingEnabled = false;

  /// Background color for the highlighted word
  Color _highlightColor = Colors.purple.shade100;

  /// Text color for the highlighted word
  Color _highlightTextColor = Colors.purple.shade900;

  /// Base text style (set from TextField's style)
  TextStyle? _baseStyle;

  // Getters
  int? get highlightStart => _highlightStart;
  int? get highlightEnd => _highlightEnd;
  bool get isHighlightingEnabled => _isHighlightingEnabled;

  /// Update the highlight position
  void updateHighlight(int? start, int? end) {
    _highlightStart = start;
    _highlightEnd = end;
    notifyListeners();
  }

  /// Enable or disable highlighting
  void setHighlightingEnabled(bool enabled) {
    _isHighlightingEnabled = enabled;
    if (!enabled) {
      // Keep positions when disabling (for pause state)
      // Only clear on explicit reset
    }
    notifyListeners();
  }

  /// Set highlight colors (typically from theme)
  void setHighlightColors({Color? backgroundColor, Color? textColor}) {
    if (backgroundColor != null) _highlightColor = backgroundColor;
    if (textColor != null) _highlightTextColor = textColor;
    notifyListeners();
  }

  /// Set base text style
  void setBaseStyle(TextStyle? style) {
    _baseStyle = style;
  }

  /// Reset highlight completely (called on stop)
  void resetHighlight() {
    _highlightStart = null;
    _highlightEnd = null;
    _isHighlightingEnabled = false;
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final effectiveStyle = style ?? _baseStyle;
    final textValue = text;

    // If highlighting is not enabled or positions are invalid, return normal text
    if (!_isHighlightingEnabled ||
        _highlightStart == null ||
        _highlightEnd == null ||
        _highlightStart! < 0 ||
        _highlightEnd! > textValue.length ||
        _highlightStart! >= _highlightEnd!) {
      return TextSpan(text: textValue, style: effectiveStyle);
    }

    final start = _highlightStart!;
    final end = _highlightEnd!;

    // Build TextSpan with three parts: before, highlighted, after
    return TextSpan(
      style: effectiveStyle,
      children: [
        // Text before highlighted word
        if (start > 0) TextSpan(text: textValue.substring(0, start)),

        // Highlighted word
        TextSpan(
          text: textValue.substring(start, end),
          style: TextStyle(
            backgroundColor: _highlightColor,
            color: _highlightTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),

        // Text after highlighted word
        if (end < textValue.length) TextSpan(text: textValue.substring(end)),
      ],
    );
  }
}
