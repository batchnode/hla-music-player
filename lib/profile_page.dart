import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';
import 'models/song.dart';

class ProfilePage extends StatelessWidget {
  final VoidCallback? onSwipeSettings;

  const ProfilePage({super.key, this.onSwipeSettings});

  String _formatTotalDuration(List<Song> songs) {
    int totalMs = 0;
    for (var s in songs) {
      totalMs += s.duration ?? 0;
    }
    final duration = Duration(milliseconds: totalMs);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    }
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final isMonochrome = settings.isMonochrome;

    final recentSongs = musicProvider.recents.take(2).toList();

    // Calculate Insights
    String topGenre = "Mixed";
    int maxCount = 0;
    musicProvider.genreMap.forEach((key, value) {
      if (value.length > maxCount) {
        maxCount = value.length;
        topGenre = key;
      }
    });

    final int labeledCount =
        musicProvider.songs.length - musicProvider.noLabel.length;
    final double healthPercent = musicProvider.songs.isEmpty
        ? 0
        : (labeledCount / musicProvider.songs.length) * 100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity! > 200) {
                onSwipeSettings?.call();
              }
            },
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverAppBar(
                    floating: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: false,
                    title: Text(
                      'Library Insights',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 32,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverToBoxAdapter(
                      child: StaggeredGrid.count(
                        crossAxisCount: 4,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          // 1. System Identity Block
                          StaggeredGridTile.count(
                            crossAxisCellCount: 4,
                            mainAxisCellCount: 1.6,
                            child: _buildBentoBlock(
                              isMonochrome,
                              child: Row(
                                children: [
                                  _buildDecorativeIcon(
                                    isMonochrome,
                                    Icons.analytics_rounded,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'System Status',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        Text(
                                          musicProvider.isPlaying
                                              ? 'Active: ${musicProvider.currentSong?.title}'
                                              : 'Library Synced & Ready',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isMonochrome
                                                ? Colors.white38
                                                : Colors.white54,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 2. Global Totals (Quick Statistics)
                          StaggeredGridTile.count(
                            crossAxisCellCount: 4,
                            mainAxisCellCount: 0.8,
                            child: _buildBentoBlock(
                              isMonochrome,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatItem(
                                    musicProvider.songs.length,
                                    'Tracks',
                                  ),
                                  _buildStatItem(
                                    musicProvider.artistMap.length,
                                    'Artists',
                                  ),
                                  _buildStatItem(
                                    musicProvider.albumMap.length,
                                    'Albums',
                                  ),
                                  _buildStatItem(
                                    musicProvider.genreMap.length,
                                    'Genres',
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 3. Recently Played
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.8,
                            child: _buildBentoBlock(
                              isMonochrome,
                              title: 'Recent Activity',
                              icon: Icons.history_rounded,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: recentSongs.isEmpty
                                    ? [
                                        const Text(
                                          'No history',
                                          style: TextStyle(
                                            color: Colors.white24,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ]
                                    : recentSongs
                                        .map((s) => _buildMiniSongItem(s))
                                        .toList(),
                              ),
                            ),
                          ),

                          // 4. Metadata Health
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.8,
                            child: _buildBentoBlock(
                              isMonochrome,
                              title: 'Library Health',
                              icon: Icons.health_and_safety_rounded,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${healthPercent.toInt()}%',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    'LABELED',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.white38,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: healthPercent / 100,
                                      backgroundColor: Colors.white10,
                                      color: isMonochrome
                                          ? Colors.white38
                                          : Colors.deepPurpleAccent,
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 5. Playback Duration
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.2,
                            child: _buildBentoBlock(
                              isMonochrome,
                              title: 'Collection Runtime',
                              icon: Icons.timer_rounded,
                              child: Center(
                                child: Text(
                                  _formatTotalDuration(musicProvider.songs),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 6. Dominant Genre
                          StaggeredGridTile.count(
                            crossAxisCellCount: 2,
                            mainAxisCellCount: 1.2,
                            child: _buildBentoBlock(
                              isMonochrome,
                              title: 'Main Genre',
                              icon: Icons.auto_awesome_rounded,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    topGenre,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            child: GestureDetector(
              onTap: onSwipeSettings,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMonochrome
                      ? Colors.white.withAlpha((255 * 0.05).round())
                      : Colors.deepPurpleAccent.withAlpha((255 * 0.1).round()),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withAlpha((255 * 0.05).round()),
                  ),
                ),
                child: Icon(
                  Icons.settings_rounded,
                  color: isMonochrome ? Colors.white70 : Colors.deepPurpleAccent,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeIcon(bool isMonochrome, IconData icon) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isMonochrome
            ? Colors.white10
            : Colors.deepPurpleAccent.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        size: 24,
        color: isMonochrome ? Colors.white70 : Colors.deepPurpleAccent,
      ),
    );
  }

  Widget _buildStatItem(int count, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: Colors.white38,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoBlock(
    bool isMonochrome, {
    String? title,
    IconData? icon,
    Widget? child,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF121212),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withAlpha((255 * 0.05).round()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 10,
                    color: isMonochrome
                        ? Colors.white38
                        : Colors.deepPurpleAccent,
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: isMonochrome
                          ? Colors.white38
                          : Colors.deepPurpleAccent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (child != null) Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildMiniSongItem(Song song) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            song.artist,
            style: const TextStyle(fontSize: 9, color: Colors.white38),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
