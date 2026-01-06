import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/web_extractor_service.dart';
import '../../../history/data/models/history_item.dart';
import '../../../history/data/repositories/history_repository.dart';
import '../../../history/presentation/screens/history_screen.dart';
import '../controllers/highlighting_text_controller.dart';
import '../controllers/tts_controller.dart';
import '../widgets/playback_controls.dart';
import '../widgets/settings_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsController _ttsController = TtsController();
  final HighlightingTextEditingController _textController =
      HighlightingTextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final HistoryRepository _historyRepository = HistoryRepository();
  final WebExtractorService _webExtractor = WebExtractorService();

  bool _isRepositoryReady = false;
  bool _isExtractingUrl = false;
  String? _extractedTitle;
  String? _sourceUrl;

  @override
  void initState() {
    super.initState();
    _initServices();
    _ttsController.addListener(_handleTtsStateChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set highlight colors from theme
    final theme = Theme.of(context);
    _textController.setHighlightColors(
      backgroundColor: theme.colorScheme.primaryContainer,
      textColor: theme.colorScheme.onPrimaryContainer,
    );
  }

  Future<void> _initServices() async {
    await Future.wait([
      _ttsController.init(),
      _historyRepository.init(),
    ]);
    if (mounted) {
      setState(() {
        _isRepositoryReady = true;
      });
    }
  }

  /// Handle TTS state changes - update highlighting and show errors
  void _handleTtsStateChange() {
    // Handle errors
    if (_ttsController.lastError != null && mounted) {
      final error = _ttsController.lastError!;
      _ttsController.clearError();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }

    // Update highlighting state
    if (!_ttsController.usingCloudTts) {
      final isActive = _ttsController.isPlaying || _ttsController.isPaused;
      _textController.setHighlightingEnabled(isActive);

      // Update highlight position
      final newStart = _ttsController.currentWordStart;
      final oldStart = _textController.highlightStart;
      _textController.updateHighlight(
        newStart,
        _ttsController.currentWordEnd,
      );

      // Auto-scroll when playing and position changed
      if (_ttsController.isPlaying && newStart != null && newStart != oldStart) {
        _scrollToHighlight(newStart);
      }

      // Reset highlighting on stop
      if (_ttsController.isStopped) {
        _textController.resetHighlight();
      }
    }
  }

  /// Auto-scroll to keep the highlighted word visible
  void _scrollToHighlight(int charPosition) {
    if (!_scrollController.hasClients) return;

    final text = _textController.text;
    if (text.isEmpty) return;

    // Estimate scroll position based on character position
    // This is an approximation - assumes roughly uniform character density
    final progress = charPosition / text.length;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetScroll = (maxScroll * progress).clamp(0.0, maxScroll);

    // Smooth scroll to target position
    _scrollController.animateTo(
      targetScroll,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ttsController.removeListener(_handleTtsStateChange);
    _ttsController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _historyRepository.close();
    super.dispose();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SettingsBottomSheet(controller: _ttsController),
    );
  }

  Future<void> _showHistory() async {
    final result = await Navigator.push<HistoryItem>(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(repository: _historyRepository),
      ),
    );

    if (result != null && mounted) {
      _textController.text = result.content;
      setState(() {});
    }
  }

  void _clearText() {
    _textController.clear();
    _ttsController.stop();
    setState(() {});
  }

  /// Check if a string looks like a URL
  bool _isUrl(String text) {
    final trimmed = text.trim();
    // Check for common URL patterns
    final urlPattern = RegExp(
      r'^(https?:\/\/)?'
      r'([\da-z\.-]+)\.'
      r'([a-z\.]{2,6})'
      r'([\/\w \.-]*)*\/?$',
      caseSensitive: false,
    );
    return urlPattern.hasMatch(trimmed) ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('www.');
  }

  /// Extract content from URL
  Future<void> _extractFromUrl(String url) async {
    setState(() {
      _isExtractingUrl = true;
      _extractedTitle = null;
      _sourceUrl = null;
    });

    try {
      final content = await _webExtractor.extractFromUrl(url);
      if (mounted) {
        _textController.text = content.content;
        _extractedTitle = content.title;
        _sourceUrl = content.sourceUrl;
        setState(() {
          _isExtractingUrl = false;
        });
      }
    } on WebExtractorException catch (e) {
      if (mounted) {
        setState(() {
          _isExtractingUrl = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'OK', onPressed: () {}),
          ),
        );
      }
    }
  }

  Future<void> _pasteText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      final text = clipboardData.text!.trim();

      // Check if it's a URL
      if (_isUrl(text)) {
        await _extractFromUrl(text);
      } else {
        // Plain text, just paste it
        _textController.text = text;
        _extractedTitle = null;
        _sourceUrl = null;
        setState(() {});
      }
    }
  }

  /// Save content to history when playback starts
  Future<void> _saveToHistory(String text) async {
    if (!_isRepositoryReady || text.trim().isEmpty) return;

    // Use extracted title if available, otherwise generate from content
    String title;
    if (_extractedTitle != null && _extractedTitle!.isNotEmpty) {
      title = _extractedTitle!;
    } else {
      final firstLine = text.split('\n').first.trim();
      title = firstLine.length > 50
          ? '${firstLine.substring(0, 50)}...'
          : firstLine.isNotEmpty
              ? firstLine
              : 'Untitled';
    }

    await _historyRepository.addOrUpdate(
      title: title,
      content: text,
      sourceUrl: _sourceUrl,
    );
  }

  /// Called when play button is pressed
  Future<void> _onPlayPressed(String text) async {
    // Save to history before playing
    await _saveToHistory(text);
    await _ttsController.togglePlayPause(text);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(HugeIconsStroke.clock01),
            onPressed: _isRepositoryReady ? _showHistory : null,
            tooltip: 'History',
          ),
          actions: [
            IconButton(
              icon: const Icon(HugeIconsStroke.settings02),
              onPressed: _ttsController.isInitialized ? _showSettings : null,
              tooltip: 'Settings',
            ),
          ],
        ),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _ttsController,
            builder: (context, _) {
              return Column(
                children: [
                  // Text input area
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.only(
                        top: 16,
                        left: 16,
                        right: 16,
                      ),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Single TextField with integrated highlighting
                          // No component switching = no visual glitches
                          TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            scrollController: _scrollController,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            // Read-only during playback/pause
                            readOnly: _ttsController.isPlaying ||
                                _ttsController.isPaused,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.6),
                            decoration: const InputDecoration(
                              hintText: 'Paste or type your text here...',
                            ),
                            onChanged: (_) {
                              // Reset extracted info if user manually edits
                              if (_sourceUrl != null) {
                                _extractedTitle = null;
                                _sourceUrl = null;
                              }
                              setState(() {});
                            },
                          ),
                          // Loading overlay for URL extraction
                          if (_isExtractingUrl)
                            Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.9),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Extracting content...',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Paste button (shown when empty and not loading)
                          if (_textController.text.isEmpty && !_isExtractingUrl)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FilledButton.icon(
                                onPressed: _pasteText,
                                icon: const Icon(
                                  HugeIconsStroke.copy01,
                                  size: 18,
                                ),
                                label: const Text('Paste'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Clear button & Character count (only show when there's text)
                  if (_textController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Clear button
                          GestureDetector(
                            onTap: _clearText,
                            child: Text(
                              'Clear input',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          // Character count
                          Text(
                            '${_textController.text.length} characters',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Playback controls
                  PlaybackControls(
                    controller: _ttsController,
                    text: _textController.text,
                    enabled:
                        _ttsController.isInitialized &&
                        _textController.text.isNotEmpty,
                    onPlayPressed: () => _onPlayPressed(_textController.text),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
