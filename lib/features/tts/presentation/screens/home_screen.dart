import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons_pro/hugeicons.dart';

import '../../../../core/constants/app_constants.dart';
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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initTts();
    _ttsController.addListener(_handleTtsError);
  }

  Future<void> _initTts() async {
    await _ttsController.init();
    if (mounted) setState(() {});
  }

  void _handleTtsError() {
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
  }

  @override
  void dispose() {
    _ttsController.removeListener(_handleTtsError);
    _ttsController.dispose();
    _textController.dispose();
    _focusNode.dispose();
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

  void _clearText() {
    _textController.clear();
    _ttsController.stop();
    setState(() {});
  }

  Future<void> _pasteText() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null && clipboardData!.text!.isNotEmpty) {
      _textController.text = clipboardData.text!;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppConstants.appName),
          centerTitle: true,
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
                          TextField(
                            controller: _textController,
                            focusNode: _focusNode,
                            maxLines: null,
                            expands: true,
                            textAlignVertical: TextAlignVertical.top,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(height: 1.6),
                            decoration: const InputDecoration(
                              hintText: 'Paste or type your text here...',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          // Paste button (shown when empty)
                          if (_textController.text.isEmpty)
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
