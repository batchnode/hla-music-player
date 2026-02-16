import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';

class CrossfadePage extends StatefulWidget {
  const CrossfadePage({super.key});

  @override
  State<CrossfadePage> createState() => _CrossfadePageState();
}

class _CrossfadePageState extends State<CrossfadePage> {
  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 500) {
            Navigator.pop(context); // L-R back
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Crossfade',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Set the duration of the transition between songs. A higher value creates a longer overlap between the ending track and the next track.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    '${settings.crossfadeValue.toInt()} Seconds',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.deepPurpleAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 8,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 12,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 24,
                    ),
                    activeTrackColor: Colors.deepPurpleAccent,
                    inactiveTrackColor: Colors.white10,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: settings.crossfadeValue,
                    min: 0,
                    max: 12,
                    divisions: 12,
                    onChanged: (val) {
                      settings.setCrossfade(val);
                    },
                  ),
                ),
                const Spacer(),
                const Center(
                  child: Text(
                    'Swipe L-R to Go Back',
                    style: TextStyle(color: Colors.white10, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
