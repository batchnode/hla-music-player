import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:io';
import 'providers/music_provider.dart';
import 'providers/settings_provider.dart';
import 'models/song.dart';
import 'library_page.dart';
import 'playlists_page.dart';
import 'category_list_page.dart';

class CollectionDetailPage extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<Song> songs;
  final List<String> allItemKeys;
  final Map<String, List<Song>> itemMap;
  final Widget? previousPage;

  const CollectionDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.songs,
    required this.allItemKeys,
    required this.itemMap,
    this.previousPage,
  });

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  late PageController _pageController;
  late String _nextKey;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    final int currentIdx = widget.allItemKeys.indexOf(widget.title);
    _nextKey = widget.allItemKeys[(currentIdx + 1) % widget.allItemKeys.length];

    _pageController = PageController(initialPage: 1);

    _pageController.addListener(() {
      if (_pageController.hasClients && !_isSwitching) {
        double page = _pageController.page ?? 1.0;

        // EXIT: Swipe L-R to Index 0 (Previous Page Copy)
        if (page <= 0.01) {
          _isSwitching = true;
          Navigator.of(context).pop();
        }
        // LOOP: Swipe R-L to Index 2 (Next Category Copy)
        else if (page >= 1.99) {
          _isSwitching = true;
          _triggerSilentReplace();
        }
      }
    });
  }

  void _triggerSilentReplace() {
    Widget nextWidget;
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    if (MusicProvider.tier2Sequence.contains(_nextKey)) {
      // Reconstruct data map for category list
      Map<String, List<Map<String, dynamic>>> allData =
          _buildCategoryData(musicProvider);
      nextWidget = CategoryListPage(
        categoryTitle: _nextKey,
        items: allData[_nextKey]!,
        allCategoryTitles: MusicProvider.tier2Sequence,
        allCategoryData: allData,
      );
    } else {
      nextWidget = CollectionDetailPage(
        title: _nextKey,
        icon: _getIconForCategory(_nextKey),
        songs: widget.itemMap[_nextKey] ?? [],
        allItemKeys: widget.allItemKeys,
        itemMap: widget.itemMap,
        previousPage: widget.previousPage,
      );
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, _, _) => nextWidget,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _buildCategoryData(
    MusicProvider musicProvider,
  ) {
    Map<String, List<Map<String, dynamic>>> allData = {};
    // Artists
    allData['Artists'] = musicProvider.artistMap.entries
        .map(
          (e) => {
            'name': e.key,
            'subtitle': '${e.value.length} Tracks',
            'icon': Icons.person_rounded,
            'songs': e.value,
          },
        )
        .toList();
    // Genres
    allData['Genres'] = musicProvider.genreMap.entries
        .map(
          (e) => {
            'name': e.key,
            'subtitle': '${e.value.length} Tracks',
            'icon': Icons.category_rounded,
            'songs': e.value,
          },
        )
        .toList();
    // Albums
    allData['Albums'] = musicProvider.albumMap.entries
        .map(
          (e) => {
            'name': e.key,
            'subtitle': '${e.value.length} Tracks',
            'icon': Icons.album_rounded,
            'songs': e.value,
          },
        )
        .toList();

    // Fill other categories too
    for (var key in MusicProvider.tier3Sequence) {
      final songs = widget.itemMap[key] ?? [];
      allData[key] = [
        {'name': key, 'songs': songs},
      ];
    }

    return allData;
  }

  IconData _getIconForCategory(String title) {
    switch (title) {
      case 'Most Played':
        return Icons.trending_up_rounded;
      case 'Favourites':
        return Icons.favorite_rounded;
      case 'NoLabel':
        return Icons.label_off_rounded;
      case 'Recent':
        return Icons.history_rounded;
      default:
        return Icons.music_note_rounded;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          if (index == 0) {
            return widget.previousPage ??
                const PlaylistsPage(
                  automaticallyImplyLeading: false,
                ); // Index 0: Buffer Copy
          }
          final int baseIndex = (index - 1) % widget.allItemKeys.length;
          final key = widget.allItemKeys[baseIndex];
          final songs = widget.itemMap[key] ?? [];
          return _buildDetailContent(context, key, songs);
        },
      ),
    );
  }

  Widget _buildDetailContent(
    BuildContext context,
    String key,
    List<Song> songs,
  ) {
    final settings = Provider.of<SettingsProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);
    final isMonochrome = settings.isMonochrome;
    final showAlbumArt = settings.showAlbumArt;

    final Song? firstSong = songs.isNotEmpty ? songs[0] : null;
    final fallbackColor = isMonochrome
        ? const Color(0xFF121212)
        : Colors.deepPurple.withAlpha((255 * 0.2).round());

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF050505),
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Artwork Background
                if (showAlbumArt && firstSong != null)
                  firstSong.externalArtPath != null &&
                          File(firstSong.externalArtPath!).existsSync()
                      ? Image.file(
                          File(firstSong.externalArtPath!),
                          fit: BoxFit.cover,
                        )
                      : QueryArtworkWidget(
                          id: firstSong.id,
                          type: ArtworkType.AUDIO,
                          format: ArtworkFormat.JPEG,
                          artworkFit: BoxFit.cover,
                          keepOldArtwork: true,
                          nullArtworkWidget: Container(color: fallbackColor),
                        )
                else
                  Container(color: fallbackColor),

                // 2. Readability Gradients
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF050505), Colors.transparent],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.4).round()),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),

                // 3. Header Text
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${songs.length} Tracks',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withAlpha((255 * 0.5).round()),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        if (songs.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No songs in this list',
                style: TextStyle(color: Colors.white24, fontSize: 16),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, idx) {
                  final song = songs[idx];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: SizedBox(
                      height: 80,
                      child: BentoSongTile(
                        song: song,
                        crossAxisCount: 2, // rectangular shape
                        mainAxisCount: 1, // rectangular shape
                        onTap: () {
                          musicProvider.setCurrentCollection(
                            key,
                            newQueue: songs,
                          );
                          musicProvider.playSong(idx);
                        },
                      ),
                    ),
                  );
                },
                childCount: songs.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }
}
