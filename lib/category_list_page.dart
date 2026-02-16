import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'dart:io';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';
import 'models/song.dart';
import 'collection_detail_page.dart';
import 'playlists_page.dart';

class CategoryListPage extends StatefulWidget {
  final String categoryTitle;
  final List<Map<String, dynamic>> items;
  final List<String> allCategoryTitles;
  final Map<String, List<Map<String, dynamic>>> allCategoryData;

  const CategoryListPage({
    super.key,
    required this.categoryTitle,
    required this.items,
    required this.allCategoryTitles,
    required this.allCategoryData,
  });

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> {
  late PageController _pageController;
  late String _nextCategory;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();

    final int currentIdx = widget.allCategoryTitles.indexOf(widget.categoryTitle);
    _nextCategory = widget.allCategoryTitles[(currentIdx + 1) % widget.allCategoryTitles.length];

    _pageController = PageController(initialPage: 1);

    _pageController.addListener(() {
      if (_pageController.hasClients && !_isSwitching) {
        double page = _pageController.page ?? 1.0;

        // EXIT: Swipe L-R to Index 0 (Collections Copy)
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
    // Determine target widget for replacement
    Widget nextWidget;
    if (_nextCategory == 'Artists' || _nextCategory == 'Genres' || _nextCategory == 'Albums') {
      nextWidget = CategoryListPage(
        categoryTitle: _nextCategory,
        items: widget.allCategoryData[_nextCategory]!,
        allCategoryTitles: widget.allCategoryTitles,
        allCategoryData: widget.allCategoryData,
      );
    } else {
      // These categories use the detail page widget
      nextWidget = CollectionDetailPage(
        title: _nextCategory,
        icon: _getIconForCategory(_nextCategory),
        songs: widget.allCategoryData[_nextCategory]?.isNotEmpty == true 
            ? widget.allCategoryData[_nextCategory]![0]['songs'] : [],
        allItemKeys: widget.allCategoryTitles,
        itemMap: _rebuildItemMap(),
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

  IconData _getIconForCategory(String title) {
    switch (title) {
      case 'Most Played': return Icons.trending_up_rounded;
      case 'Favourites': return Icons.favorite_rounded;
      case 'NoLabel': return Icons.label_off_rounded;
      case 'Recent': return Icons.history_rounded;
      default: return Icons.music_note_rounded;
    }
  }

  Map<String, List<Song>> _rebuildItemMap() {
    Map<String, List<Song>> map = {};
    widget.allCategoryData.forEach((key, items) {
      if (items.isNotEmpty && items[0]['songs'] != null) {
        map[key] = items[0]['songs'] as List<Song>;
      } else {
        map[key] = [];
      }
    });
    return map;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        children: [
          const PlaylistsPage(automaticallyImplyLeading: false), // Index 0: Tier 1 Copy
          _buildCategoryContent(context, widget.categoryTitle, widget.items, musicProvider), // Index 1: Original
          _buildCategoryContent(context, _nextCategory, widget.allCategoryData[_nextCategory] ?? [], musicProvider), // Index 2: Next Copy
        ],
      ),
    );
  }

  Widget _buildCategoryContent(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
    MusicProvider musicProvider,
  ) {
    final settings = Provider.of<SettingsProvider>(context);
    final isMonochrome = settings.isMonochrome;

    final List<Map<String, int>> layoutConfigs = musicProvider.getBentoLayoutFor(title, items.length);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          floating: true,
          backgroundColor: const Color(0xFF050505),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          sliver: SliverToBoxAdapter(
            child: StaggeredGrid.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: items.asMap().entries.map((entry) {
                final int idx = entry.key;
                final item = entry.value;
                final config = (idx < layoutConfigs.length)
                    ? layoutConfigs[idx]
                    : {'cross': 2, 'main': 2};

                return StaggeredGridTile.count(
                  crossAxisCellCount: config['cross']!,
                  mainAxisCellCount: config['main']!,
                  child: GestureDetector(
                    onTap: () =>
                        _enterDetailView(context, item, title, musicProvider),
                    child: _buildCategoryTile(
                      item,
                      isMonochrome,
                      config['cross']!,
                      config['main']!,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  void _enterDetailView(
    BuildContext context,
    Map<String, dynamic> item,
    String categoryTitle,
    MusicProvider musicProvider,
  ) {
    List<String> keys = [];
    Map<String, List<Song>> map = {};

    if (categoryTitle == 'Artists') {
      keys = musicProvider.artistKeys;
      map = musicProvider.artistMap;
    } else if (categoryTitle == 'Genres') {
      keys = musicProvider.genreKeys;
      map = musicProvider.genreMap;
    } else if (categoryTitle == 'Albums') {
      keys = musicProvider.albumKeys;
      map = musicProvider.albumMap;
    }

    final categoryItems = widget.allCategoryData[categoryTitle] ?? [];

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            CollectionDetailPage(
          title: item['name'],
          icon: item['icon'] ?? Icons.music_note_rounded,
          songs: item['songs'] ?? [],
          allItemKeys: keys,
          itemMap: map,
          previousPage:
              _buildCategoryContent(context, categoryTitle, categoryItems, musicProvider),
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

  Widget _buildCategoryTile(
    Map<String, dynamic> item,
    bool isMonochrome,
    int cross,
    int main,
  ) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final bool showAlbumArt = settings.showAlbumArt;
    final bool isWide = cross == 4;
    final bool isSmall = main == 1;

    final List<Song>? categorySongs = item['songs'] as List<Song>?;
    final Song? firstSong =
        (categorySongs?.isNotEmpty == true) ? categorySongs![0] : null;

    final List<Color> defaultColors = [
      Colors.deepPurpleAccent,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.pinkAccent,
    ];

    final Color randomColor =
        defaultColors[item['name'].hashCode % defaultColors.length];

    final Color fallbackColor = isMonochrome ? const Color(0xFF121212) : randomColor;

    return Container(
      decoration: BoxDecoration(
        color: fallbackColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withAlpha((255 * 0.05).round()),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (showAlbumArt && firstSong != null)
              firstSong.externalArtPath != null &&
                      File(firstSong.externalArtPath!).existsSync()
                  ? Image.file(
                      File(firstSong.externalArtPath!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    )
                  : QueryArtworkWidget(
                      id: firstSong.id,
                      type: ArtworkType.AUDIO,
                      format: ArtworkFormat.JPEG,
                      artworkWidth: double.infinity,
                      artworkHeight: double.infinity,
                      artworkFit: BoxFit.cover,
                      artworkBorder: BorderRadius.circular(28),
                      keepOldArtwork: true,
                      nullArtworkWidget: const SizedBox.shrink(),
                    ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha((255 * 0.1).round()),
                    Colors.black.withAlpha((255 * 0.8).round()),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmall ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    item['icon'] ?? Icons.person_rounded,
                    size: isWide ? 32 : (isSmall ? 20 : 24),
                    color: isMonochrome ? Colors.white70 : Colors.white,
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item['name'],
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: isWide ? 22 : (isSmall ? 16 : 20),
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Text(
                    item['subtitle'] ?? "",
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withAlpha((255 * 0.5).round()),
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
    );
  }
}
