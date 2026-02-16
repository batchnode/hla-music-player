import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';

class EqualizerPage extends StatefulWidget {
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSwipeUp;

  const EqualizerPage({super.key, this.onSwipeDown, this.onSwipeUp});

  @override
  State<EqualizerPage> createState() => _EqualizerPageState();
}

class _EqualizerPageState extends State<EqualizerPage> {
  final List<String> _freqs = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 500) widget.onSwipeDown?.call();
          if (details.primaryVelocity! < -500) widget.onSwipeUp?.call();
        },
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Equalizer',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                    Switch(
                      value: settings.isEqEnabled,
                      onChanged: (v) => settings.setEqEnabled(v),
                      activeThumbColor: isMonochrome
                          ? Colors.white
                          : Colors.deepPurpleAccent,
                      activeTrackColor: isMonochrome ? Colors.white24 : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Opacity(
                  opacity: settings.isEqEnabled ? 1.0 : 0.3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      5,
                      (index) => _buildFreqBand(index, settings, isMonochrome),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildKnobEffect(
                        'Bass Boost',
                        settings.bassBoost,
                        (v) => settings.setBassBoost(v),
                        settings.isEqEnabled,
                        isMonochrome,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildKnobEffect(
                        'Virtualizer',
                        settings.virtualizer,
                        (v) => settings.setVirtualizer(v),
                        settings.isEqEnabled,
                        isMonochrome,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreqBand(
    int index,
    SettingsProvider settings,
    bool isMonochrome,
  ) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: isMonochrome
                    ? Colors.white
                    : Colors.deepPurpleAccent,
                inactiveTrackColor: isMonochrome
                    ? Colors.white.withAlpha((255 * 0.1).round())
                    : Colors.white10,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: settings.eqBands[index],
                onChanged: settings.isEqEnabled
                    ? (v) => settings.setEqBand(index, v)
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _freqs[index],
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildKnobEffect(
    String label,
    double value,
    ValueChanged<double> onChanged,
    bool enabled,
    bool isMonochrome,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Slider(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: isMonochrome ? Colors.white : Colors.deepPurpleAccent,
          inactiveColor: isMonochrome
              ? Colors.white.withAlpha((255 * 0.1).round())
              : Colors.white10,
        ),
      ],
    );
  }
}
