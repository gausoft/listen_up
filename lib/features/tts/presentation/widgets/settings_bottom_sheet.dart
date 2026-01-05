import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../controllers/tts_controller.dart';

class SettingsBottomSheet extends StatefulWidget {
  final TtsController controller;

  const SettingsBottomSheet({
    super.key,
    required this.controller,
  });

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  late double _speechRate;
  late double _pitch;
  late double _volume;

  @override
  void initState() {
    super.initState();
    _speechRate = widget.controller.speechRate;
    _pitch = widget.controller.pitch;
    _volume = widget.controller.volume;
  }

  String _formatSpeed(double rate) {
    final displaySpeed = 0.5 + (rate * 1.5);
    return '${displaySpeed.toStringAsFixed(1)}x';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    TextButton(
                      onPressed: () async {
                        await widget.controller.resetToDefaults();
                        setState(() {
                          _speechRate = AppConstants.defaultSpeechRate;
                          _pitch = AppConstants.defaultPitch;
                          _volume = AppConstants.defaultVolume;
                        });
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Speed slider
                _SettingSlider(
                  label: 'Speed',
                  value: _speechRate,
                  min: AppConstants.minSpeechRate,
                  max: AppConstants.maxSpeechRate,
                  displayValue: _formatSpeed(_speechRate),
                  onChanged: (value) {
                    setState(() => _speechRate = value);
                    widget.controller.setSpeechRate(value);
                  },
                ),
                const SizedBox(height: 16),

                // Pitch slider
                _SettingSlider(
                  label: 'Pitch',
                  value: _pitch,
                  min: AppConstants.minPitch,
                  max: AppConstants.maxPitch,
                  displayValue: _pitch.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _pitch = value);
                    widget.controller.setPitch(value);
                  },
                ),
                const SizedBox(height: 16),

                // Volume slider
                _SettingSlider(
                  label: 'Volume',
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  displayValue: '${(_volume * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _volume = value);
                    widget.controller.setVolume(value);
                  },
                ),
                const SizedBox(height: 24),

                // Voice selector
                Text(
                  'Voice',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _VoiceSelector(controller: widget.controller),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SettingSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  const _SettingSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                displayValue,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _VoiceSelector extends StatefulWidget {
  final TtsController controller;

  const _VoiceSelector({required this.controller});

  @override
  State<_VoiceSelector> createState() => _VoiceSelectorState();
}

class _VoiceSelectorState extends State<_VoiceSelector> {
  String _selectedLocale = '';

  @override
  void initState() {
    super.initState();
    // Try to detect default locale
    _selectedLocale = _getDefaultLocale();
  }

  String _getDefaultLocale() {
    final voices = widget.controller.availableVoices;
    if (voices.isEmpty) return '';

    // Try to find French or English as default
    final frenchVoice = voices.firstWhere(
      (v) => v['locale']?.startsWith('fr') ?? false,
      orElse: () => {},
    );
    if (frenchVoice.isNotEmpty) return 'fr';

    final englishVoice = voices.firstWhere(
      (v) => v['locale']?.startsWith('en') ?? false,
      orElse: () => {},
    );
    if (englishVoice.isNotEmpty) return 'en';

    // Return first available
    return voices.first['locale']?.split('-').first ?? '';
  }

  List<String> _getUniqueLocales() {
    final locales = <String>{};
    for (final voice in widget.controller.availableVoices) {
      final locale = voice['locale'];
      if (locale != null) {
        locales.add(locale.split('-').first);
      }
    }
    return locales.toList()..sort();
  }

  List<Map<String, String>> _getVoicesForLocale(String locale) {
    return widget.controller.availableVoices
        .where((v) => v['locale']?.startsWith(locale) ?? false)
        .toList();
  }

  String _getLocaleName(String code) {
    const names = {
      'en': 'English',
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'nl': 'Dutch',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
      'ar': 'Arabic',
      'ru': 'Russian',
    };
    return names[code] ?? code.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final locales = _getUniqueLocales();
    final voices = _selectedLocale.isNotEmpty
        ? _getVoicesForLocale(_selectedLocale)
        : <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Language selector
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: locales.take(8).map((locale) {
            final isSelected = locale == _selectedLocale;
            return ChoiceChip(
              label: Text(_getLocaleName(locale)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedLocale = locale);
                }
              },
            );
          }).toList(),
        ),

        if (voices.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: voices.length,
              itemBuilder: (context, index) {
                final voice = voices[index];
                final isSelected =
                    widget.controller.currentVoice == voice['name'];

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voice['name'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          voice['locale'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        widget.controller.setVoice(voice);
                        setState(() {});
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
