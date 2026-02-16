import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';
import 'models/song.dart';
import 'category_list_page.dart';
import 'collection_detail_page.dart';

class PlaylistsPage extends StatefulWidget {
  final VoidCallback? onSwipeDown;
  final bool automaticallyImplyLeading;

  const PlaylistsPage({
    super.key,
    this.onSwipeDown,
    this.automaticallyImplyLeading = false,
  });

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final ScrollController _scrollController = ScrollController();

  void _navigateToCategory(
    BuildContext context,
    String title,
    MusicProvider musicProvider,
  ) {
    // Enforce "straight back to top" by resetting scroll before navigation
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Prepare data for all categories to support swiping
    Map<String, List<Map<String, dynamic>>> allData = {};

    // Artists
    List<Map<String, dynamic>> artistItems = [];
    musicProvider.artistMap.forEach((name, songs) {
      artistItems.add({
        'name': name,
        'subtitle': '${songs.length} Tracks',
        'icon': Icons.person_rounded,
        'songs': songs,
      });
    });
    allData['Artists'] = artistItems;

    // Genres
    List<Map<String, dynamic>> genreItems = [];
    musicProvider.genreMap.forEach((name, songs) {
      genreItems.add({
        'name': name,
        'subtitle': '${songs.length} Tracks',
        'icon': Icons.category_rounded,
        'songs': songs,
      });
    });
    allData['Genres'] = genreItems;

    // Albums
    List<Map<String, dynamic>> albumItems = [];
    musicProvider.albumMap.forEach((name, songs) {
      albumItems.add({
        'name': name,
        'subtitle': '${songs.length} Tracks',
        'icon': Icons.album_rounded,
        'songs': songs,
      });
    });
    allData['Albums'] = albumItems;

    final List<String> tier2Sequence = ['Artists', 'Albums', 'Genres'];
    final List<String> tier3Sequence = [
      'Most Played',
      'Favourites',
      'NoLabel',
      'Recent'
    ];

    if (tier2Sequence.contains(title)) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CategoryListPage(
            categoryTitle: title,
            items: allData[title]!,
            allCategoryTitles: tier2Sequence,
            allCategoryData: allData,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            var trait = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(trait),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: Duration.zero,
        ),
      );
    } else {
      List<Song> songs = [];
      String mapKey = title;
      if (title == 'Favourites') {
        songs = musicProvider.favourites;
      } else if (title == 'Recent') {
        songs = musicProvider.recents;
      } else if (title == 'NoLabel') {
        songs = musicProvider.noLabel;
      } else if (title == 'Most Played') {
        songs = musicProvider.recents; // fallback
      }

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              CollectionDetailPage(
            title: mapKey,
            icon: _getIconForCategory(title),
            songs: songs,
            allItemKeys: tier3Sequence,
            itemMap: {
              'Most Played': musicProvider.recents,
              'Favourites': musicProvider.favourites,
              'NoLabel': musicProvider.noLabel,
              'Recent': musicProvider.recents,
            },
            previousPage: const PlaylistsPage(automaticallyImplyLeading: false),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutQuart;
            var trait = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(trait),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 600),
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  IconData _getIconForCategory(String title) {
    switch (title) {
      case 'Artists':
        return Icons.person_rounded;
      case 'Genre':
        return Icons.category_rounded;
      case 'Albums':
        return Icons.album_rounded;
      case 'Favourites':
        return Icons.favorite_rounded;
      case 'Recent':
        return Icons.history_rounded;
      case 'NoLabel':
        return Icons.label_off_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final isMonochrome = settings.isMonochrome;

    final List<Map<String, dynamic>> playlists = [
      {
        'title': 'Artists',
        'color': isMonochrome ? Colors.white : Colors.blueAccent,
        'count': '${musicProvider.artistMap.length} Artists',
        'icon': Icons.person_rounded,
      },
      {
        'title': 'Genres',
        'color': isMonochrome ? Colors.white70 : Colors.tealAccent,
        'count': '${musicProvider.genreMap.length} Genres',
        'icon': Icons.category_rounded,
      },
      {
        'title': 'Albums',
        'color': isMonochrome ? Colors.white : Colors.orangeAccent,
        'count': '${musicProvider.albumMap.length} Albums',
        'icon': Icons.album_rounded,
      },
      {
        'title': 'Most Played',
        'color': isMonochrome ? Colors.white70 : Colors.deepPurpleAccent,
        'count': 'Top Tracks',
        'icon': Icons.trending_up_rounded,
      },
      {
        'title': 'Favourites',
        'color': isMonochrome ? Colors.white : Colors.pinkAccent,
        'count': '${musicProvider.favourites.length} Songs',
        'icon': Icons.favorite_rounded,
      },
      {
        'title': 'NoLabel',
        'color': isMonochrome ? Colors.white70 : Colors.grey,
        'count': '${musicProvider.noLabel.length} Items',
        'icon': Icons.label_off_rounded,
      },
      {
        'title': 'Recent',
        'color': isMonochrome ? Colors.white : Colors.cyanAccent,
        'count': 'History',
        'icon': Icons.history_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 500) widget.onSwipeDown?.call();
        },
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: false,
                automaticallyImplyLeading: false, // Explicitly set to false based on user feedback
                title: const Text(
                  'Collections',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                    letterSpacing: -1,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverToBoxAdapter(
                  child: StaggeredGrid.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: playlists.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final Map<String, dynamic> playlist = entry.value;
                      final String title = playlist['title'];

                      // Fetch the synchronized config
                      final config =
                          musicProvider.playlistsLayoutConfigs[index];
                      final int cross = config['cross']!;
                      final int main = config['main']!;

                      return StaggeredGridTile.count(
                        crossAxisCellCount: cross,
                        mainAxisCellCount: main,
                        child: GestureDetector(
                          onTap: () => _navigateToCategory(
                            context,
                            title,
                            musicProvider,
                          ),
                          child: _buildPlaylistTile(
                            playlist,
                            cross,
                            main,
                            isMonochrome,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(
    Map<String, dynamic> playlist,
    int cross,
    int main,
    bool isMonochrome,
  ) {
    final bool isSmall = main == 1;
    final bool isWide = cross == 4;
    final Color baseColor = playlist['color'];

    return Container(
      decoration: BoxDecoration(
        color: isMonochrome
            ? const Color(0xFF121212)
            : baseColor.withAlpha((255 * 0.1).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMonochrome
              ? Colors.white.withAlpha((255 * 0.05).round())
              : baseColor.withAlpha((255 * 0.15).round()),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background Icon
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                playlist['icon'],
                size: isSmall ? 60 : 100,
                color: isMonochrome
                    ? Colors.white.withAlpha((255 * 0.02).round())
                    : baseColor.withAlpha((255 * 0.05).round()),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(isSmall ? 16.0 : 20.0),
              child: isSmall
                  ? Row(
                      // Horizontal layout for small boxes
                      children: [
                        Icon(
                          playlist['icon'],
                          color: isMonochrome ? Colors.white70 : baseColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  playlist['title'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: isMonochrome
                                        ? Colors.white.withAlpha(
                                            (255 * 0.9).round(),
                                          )
                                        : Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                playlist['count'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMonochrome
                                      ? Colors.white.withAlpha(
                                          (255 * 0.3).round(),
                                        )
                                      : Colors.white.withAlpha(
                                          (255 * 0.4).round(),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      // Vertical layout for larger boxes
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          playlist['icon'],
                          color: isMonochrome ? Colors.white70 : baseColor,
                          size: isWide ? 32 : 24,
                        ),
                        const Spacer(),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            playlist['title'],
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: isWide ? 28 : 20,
                              color: isMonochrome
                                  ? Colors.white.withAlpha((255 * 0.9).round())
                                  : Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        Text(
                          playlist['count'],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isMonochrome
                                ? Colors.white.withAlpha((255 * 0.3).round())
                                : Colors.white.withAlpha((255 * 0.4).round()),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
