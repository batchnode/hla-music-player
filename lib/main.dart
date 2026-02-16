import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:audio_service/audio_service.dart'; // Add this import
import 'package:just_audio/just_audio.dart'; // Add this import
import 'services/audio_player_handler.dart'; // Add this import

import 'library_page.dart';
import 'now_playing_page.dart';
import 'playlists_page.dart';
import 'settings_page.dart';
import 'equalizer_page.dart';
import 'profile_page.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';

late AudioHandler _audioHandler; // Declare _audioHandler globally

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Wrap in try-catch to prevent initialization errors from causing a black screen
  try {
    final equalizer = AndroidEqualizer();
    final pipeline = AudioPipeline(androidAudioEffects: [equalizer]);
    final audioPlayer = AudioPlayer(audioPipeline: pipeline);
    _audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(audioPlayer, equalizer),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.ryanheise.bg_demo.channel',
        androidNotificationChannelName: 'Audio Service Demo',
        androidNotificationOngoing: true,
      ),
    );
  } catch (e) {
    debugPrint("Error initializing AudioService: $e");
    // Fallback or error handling can be added here
  }

  // Set orientations and run app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, MusicProvider>(
          create: (_) => MusicProvider(_audioHandler),
          update: (_, settings, music) {
            music!.updateSettings(settings);
            return music;
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;

    return MaterialApp(
      title: 'hla',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: isMonochrome ? Colors.grey : Colors.deepPurple,
        primaryColor: isMonochrome ? Colors.white : Colors.deepPurpleAccent,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF050505),
        colorScheme: ColorScheme.dark(
          primary: isMonochrome ? Colors.white : Colors.deepPurpleAccent,
          secondary: isMonochrome ? Colors.white70 : Colors.deepPurple,
          surface: const Color(0xFF0A0A0A),
        ),
      ),
      builder: (context, child) {
        return GlobalPlayerWrapper(
          key: const GlobalObjectKey('global_player_wrapper'),
          child: child!,
        );
      },
      home: const MyHomePage(),
    );
  }
}

class GlobalPlayerWrapper extends StatefulWidget {
  final Widget child;
  const GlobalPlayerWrapper({super.key, required this.child});

  @override
  State<GlobalPlayerWrapper> createState() => _GlobalPlayerWrapperState();
}

class _GlobalPlayerWrapperState extends State<GlobalPlayerWrapper>
    with TickerProviderStateMixin {
  final GlobalKey<State<NowPlayingPage>> _nowPlayingKey =
      GlobalKey<State<NowPlayingPage>>();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final musicProvider = Provider.of<MusicProvider>(context);
    final isPlayerExpanded = musicProvider.isFullPlayerExpanded;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          widget.child,
          if (musicProvider.isMiniPlayerVisible && !isPlayerExpanded)
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: MiniPlayer(
                onTap: () => musicProvider.setFullPlayerExpanded(true),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 600),
            curve: MyCurves.stack,
            top: isPlayerExpanded ? 0 : size.height,
            left: 0,
            width: size.width,
            height: size.height,
            child: Material(
              type: MaterialType.transparency,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => NowPlayingPage(
                      key: _nowPlayingKey,
                      onMinimize: () =>
                          musicProvider.setFullPlayerExpanded(false),
                      onGoToLibrary: () {
                        musicProvider.setFullPlayerExpanded(false);
                        musicProvider.goToLibrary();
                      },
                      onGoToEqualizer: () {
                        musicProvider.setFullPlayerExpanded(false);
                        musicProvider.goToEqualizer();
                      },
                      onGoToSettings: () {
                        musicProvider.setFullPlayerExpanded(false);
                        musicProvider.goToProfile();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context);
    final song = provider.currentSong!;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isMonochrome = settings.isMonochrome;

    return GestureDetector(
      onTap: onTap,
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! < -500) onTap();
      },
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity!.abs() > 500) provider.hideMiniPlayer();
      },
      child: Container(
        height: 75,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withAlpha((255 * 0.05).round()),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.6).round()),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: settings.showAlbumArt
                  ? (song.externalArtPath != null && File(song.externalArtPath!).existsSync()
                      ? Image.file(
                          File(song.externalArtPath!),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            format: ArtworkFormat.JPEG,
                            artworkWidth: 50,
                            artworkHeight: 50,
                            artworkFit: BoxFit.cover,
                            artworkBorder: BorderRadius.circular(12),
                            keepOldArtwork: true,
                            nullArtworkWidget: Container(
                              color: isMonochrome
                                  ? const Color(0xFF252525)
                                  : song.color,
                              width: 50,
                              height: 50,
                              child: const Icon(
                                Icons.music_note,
                                color: Colors.white24,
                                size: 20,
                              ),
                            ),
                          ),
                        )
                      : QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          format: ArtworkFormat.JPEG,
                          artworkWidth: 50,
                          artworkHeight: 50,
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.circular(12),
                          keepOldArtwork: true,
                          nullArtworkWidget: Container(
                            color: isMonochrome
                                ? const Color(0xFF252525)
                                : song.color,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white24,
                              size: 20,
                            ),
                          ),
                        ))
                  : Container(
                      color: isMonochrome
                          ? const Color(0xFF252525)
                          : song.color,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.music_note,
                        color: Colors.white24,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                  ),
                  Text(
                    song.artist,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                provider.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 34,
                color: isMonochrome ? Colors.white : Colors.deepPurpleAccent,
              ),
              onPressed: provider.togglePlay,
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late PageController _rootPageController;
  final int _initialPage = 1000;
  StreamSubscription? _navSubscription;
  StreamSubscription? _jumpSubscription;
  int _lastBaseIndex = 1; // Track previous page correctly

  // Vertical Transition State
  late AnimationController _verticalTransitionController;
  late Animation<Offset> _verticalSlideAnimation;
  int? _vTargetIndex;
  bool _isVTransitioning = false;

  @override
  void initState() {
    super.initState();
    _rootPageController = PageController(
      initialPage: _initialPage + 1,
    ); // Library

    _rootPageController.addListener(() {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      if (_rootPageController.hasClients && _rootPageController.page != null) {
        int currentBase = _rootPageController.page!.round() % 4;

        // Trigger regeneration only when reaching Profile (Index 3)
        // or when moving from Library (1) to something far away
        if (currentBase == 3 && _lastBaseIndex != 3) {
          musicProvider.regenerateLibraryLayout();
        }
        _lastBaseIndex = currentBase;
      }
    });

    _verticalTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    _verticalSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _verticalTransitionController,
            curve: Curves.easeInOutQuart,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      _navSubscription = musicProvider.navStream.listen((index) {
        _navigateToPage(index);
      });
      _jumpSubscription = musicProvider.jumpStream.listen((index) {
        _rootPageController.jumpToPage(_initialPage + index);
      });
    });
  }

  @override
  void dispose() {
    _rootPageController.dispose();
    _navSubscription?.cancel();
    _jumpSubscription?.cancel();
    _verticalTransitionController.dispose();
    super.dispose();
  }

  void _performVerticalTransition(int targetIndex, {required bool upward, required int finalHorizontalPageIndex}) {
    if (_isVTransitioning) return;

    _verticalTransitionController.duration = const Duration(milliseconds: 5000);
    _verticalTransitionController.reset();

    setState(() {
      _vTargetIndex = targetIndex;
      _isVTransitioning = true;
      _verticalSlideAnimation =
          Tween<Offset>(
            begin: upward ? const Offset(0, 1) : const Offset(0, -1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _verticalTransitionController,
              curve: Curves.easeInOutQuart,
            ),
          );
    });

    void transitionListener() {
      if (_verticalTransitionController.value >= 0.8) {
        _rootPageController.jumpToPage(_initialPage + finalHorizontalPageIndex);
        _verticalTransitionController.removeListener(transitionListener);
      }
    }

    _verticalTransitionController.addListener(transitionListener);

    _verticalTransitionController.forward().then((_) {
      if (mounted) {
        // Only auto-dismiss if target is NOT Settings (4)
        if (targetIndex != 4) {
          setState(() {
            _isVTransitioning = false;
          });
        }
      }
    });
  }

  void _navigateToPage(int targetBaseIndex) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    int currentIndex = _rootPageController.page!.round();
    int currentBase = currentIndex % 4;

    if (targetBaseIndex == 3 && currentBase != 3) {
      musicProvider.regenerateLibraryLayout();
    }

    // Vertical transition logic
    if ((currentBase == 0 && targetBaseIndex == 2)) {
      _performVerticalTransition(2, upward: true, finalHorizontalPageIndex: 2);
      return;
    } else if (currentBase == 2 && targetBaseIndex == 0) {
      _performVerticalTransition(0, upward: false, finalHorizontalPageIndex: 2);
      return;
    } else if (currentBase == 3 && targetBaseIndex == 4) {
      // 4 = Settings above Profile
      _performVerticalTransition(4, upward: false, finalHorizontalPageIndex: 3);
      return;
    } else if (currentBase == 4 && targetBaseIndex == 3) {
      _performVerticalTransition(3, upward: true, finalHorizontalPageIndex: 3);
      return;
    }

    int diff = targetBaseIndex - currentBase;
    if (diff > 2) diff -= 4;
    if (diff < -2) diff += 4;

    _rootPageController.animateToPage(
      currentIndex + diff,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutQuart,
    );
  }

  Widget _getVTargetWidget(int index) {
    switch (index) {
      case 0:
        return EqualizerPage(
          onSwipeUp: () => _navigateToPage(2),
          onSwipeDown: () => Provider.of<MusicProvider>(
            context,
            listen: false,
          ).setFullPlayerExpanded(true),
        );
      case 2:
        return PlaylistsPage(onSwipeDown: () => _navigateToPage(0));
      case 3:
        return const ProfilePage();
      case 4:
        return SettingsPage(
          onExitToCollections: () {
            _rootPageController
                .animateToPage(
              _rootPageController.page!.round() - 1, // Animate one page left from current
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOutQuart,
            )
                .then((_) {
              setState(() => _isVTransitioning = false);
            });
          },
          onSwipeToProfile: () => _navigateToPage(3),
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    return PopScope(
      canPop: false, // Prevent native pop
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) {
          // This should not happen if canPop is false, but as a safeguard
          return;
        }
        if (musicProvider.isPlaying) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Exit App?'),
                content: const Text(
                  'Music is currently playing. Do you want to exit the app or send it to the background?',
                ),
                actions: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(false), // Send to background
                    child: const Text('BACKGROUND'),
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(true), // Exit app
                    child: const Text('EXIT'),
                  ),
                ],
              );
            },
          );
          if (confirm ?? false) {
            musicProvider.hideMiniPlayer(); // Explicitly stop the audio and hide mini-player
            SystemNavigator.pop();
          }
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            PageView.builder(
              controller: _rootPageController,
              itemBuilder: (context, index) {
                final int baseIndex = index % 4;
                switch (baseIndex) {
                  case 0:
                    return EqualizerPage(
                      onSwipeUp: () => _navigateToPage(2),
                      onSwipeDown: musicProvider.isMiniPlayerVisible
                          ? () => musicProvider.setFullPlayerExpanded(true)
                          : null,
                    );
                  case 1:
                    return LibraryPage(
                      onSongClicked: (idx) {
                        musicProvider.setCurrentCollection(
                          "Library",
                          newQueue: musicProvider.songs,
                        );
                        musicProvider.playSong(idx);
                      },
                    );
                  case 2:
                    return PlaylistsPage(onSwipeDown: () => _navigateToPage(0));
                  case 3:
                    return ProfilePage(
                      onSwipeSettings: () => _navigateToPage(4),
                    );
                  default:
                    return const SizedBox();
                }
              },
            ),

            if (_isVTransitioning && _vTargetIndex != null)
              SlideTransition(
                key: ValueKey('vertical_slide_transition_key_$_vTargetIndex'),
                position: _verticalSlideAnimation,
                child: Container(
                  key: ValueKey('vertical_transition_container_key_$_vTargetIndex'),
                  color: const Color(0xFF050505),
                  child: _getVTargetWidget(_vTargetIndex!),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MyCurves {
  static const Curve stack = Cubic(0.2, 0.8, 0.2, 1.0);
}
