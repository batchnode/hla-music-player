import 'package:flutter/material.dart' hide RepeatMode;
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:math';
import 'dart:io';
import '../models/song.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';
import 'equalizer_page.dart';
import 'library_page.dart';
import 'profile_page.dart';

class NowPlayingPage extends StatefulWidget {
  final VoidCallback? onMinimize;
  final VoidCallback? onGoToLibrary;
  final VoidCallback? onGoToEqualizer;
  final VoidCallback? onGoToSettings;

  const NowPlayingPage({
    super.key,
    this.onMinimize,
    this.onGoToLibrary,
    this.onGoToEqualizer,
    this.onGoToSettings,
  });

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  PageController? _verticalPageController;
  late PageController _hPlayerController;
  late PageController _hLyricsController;
  final ScrollController _lyricsScrollController = ScrollController();
  double? _dragValue;
  bool _isSilentLoading = false;
  bool _verticalScrollEnabled = true;
  bool _isNavLocked = false; // Start unlocked so gestures work by default

  @override
  void initState() {
    super.initState();
    _verticalPageController = PageController(initialPage: 0);
    _hPlayerController = PageController(initialPage: 1);
    _hLyricsController = PageController(initialPage: 1);

    _hPlayerController.addListener(
      () => _handleHorizontalScroll(_hPlayerController, isPlayer: true),
    );
    _hLyricsController.addListener(
      () => _handleHorizontalScroll(_hLyricsController, isPlayer: false),
    );
  }

  void _handleHorizontalScroll(
    PageController controller, {
    required bool isPlayer,
  }) {
    if (_isSilentLoading) return;

    // Guard: Only allow silent loads if the player is actually expanded
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    if (!musicProvider.isFullPlayerExpanded) return;

    final page = controller.page ?? 1.0;
    final offset = (page - 1.0).abs();

    // Lock vertical scroll if we are swiping horizontally - Increase threshold to 0.1
    if (offset > 0.1 && _verticalScrollEnabled) {
      setState(() => _verticalScrollEnabled = false);
    } else if (offset <= 0.1 && !_verticalScrollEnabled) {
      setState(() => _verticalScrollEnabled = true);
    }

    // Trigger silent load at 85% (0.15 or 1.85)
    if (page <= 0.15) {
      _triggerSilentLoad(0);
    } else if (page >= 1.85) {
      _triggerSilentLoad(isPlayer ? 1 : 3);
    }
  }

  void _triggerSilentLoad(int targetBaseIndex) {
    if (_isSilentLoading) return;
    _isSilentLoading = true;

    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    // Sync the OTHER horizontal controller to match the current one
    // to prevent content jumping during the vertical slide
    if (_hPlayerController.hasClients && _hLyricsController.hasClients) {
      final double? activePage =
          _hPlayerController.hasClients &&
              _hPlayerController.position.hasContentDimensions
          ? _hPlayerController.page
          : (_hLyricsController.hasClients &&
                    _hLyricsController.position.hasContentDimensions
                ? _hLyricsController.page
                : 1.0);

      if (activePage != null) {
        final int targetPage = activePage.round();
        if (_hPlayerController.hasClients) {
          _hPlayerController.jumpToPage(targetPage);
        }
        if (_hLyricsController.hasClients) {
          _hLyricsController.jumpToPage(targetPage);
        }
      }
    }

    musicProvider.jumpToPage(targetBaseIndex);
    widget.onMinimize?.call();

    // DELAYED RESET: Move all state changes here to prevent "flashing" while sliding
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        _verticalPageController?.jumpToPage(0);
        if (_hPlayerController.hasClients) _hPlayerController.jumpToPage(1);
        if (_hLyricsController.hasClients) _hLyricsController.jumpToPage(1);
        setState(() {
          _isSilentLoading = false;
          _verticalScrollEnabled = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _verticalPageController?.dispose();
    _hPlayerController.dispose();
    _hLyricsController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _onMinimize() {
    _verticalPageController?.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn,
    );
    widget.onMinimize?.call();

    // Safety reset for horizontal controllers
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (_hPlayerController.hasClients) _hPlayerController.jumpToPage(1);
        if (_hLyricsController.hasClients) _hLyricsController.jumpToPage(1);
      }
    });
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return "--:--";
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final song = musicProvider.currentSong;

    if (song == null) {
      return const Scaffold(body: Center(child: Text("No song playing")));
    }

    // Vertical physics logic:
    // 1. From Player Page (0): Always allow scrolling down to Lyrics.
    // 2. From Lyrics Page (1): Only allow scrolling up if NOT locked.
    final ScrollPhysics vPhysics = _verticalScrollEnabled
        ? const BouncingScrollPhysics()
        : const NeverScrollableScrollPhysics();

    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _verticalPageController,
        scrollDirection: Axis.vertical,
        // The PageView should generally be scrollable unless we are mid-horizontal-swipe
        physics: vPhysics,
        itemBuilder: (context, index) {
          final bool isPlayerPage = index % 2 == 0;

          if (isPlayerPage) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                // Manual swipe up to lyrics
                if (details.primaryVelocity! < -500) {
                  _verticalPageController?.nextPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutQuart,
                  );
                }
                // Swipe down to minimize
                if (details.primaryVelocity! > 500) {
                  _onMinimize();
                }
              },
              child: PageView(
                controller: _hPlayerController,
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox.expand(child: EqualizerPage()),
                  _buildNowPlayingView(context, song, musicProvider),
                  SizedBox.expand(
                    child: LibraryPage(
                      onSongClicked: (idx) {
                        musicProvider.setCurrentCollection(
                          "Library",
                          newQueue: musicProvider.songs,
                        );
                        musicProvider.playSong(idx);
                      },
                    ),
                  ),
                ],
              ),
            );
          } else {
            // On lyrics page, we respect the _isNavLocked for vertical PageView interaction
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // If locked, we prevent the PageView from seeing vertical scrolls
                if (_isNavLocked) return true;
                return false;
              },
              child: PageView(
                controller: _hLyricsController,
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox.expand(child: EqualizerPage()),
                  _buildLyricsView(context, song),
                  const SizedBox.expand(child: ProfilePage()),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildNowPlayingView(
    BuildContext context,
    Song song,
    MusicProvider provider,
  ) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: isMonochrome
                ? const Color(0xFF050505)
                : (song.color ?? Colors.deepPurple).withAlpha(
                    (255 * 0.05).round(),
                  ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Text(
                  "PLAYING FROM: ${provider.currentCollection.toUpperCase()}",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: isMonochrome
                        ? Colors.white.withAlpha((255 * 0.3).round())
                        : Colors.white24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(flex: 2),
                _buildAlbumArt(song, settings),
                const Spacer(flex: 2),
                _buildSongInfo(song, isMonochrome),
                const SizedBox(height: 30),
                _buildProgressBar(provider),
                const SizedBox(height: 20),
                _buildControls(provider, isMonochrome),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumArt(Song song, SettingsProvider settings) {
    final showAlbumArt = settings.showAlbumArt;
    final isMonochrome = settings.isMonochrome;
    final size = MediaQuery.of(context).size;
    final artSize = min(size.width * 0.75, size.height * 0.35);

    final fallbackColor = isMonochrome
        ? const Color(0xFF1A1A1A)
        : (song.color ?? Colors.grey[900]!);

    return Container(
      width: artSize,
      height: artSize,
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(
              (255 * (isMonochrome ? 0.8 : 0.5)).round(),
            ),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
        border: Border.all(color: Colors.white.withAlpha((255 * 0.05).round())),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: showAlbumArt
            ? (song.externalArtPath != null &&
                      File(song.externalArtPath!).existsSync()
                  ? Image.file(
                      File(song.externalArtPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : QueryArtworkWidget(
                      id: song.id,
                      type: ArtworkType.AUDIO,
                      format: ArtworkFormat.JPEG,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.circular(32),
                      keepOldArtwork: true,
                      nullArtworkWidget: Container(
                        color: fallbackColor,
                        child: Icon(
                          Icons.music_note,
                          size: artSize * 0.4,
                          color: Colors.white.withAlpha((255 * 0.1).round()),
                        ),
                      ),
                    ))
            : Container(
                color: fallbackColor,
                child: Icon(
                  Icons.music_note,
                  size: artSize * 0.4,
                  color: Colors.white.withAlpha((255 * 0.1).round()),
                ),
              ),
      ),
    );
  }

  Widget _buildSongInfo(Song song, bool isMonochrome) {
    return Column(
      children: [
        Text(
          song.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isMonochrome
                ? Colors.white.withAlpha((255 * 0.9).round())
                : Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          song.artist,
          style: TextStyle(
            fontSize: 18,
            color: isMonochrome
                ? Colors.white.withAlpha((255 * 0.4).round())
                : Colors.white54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildProgressBar(MusicProvider provider) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isMonochrome = settings.isMonochrome;
    final position = provider.currentPosition;
    final duration = provider.currentDuration;

    // Use milliseconds for smoother slider
    final double currentMs = (_dragValue ?? position.inMilliseconds.toDouble())
        .clamp(0.0, duration.inMilliseconds.toDouble());
    final double totalMs = max(currentMs, duration.inMilliseconds.toDouble());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: isMonochrome
                  ? Colors.white
                  : Colors.deepPurpleAccent,
              inactiveTrackColor: isMonochrome
                  ? Colors.white.withAlpha((255 * 0.1).round())
                  : Colors.white10,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: currentMs,
              max: totalMs,
              onChanged: (val) {
                setState(() {
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                provider.seek(Duration(milliseconds: val.toInt()));
                setState(() {
                  _dragValue = null;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(
                    _dragValue != null
                        ? Duration(milliseconds: _dragValue!.toInt())
                        : position,
                  ),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(MusicProvider provider, bool isMonochrome) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            provider.isShuffleEnabled ? Icons.shuffle_rounded : Icons.shuffle,
            color: provider.isShuffleEnabled
                ? (isMonochrome ? Colors.white : Colors.deepPurpleAccent)
                : Colors.white24,
          ),
          onPressed: provider.toggleShuffle,
        ),
        IconButton(
          icon: Icon(
            Icons.skip_previous_rounded,
            size: 40,
            color: isMonochrome
                ? Colors.white.withAlpha((255 * 0.8).round())
                : Colors.white,
          ),
          onPressed: provider.playPrevious,
        ),
        GestureDetector(
          onTap: provider.togglePlay,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isMonochrome
                  ? Colors.white.withAlpha((255 * 0.9).round())
                  : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              provider.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: Colors.black,
              size: 36,
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            size: 40,
            color: isMonochrome
                ? Colors.white.withAlpha((255 * 0.8).round())
                : Colors.white,
          ),
          onPressed: provider.playNext,
        ),
        IconButton(
          icon: Icon(
            provider.repeatMode == RepeatMode.one
                ? Icons.repeat_one_rounded
                : (provider.repeatMode == RepeatMode.smart
                      ? Icons.auto_awesome_rounded
                      : Icons.repeat_rounded),
            color: provider.repeatMode != RepeatMode.off
                ? (isMonochrome ? Colors.white : Colors.deepPurpleAccent)
                : Colors.white24,
          ),
          onPressed: provider.toggleRepeat,
        ),
      ],
    );
  }

  Widget _buildLyricsView(BuildContext context, Song song) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;

    return Stack(
      children: [
        SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                "LYRICS",
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 4,
                  color: isMonochrome ? Colors.white38 : Colors.white24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              Expanded(
                child: musicProvider.isLoadingLyrics
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isMonochrome
                              ? Colors.white38
                              : Colors.deepPurpleAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _lyricsScrollController,
                        physics: _isNavLocked
                            ? const BouncingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 60),
                        child: Column(
                          children: [
                            Text(
                              musicProvider.currentLyrics ??
                                  "No lyrics found for this track.",
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.6,
                                fontWeight: FontWeight.w300,
                                color: isMonochrome
                                    ? Colors.white.withAlpha(
                                        (255 * 0.7).round(),
                                      )
                                    : Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
        // Navigation Lock Toggle
        Positioned(
          bottom: 40,
          right: 30,
          child: GestureDetector(
            onTap: () => setState(() => _isNavLocked = !_isNavLocked),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMonochrome
                    ? Colors.white.withAlpha((255 * 0.1).round())
                    : Colors.deepPurpleAccent.withAlpha((255 * 0.2).round()),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withAlpha((255 * 0.1).round()),
                ),
              ),
              child: Icon(
                _isNavLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: isMonochrome ? Colors.white70 : Colors.deepPurpleAccent,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
