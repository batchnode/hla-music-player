import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:math';
import 'dart:io';

import '../models/song.dart';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';

class LibraryPage extends StatefulWidget {
  final ValueChanged<int>? onSongClicked;

  const LibraryPage({super.key, this.onSongClicked});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  String _searchQuery = "";

  String _normalize(String text) {
    // Remove punctuation, special characters and whitespace for 'fuzzy' matching
    return text.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]"), "");
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final allSongs = musicProvider.songs;
    final layoutConfigs = musicProvider.libraryLayoutConfigs;

    final normalizedQuery = _normalize(_searchQuery);

    final filteredSongs = allSongs.where((s) {
      if (normalizedQuery.isEmpty) return true;

      // Combine all searchable metadata into one normalized sweep
      final combinedMetadata = _normalize(
        "${s.title} ${s.artist} ${s.album ?? ''}",
      );
      return combinedMetadata.contains(normalizedQuery);
    }).toList();

    return VisibilityDetector(
      key: const Key('library-page-visibility'),
      onVisibilityChanged: (visibilityInfo) {
        // Removed redundant layout regeneration to prevent blinking
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                title: const Text(
                  'Library',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: -1,
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search Library',
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colors.white24,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.white24,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    setState(() => _searchQuery = ""),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withAlpha((255 * 0.05).round()),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (!musicProvider.hasPermission)
                SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 50),
                        const Text("Permissions required to scan music"),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: musicProvider.checkAndRequestPermissions,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                          ),
                          child: const Text(
                            "Grant Permissions",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (filteredSongs.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        _searchQuery.isEmpty
                            ? "No songs found on device"
                            : "No matches found",
                      ),
                    ),
                  ),
                )
              else if (layoutConfigs.length >= filteredSongs.length)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  sliver: SliverToBoxAdapter(
                    child: StaggeredGrid.count(
                      crossAxisCount: 4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      children: List.generate(filteredSongs.length, (index) {
                        // When searching, we might not match the global layout exactly,
                        // so we fall back to a standard 2x1 if the global config is missing
                        final config = _searchQuery.isEmpty
                            ? layoutConfigs[index]
                            : {'cross': 2, 'main': 1};

                        return StaggeredGridTile.count(
                          crossAxisCellCount: config['cross']!,
                          mainAxisCellCount: config['main']!,
                          child: BentoSongTile(
                            song: filteredSongs[index],
                            crossAxisCount: config['cross']!,
                            mainAxisCount: config['main']!,
                            onTap: () {
                              musicProvider.setCurrentCollection(
                                _searchQuery.isEmpty
                                    ? "Library"
                                    : "Search Results",
                                newQueue: filteredSongs,
                              );
                              musicProvider.playSong(index);
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }
}

class BentoSongTile extends StatefulWidget {
  final Song song;
  final int crossAxisCount;
  final int mainAxisCount;
  final VoidCallback? onTap;

  const BentoSongTile({
    super.key,
    required this.song,
    required this.crossAxisCount,
    required this.mainAxisCount,
    this.onTap,
  });

  @override
  State<BentoSongTile> createState() => _BentoSongTileState();
}

class _BentoSongTileState extends State<BentoSongTile>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getMonochromeColor(int id) {
    final shades = [
      const Color(0xFF080808),
      const Color(0xFF101010),
      const Color(0xFF181818),
      const Color(0xFF202020),
      const Color(0xFF282828),
    ];
    return shades[id % shades.length];
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;
    final showAlbumArt = settings.showAlbumArt;

    final fallbackColor = isMonochrome
        ? _getMonochromeColor(widget.song.id)
        : (widget.song.color ?? Colors.grey[900]!);

    final isVertical = widget.mainAxisCount > widget.crossAxisCount;
    final isSmall = widget.mainAxisCount == 1 && widget.crossAxisCount == 1;
    final isLarge = widget.mainAxisCount >= 2 && widget.crossAxisCount >= 2;

    // Artistic Curation Logic:
    final artisticRandom = Random(widget.song.id);
    bool shouldShowArtArtistically = true;

    if (isSmall) {
      shouldShowArtArtistically = false; // Never on 1x1
    } else if (widget.mainAxisCount == 1 || widget.crossAxisCount == 1) {
      // List Mode (Tier 3 or narrow blocks): Strict 40% chance
      shouldShowArtArtistically = artisticRandom.nextDouble() < 0.4;
    } else if (widget.mainAxisCount == 4 && widget.crossAxisCount == 4) {
      shouldShowArtArtistically = true; // Always on giant blocks
    } else if (isLarge) {
      shouldShowArtArtistically =
          artisticRandom.nextDouble() < 0.5; // 50% on standard squares
    } else {
      shouldShowArtArtistically =
          artisticRandom.nextDouble() < 0.7; // 70% on rectangles
    }

    final bool effectivelyShowArt = showAlbumArt && shouldShowArtArtistically;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _animationController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _animationController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _animationController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(
              color: _isPressed
                  ? Colors.white.withAlpha((255 * 0.4).round())
                  : Colors.white.withAlpha((255 * 0.05).round()),
              width: _isPressed ? 1.5 : 1,
            ),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.white.withAlpha((255 * 0.1).round()),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Base Fallback Layer (Inside Clipping)
                Container(color: fallbackColor),

                // 2. Artwork Layer (Curation-Aware)
                if (effectivelyShowArt)
                  widget.song.externalArtPath != null &&
                          File(widget.song.externalArtPath!).existsSync()
                      ? Image.file(
                          File(widget.song.externalArtPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      : QueryArtworkWidget(
                          id: widget.song.id,
                          type: ArtworkType.AUDIO,
                          format: ArtworkFormat.JPEG,
                          artworkWidth: double.infinity,
                          artworkHeight: double.infinity,
                          artworkFit: BoxFit.cover,
                          artworkBorder: BorderRadius.circular(24.0),
                          keepOldArtwork: true,
                          nullArtworkWidget: const SizedBox.shrink(),
                        ),

                // 3. Random Pattern Background (Only in Monochrome)
                if (isMonochrome)
                  Opacity(
                    opacity: 0.2,
                    child: CustomPaint(
                      painter: PatternPainter(
                        seed: widget.song.id,
                        color: Colors.white.withAlpha((255 * 0.15).round()),
                      ),
                    ),
                  ),

                // 4. Text Scrim for Readability
                if (isVertical)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withAlpha((255 * 0.1).round()),
                          Colors.black.withAlpha((255 * 0.7).round()),
                        ],
                      ),
                    ),
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 12.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.song.artist,
                              style: TextStyle(
                                color: Colors.white.withAlpha(
                                  (255 * 0.6).round(),
                                ),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withAlpha((255 * 0.9).round()),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSmall)
                            SizedBox(
                              height: 20,
                              child: MarqueeWidget(
                                text: widget.song.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            Text(
                              widget.song.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            widget.song.artist,
                            style: TextStyle(
                              color: Colors.white.withAlpha(
                                (255 * 0.6).round(),
                              ),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
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

class MarqueeWidget extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MarqueeWidget({super.key, required this.text, required this.style});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}

class PatternPainter extends CustomPainter {
  final int seed;
  final Color color;

  PatternPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final List<Offset> points = [];

    // Draw background grid lines first
    for (int i = 0; i < 8; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      points.add(Offset(x, y));

      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = color.withAlpha((255 * 0.02).round())
          ..strokeWidth = 0.2,
      );
    }

    for (int i = 0; i < 12; i++) {
      final type = random.nextInt(4);
      final fillPaint = Paint()
        ..color = Color.lerp(
          Colors.black,
          Colors.white,
          random.nextDouble() * 0.1,
        )!.withAlpha((255 * 0.05).round())
        ..style = PaintingStyle.fill;

      Offset center = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );

      if (type == 0) {
        double radius = random.nextDouble() * 30 + 5;
        canvas.drawCircle(center, radius, fillPaint);
        canvas.drawCircle(center, radius, strokePaint);
        // Intersecting line
        canvas.drawLine(
          center,
          points[random.nextInt(points.length)],
          strokePaint,
        );
      } else if (type == 1) {
        Rect rect = Rect.fromCenter(
          center: center,
          width: random.nextDouble() * 40 + 10,
          height: random.nextDouble() * 40 + 10,
        );
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        // Intersecting line
        canvas.drawLine(
          rect.topLeft,
          points[random.nextInt(points.length)],
          strokePaint,
        );
      } else if (type == 2) {
        Path path = Path();
        path.moveTo(center.dx, center.dy);
        path.lineTo(center.dx + 20, center.dy + 40);
        path.lineTo(center.dx - 20, center.dy + 40);
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      } else {
        // Just a connector line
        canvas.drawLine(
          points[random.nextInt(points.length)],
          points[random.nextInt(points.length)],
          strokePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
