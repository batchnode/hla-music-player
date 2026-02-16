import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'about_page.dart';
import 'excluded_folders_page.dart';
import 'restricted_mode_page.dart';
import 'crossfade_page.dart';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';
import 'playlists_page.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback? onExitToCollections;
  final VoidCallback? onSwipeToProfile;

  const SettingsPage({
    super.key,
    this.onExitToCollections,
    this.onSwipeToProfile,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late PageController _hController;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();
    _hController = PageController(initialPage: 1);
    _hController.addListener(_handleHScroll);
  }

  void _handleHScroll() {
    if (_isExiting) return;
    if (_hController.hasClients && _hController.page != null) {
      if (_hController.page! <= 0.05) {
        _isExiting = true;
        widget.onExitToCollections?.call();
      }
    }
  }

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _hController,
      physics: const BouncingScrollPhysics(),
      children: [
        const PlaylistsPage(), // Index 0: Buffer for L-R exit
        _buildSettingsContent(context), // Index 1: Actual Settings
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final musicProvider = Provider.of<MusicProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          // Swipe up to return to Profile
          if (details.primaryVelocity! < -200) {
            widget.onSwipeToProfile?.call();
          }
        },
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 30),

              _buildSectionHeader('Library Management', settings.isMonochrome),
              _buildActionTile(
                Icons.folder_delete_outlined,
                'Excluded Folders',
                'Music from these folders will be hidden',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExcludedFoldersPage(),
                  ),
                ),
                hasChevron: true,
              ),
              _buildActionTile(
                Icons.folder_special_outlined,
                'Restricted Mode',
                'Play ONLY from selected directories',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RestrictedModePage(),
                  ),
                ),
                hasChevron: true,
              ),
              _buildActionTile(
                Icons.refresh_rounded,
                'Rescan Library',
                'Manually scan storage for new songs',
                () {
                  musicProvider.scanLocalSongs();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning for music...')),
                  );
                },
                hasChevron: false,
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('UI & Appearance', settings.isMonochrome),
              _buildSwitchTile(
                Icons.palette_outlined,
                'Enable Monochrome',
                'Use shades of black and gray for the UI',
                settings.isMonochrome,
                settings.isMonochrome,
                (val) => settings.setMonochrome(val),
              ),
              _buildSwitchTile(
                Icons.image_not_supported_outlined,
                'Disable Album Art',
                'Hide album covers throughout the app',
                !settings.showAlbumArt,
                settings.isMonochrome,
                (val) => settings.setShowAlbumArt(!val),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Audio Engine', settings.isMonochrome),
              _buildDropdownTile(
                Icons.high_quality_rounded,
                'Audio Quality',
                settings.audioQuality,
                [
                  'Low (96kbps)',
                  'Normal (160kbps)',
                  'High (320kbps)',
                  'Extreme (Lossless)',
                ],
                settings.isMonochrome,
                (val) => settings.setAudioQuality(val!),
              ),
              _buildActionTile(
                Icons.av_timer_rounded,
                'Crossfade',
                'Currently: ${settings.crossfadeValue.toInt()} seconds',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrossfadePage(),
                  ),
                ),
                hasChevron: true,
              ),
              _buildSwitchTile(
                Icons.layers_outlined,
                'Gapless Playback',
                'Eliminate silence between tracks',
                settings.gaplessPlayback,
                settings.isMonochrome,
                (val) => settings.setGaplessPlayback(val),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Playback Behavior', settings.isMonochrome),
              _buildSwitchTile(
                Icons.headset_off_rounded,
                'Stop on Disconnect',
                'Pause music when headphones unplugged',
                settings.stopOnDisconnect,
                settings.isMonochrome,
                (val) => settings.setStopOnDisconnect(val),
              ),
              _buildActionTile(
                Icons.timer_outlined,
                'Sleep Timer',
                musicProvider.sleepTimerSecondsRemaining > 0
                    ? 'Stopping in ${_formatTimer(musicProvider.sleepTimerSecondsRemaining)}'
                    : 'Not set',
                () => _showSleepTimerDialog(context, musicProvider),
                hasChevron: true,
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('System', settings.isMonochrome),
              _buildActionTile(
                Icons.storage_rounded,
                'Storage Usage',
                'Total music cache: 142MB',
                () {},
                hasChevron: false,
              ),
              _buildActionTile(
                Icons.info_outline_rounded,
                'About',
                'App version and philosophy',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AboutPage()),
                ),
                hasChevron: true,
              ),

              // Artwork Sync Section
              const SizedBox(height: 20),
              _buildSectionHeader('Artwork Sync', settings.isMonochrome),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.cloud_sync_rounded,
                  color: musicProvider.isSyncing
                      ? (settings.isMonochrome
                            ? Colors.white
                            : Colors.deepPurpleAccent)
                      : Colors.white70,
                ),
                title: const Text(
                  'Fetch Missing Artwork',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      musicProvider.isSyncing
                          ? musicProvider.syncStatus
                          : 'Download high-quality covers from MusicBrainz',
                      style: TextStyle(
                        color: musicProvider.isSyncing
                            ? (settings.isMonochrome
                                  ? Colors.white70
                                  : Colors.deepPurpleAccent)
                            : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    if (musicProvider.isSyncing) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: musicProvider.syncProgress,
                          backgroundColor: Colors.white10,
                          color: settings.isMonochrome
                              ? Colors.white
                              : Colors.deepPurpleAccent,
                          minHeight: 4,
                        ),
                      ),
                    ],
                    if (musicProvider.syncLogs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: TextButton.icon(
                          onPressed: () =>
                              _showSyncLogs(context, musicProvider),
                          icon: const Icon(Icons.list_alt_rounded, size: 14),
                          label: const Text(
                            'VIEW LOGS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: settings.isMonochrome
                                ? Colors.white38
                                : Colors.deepPurpleAccent.withAlpha(
                                    (255 * 0.6).round(),
                                  ),
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: musicProvider.isSyncing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white24,
                        ),
                        onPressed: () => musicProvider.syncMissingArtwork(),
                      ),
              ),

              _buildActionTile(
                Icons.info_outline_rounded,
                'Build Version',
                '1.0.0-stable',
                () {},
                hasChevron: false,
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncLogs(BuildContext context, MusicProvider musicProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0A0A),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sync Engine Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.copy_rounded,
                    color: Colors.white24,
                    size: 20,
                  ),
                  onPressed: () {
                    final allLogs = musicProvider.syncLogs.join('\n');
                    Clipboard.setData(ClipboardData(text: allLogs));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Logs copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white24,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Consumer<MusicProvider>(
            builder: (context, provider, child) => ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: provider.syncLogs.length,
              itemBuilder: (context, index) {
                final log = provider.syncLogs[index];
                final isError = log.contains('Error') || log.contains('Failed');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: isError
                          ? Colors.redAccent.withAlpha((255 * 0.8).round())
                          : Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showSleepTimerDialog(
    BuildContext context,
    MusicProvider musicProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Set Sleep Timer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerOption(context, musicProvider, 'Off', 0),
            _buildTimerOption(context, musicProvider, '15 Minutes', 15),
            _buildTimerOption(context, musicProvider, '30 Minutes', 30),
            _buildTimerOption(context, musicProvider, '45 Minutes', 45),
            _buildTimerOption(context, musicProvider, '60 Minutes', 60),
            _buildTimerOption(context, musicProvider, '90 Minutes', 90),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerOption(
    BuildContext context,
    MusicProvider provider,
    String label,
    int minutes,
  ) {
    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      onTap: () {
        provider.setSleepTimer(minutes);
        Navigator.pop(context);
      },
    );
  }

  String _formatTimer(int totalSeconds) {
    int minutes = totalSeconds ~/ 60;
    int seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildSectionHeader(String title, bool isMonochrome) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isMonochrome
              ? Colors.white.withAlpha((255 * 0.4).round())
              : Colors.deepPurpleAccent.withAlpha((255 * 0.7).round()),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    bool isMonochrome,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      secondary: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: isMonochrome ? Colors.white : Colors.deepPurpleAccent,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownTile(
    IconData icon,
    String title,
    String current,
    List<String> options,
    bool isMonochrome,
    ValueChanged<String?> onChanged,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      trailing: DropdownButton<String>(
        value: current,
        underline: const SizedBox(),
        dropdownColor: const Color(0xFF1A1A1A),
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: isMonochrome ? Colors.white70 : Colors.deepPurpleAccent,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    bool hasChevron = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      trailing: hasChevron
          ? const Icon(Icons.chevron_right, color: Colors.white10)
          : null,
    );
  }
}
