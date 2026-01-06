import 'dart:math';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:http/http.dart' as http;

/// Result of web content extraction
class ExtractedContent {
  final String title;
  final String content;
  final String? description;
  final String? imageUrl;
  final String sourceUrl;

  const ExtractedContent({
    required this.title,
    required this.content,
    this.description,
    this.imageUrl,
    required this.sourceUrl,
  });

  bool get isEmpty => content.trim().isEmpty;
  bool get isNotEmpty => !isEmpty;
}

/// Service for extracting readable content from web pages
/// Implements a Readability-like algorithm for content extraction
class WebExtractorService {
  static const _timeout = Duration(seconds: 15);

  // Elements that are unlikely to contain main content
  static const _unlikelyCandidates = [
    'banner',
    'breadcrumbs',
    'combx',
    'comment',
    'community',
    'cover-wrap',
    'disqus',
    'extra',
    'footer',
    'gdpr',
    'header',
    'legends',
    'menu',
    'related',
    'remark',
    'replies',
    'rss',
    'shoutbox',
    'sidebar',
    'skyscraper',
    'social',
    'sponsor',
    'supplemental',
    'ad-break',
    'agegate',
    'pagination',
    'pager',
    'popup',
    'yom-hierarchical-nav',
    'yom-remote',
  ];

  // Elements that might be content candidates
  static const _okMaybeItsACandidate = [
    'and',
    'article',
    'body',
    'column',
    'content',
    'main',
    'shadow',
  ];

  // Positive indicators for content
  static const _positivePatterns = [
    'article',
    'body',
    'content',
    'entry',
    'hentry',
    'h-entry',
    'main',
    'page',
    'pagination',
    'post',
    'text',
    'blog',
    'story',
  ];

  // Negative indicators
  static const _negativePatterns = [
    'hidden',
    'banner',
    'combx',
    'comment',
    'com-',
    'contact',
    'foot',
    'footer',
    'footnote',
    'gdpr',
    'masthead',
    'media',
    'meta',
    'outbrain',
    'promo',
    'related',
    'scroll',
    'share',
    'shoutbox',
    'sidebar',
    'skyscraper',
    'sponsor',
    'shopping',
    'tags',
    'tool',
    'widget',
  ];

  // Elements to completely remove
  static const _removeElements = [
    'script',
    'style',
    'nav',
    'footer',
    'header',
    'aside',
    'form',
    'iframe',
    'noscript',
    'svg',
    'canvas',
    'button',
    'input',
    'select',
    'textarea',
    'figure.wp-block-embed',
  ];

  /// Check if a string is a valid URL
  static bool isValidUrl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    // Simple URL pattern check
    final urlPattern = RegExp(
      r'^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?(\?[^\s]*)?$',
      caseSensitive: false,
    );

    return urlPattern.hasMatch(trimmed) ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://');
  }

  /// Normalize URL (add https if missing)
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'https://$trimmed';
    }
    return trimmed;
  }

  /// Extract content from a URL using Readability-like algorithm
  Future<ExtractedContent> extractFromUrl(String url) async {
    final normalizedUrl = normalizeUrl(url);

    try {
      // Fetch the page
      final response = await http.get(
        Uri.parse(normalizedUrl),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9,fr;q=0.8',
          'Cache-Control': 'no-cache',
        },
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw WebExtractorException(
          'Failed to fetch page: HTTP ${response.statusCode}',
          code: WebExtractorErrorCode.httpError,
        );
      }

      // Parse HTML
      final document = html_parser.parse(response.body);

      // Extract metadata
      final title = _extractTitle(document);
      final description = _extractDescription(document);
      final imageUrl = _extractImage(document, normalizedUrl);

      // Apply Readability algorithm
      final content = _extractWithReadability(document);

      if (content.trim().isEmpty) {
        throw WebExtractorException(
          'Could not extract content from page',
          code: WebExtractorErrorCode.noContent,
        );
      }

      return ExtractedContent(
        title: title,
        content: content,
        description: description,
        imageUrl: imageUrl,
        sourceUrl: normalizedUrl,
      );
    } on WebExtractorException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('HandshakeException')) {
        throw WebExtractorException(
          'Network error: Could not connect to server',
          code: WebExtractorErrorCode.networkError,
        );
      }
      if (e.toString().contains('TimeoutException')) {
        throw WebExtractorException(
          'Request timed out',
          code: WebExtractorErrorCode.timeout,
        );
      }
      throw WebExtractorException(
        'Failed to extract content: $e',
        code: WebExtractorErrorCode.unknown,
      );
    }
  }

  /// Main Readability-like extraction algorithm
  String _extractWithReadability(Document document) {
    // Step 1: Remove unwanted elements
    _removeUnwantedElements(document);

    // Step 2: Try to find article element first (most reliable)
    final article = document.querySelector('article');
    if (article != null) {
      final text = _extractTextFromElement(article);
      if (text.length > 200) {
        return text;
      }
    }

    // Step 3: Score all candidate elements
    final candidates = <Element, double>{};
    final body = document.body;
    if (body == null) return '';

    // Find all paragraphs and score their parents
    final paragraphs = body.querySelectorAll('p');
    for (final p in paragraphs) {
      final text = p.text.trim();
      if (text.length < 25) continue;

      // Get parent and grandparent
      final parent = p.parent;
      final grandparent = parent?.parent;

      if (parent == null) continue;

      // Initialize scores
      candidates.putIfAbsent(parent, () => _getInitialScore(parent));
      if (grandparent != null) {
        candidates.putIfAbsent(grandparent, () => _getInitialScore(grandparent));
      }

      // Calculate content score
      var contentScore = 1.0;
      contentScore += text.split(',').length; // Comma bonus
      contentScore += min((text.length / 100).floor(), 3).toDouble(); // Length bonus

      // Add to parent score
      candidates[parent] = candidates[parent]! + contentScore;

      // Add half to grandparent
      if (grandparent != null) {
        candidates[grandparent] = candidates[grandparent]! + (contentScore / 2);
      }
    }

    // Step 4: Find the best candidate
    Element? bestCandidate;
    double bestScore = 0;

    candidates.forEach((element, score) {
      // Apply link density penalty
      final linkDensity = _getLinkDensity(element);
      final adjustedScore = score * (1 - linkDensity);

      if (adjustedScore > bestScore) {
        bestScore = adjustedScore;
        bestCandidate = element;
      }
    });

    // Step 5: Extract text from best candidate
    if (bestCandidate != null) {
      return _extractTextFromElement(bestCandidate!);
    }

    // Fallback: try main or content div
    final main = document.querySelector('main, [role="main"], #content, .content');
    if (main != null) {
      return _extractTextFromElement(main);
    }

    // Last resort: get all paragraphs from body
    return _extractTextFromElement(body);
  }

  /// Get initial score for an element based on tag and class/id
  double _getInitialScore(Element element) {
    var score = 0.0;
    final tagName = element.localName?.toLowerCase() ?? '';

    // Score by tag
    switch (tagName) {
      case 'article':
        score += 25;
        break;
      case 'section':
        score += 15;
        break;
      case 'div':
        score += 5;
        break;
      case 'pre':
      case 'td':
      case 'blockquote':
        score += 3;
        break;
      case 'form':
      case 'ul':
      case 'ol':
      case 'dl':
        score -= 3;
        break;
      case 'nav':
      case 'header':
      case 'footer':
      case 'aside':
        score -= 25;
        break;
    }

    // Score by class and id
    final classId = '${element.className} ${element.id}'.toLowerCase();

    for (final pattern in _positivePatterns) {
      if (classId.contains(pattern)) {
        score += 25;
        break;
      }
    }

    for (final pattern in _negativePatterns) {
      if (classId.contains(pattern)) {
        score -= 25;
        break;
      }
    }

    return score;
  }

  /// Calculate link density (ratio of link text to total text)
  double _getLinkDensity(Element element) {
    final text = element.text;
    if (text.isEmpty) return 0;

    var linkLength = 0;
    for (final link in element.querySelectorAll('a')) {
      linkLength += link.text.length;
    }

    return linkLength / text.length;
  }

  /// Check if element is unlikely to be content
  bool _isUnlikelyCandidate(Element element) {
    final classId = '${element.className} ${element.id}'.toLowerCase();

    for (final pattern in _unlikelyCandidates) {
      if (classId.contains(pattern)) {
        // Check if it might still be a candidate
        for (final ok in _okMaybeItsACandidate) {
          if (classId.contains(ok)) {
            return false;
          }
        }
        return true;
      }
    }
    return false;
  }

  /// Extract page title
  String _extractTitle(Document document) {
    // Try Open Graph title first
    final ogTitle = document.querySelector('meta[property="og:title"]');
    if (ogTitle != null && ogTitle.attributes['content']?.isNotEmpty == true) {
      return ogTitle.attributes['content']!.trim();
    }

    // Try Twitter title
    final twitterTitle = document.querySelector('meta[name="twitter:title"]');
    if (twitterTitle != null &&
        twitterTitle.attributes['content']?.isNotEmpty == true) {
      return twitterTitle.attributes['content']!.trim();
    }

    // Try article h1
    final articleH1 = document.querySelector('article h1');
    if (articleH1 != null && articleH1.text.trim().isNotEmpty) {
      return articleH1.text.trim();
    }

    // Try any h1
    final h1 = document.querySelector('h1');
    if (h1 != null && h1.text.trim().isNotEmpty) {
      return h1.text.trim();
    }

    // Fall back to title tag
    final title = document.querySelector('title');
    if (title != null && title.text.trim().isNotEmpty) {
      // Clean common suffixes like " | Site Name" or " - Site Name"
      return title.text.trim().split(RegExp(r'\s*[\|\-–—]\s*')).first.trim();
    }

    return 'Untitled';
  }

  /// Extract page description
  String? _extractDescription(Document document) {
    // Try Open Graph description
    final ogDesc = document.querySelector('meta[property="og:description"]');
    if (ogDesc != null && ogDesc.attributes['content']?.isNotEmpty == true) {
      return ogDesc.attributes['content'];
    }

    // Try meta description
    final metaDesc = document.querySelector('meta[name="description"]');
    if (metaDesc != null &&
        metaDesc.attributes['content']?.isNotEmpty == true) {
      return metaDesc.attributes['content'];
    }

    return null;
  }

  /// Extract main image URL
  String? _extractImage(Document document, String baseUrl) {
    // Try Open Graph image
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null && ogImage.attributes['content']?.isNotEmpty == true) {
      return _resolveUrl(ogImage.attributes['content']!, baseUrl);
    }

    // Try Twitter image
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null &&
        twitterImage.attributes['content']?.isNotEmpty == true) {
      return _resolveUrl(twitterImage.attributes['content']!, baseUrl);
    }

    return null;
  }

  /// Resolve relative URLs to absolute
  String _resolveUrl(String url, String baseUrl) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('//')) {
      return 'https:$url';
    }
    final base = Uri.parse(baseUrl);
    if (url.startsWith('/')) {
      return '${base.scheme}://${base.host}$url';
    }
    return '${base.scheme}://${base.host}/${base.path}/$url';
  }

  /// Remove unwanted elements from document
  void _removeUnwantedElements(Document document) {
    // Remove script, style, nav, etc.
    for (final selector in _removeElements) {
      document.querySelectorAll(selector).forEach((e) => e.remove());
    }

    // Remove unlikely candidates
    final body = document.body;
    if (body != null) {
      final toRemove = <Element>[];
      for (final element in body.querySelectorAll('*')) {
        if (_isUnlikelyCandidate(element)) {
          toRemove.add(element);
        }
      }
      for (final element in toRemove) {
        element.remove();
      }
    }

    // Remove empty elements
    document.querySelectorAll('p, div, span').where((e) {
      return e.text.trim().isEmpty && e.children.isEmpty;
    }).forEach((e) => e.remove());

    // Remove hidden elements
    document.querySelectorAll('[hidden], [style*="display:none"], [style*="display: none"]')
        .forEach((e) => e.remove());
  }

  /// Extract clean text from an element
  String _extractTextFromElement(Element element) {
    final buffer = StringBuffer();
    
    // Get all text-containing elements
    final textElements = element.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, blockquote, pre');

    if (textElements.isNotEmpty) {
      for (final el in textElements) {
        final tagName = el.localName?.toLowerCase() ?? '';
        var text = el.text.trim();
        
        if (text.isEmpty) continue;
        
        // Skip if parent is already processed (nested lists)
        if (el.parent?.localName == 'li') continue;
        
        // Add heading markers
        if (tagName.startsWith('h') && tagName.length == 2) {
          buffer.writeln();
          buffer.writeln(text.toUpperCase());
          buffer.writeln();
        } else if (tagName == 'blockquote') {
          buffer.writeln('"$text"');
          buffer.writeln();
        } else if (tagName == 'li') {
          buffer.writeln('• $text');
        } else {
          buffer.writeln(text);
          buffer.writeln();
        }
      }
    } else {
      // Fall back to all text content
      buffer.write(element.text);
    }

    // Clean up the text
    return buffer
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Remove excessive newlines
        .replaceAll(RegExp(r'[ \t]+'), ' ') // Normalize spaces
        .replaceAll(RegExp(r' +\n'), '\n') // Remove trailing spaces
        .trim();
  }
}

/// Error codes for web extraction
enum WebExtractorErrorCode {
  httpError,
  networkError,
  timeout,
  noContent,
  invalidUrl,
  unknown,
}

/// Exception for web extraction errors
class WebExtractorException implements Exception {
  final String message;
  final WebExtractorErrorCode code;

  const WebExtractorException(this.message, {required this.code});

  @override
  String toString() => message;
}
