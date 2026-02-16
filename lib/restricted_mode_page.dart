import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';

class RestrictedModePage extends StatefulWidget {
  const RestrictedModePage({super.key});

  @override
  State<RestrictedModePage> createState() => _RestrictedModePageState();
}

class _RestrictedModePageState extends State<RestrictedModePage> {
  Future<void> _pickFolder(SettingsProvider settings, MusicProvider music) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      if (!settings.restrictedFolders.contains(selectedDirectory)) {
        final newList = List<String>.from(settings.restrictedFolders)..add(selectedDirectory);
        await settings.setRestrictedFolders(newList);
        if (settings.isRestrictedMode) {
          music.scanLocalSongs();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final music = Provider.of<MusicProvider>(context, listen: false);

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Restricted Mode',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Switch(
                      value: settings.isRestrictedMode,
                      onChanged: (v) async {
                        await settings.setRestrictedMode(v);
                        music.scanLocalSongs();
                      },
                      activeThumbColor: Colors.deepPurpleAccent,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'When enabled, only music found in the directories below will be shown in your library. All other folders will be ignored.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Opacity(
                  opacity: settings.isRestrictedMode ? 1.0 : 0.3,
                  child: Consumer<SettingsProvider>(
                    builder: (context, settings, child) {
                      if (settings.restrictedFolders.isEmpty) {
                        return const Center(
                          child: Text(
                            'No restricted folders added',
                            style: TextStyle(color: Colors.white24),
                          ),
                        );
                      }
                      return ListView.builder(
                        itemCount: settings.restrictedFolders.length,
                        itemBuilder: (context, index) {
                          return _buildFolderTile(
                            context,
                            settings.restrictedFolders[index],
                            settings,
                            music,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Swipe L-R to Go Back',
                    style: TextStyle(color: Colors.white10, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: settings.isRestrictedMode
          ? FloatingActionButton(
              onPressed: () => _pickFolder(settings, music),
              backgroundColor: Colors.deepPurpleAccent,
              child: const Icon(Icons.create_new_folder_rounded),
            )
          : null,
    );
  }

  Widget _buildFolderTile(
    BuildContext context,
    String path,
    SettingsProvider settings,
    MusicProvider music,
  ) {
    return ListTile(
      leading: const Icon(
        Icons.folder_special_outlined,
        color: Colors.tealAccent,
      ),
      title: Text(
        path.split('/').last,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      subtitle: Text(
        path,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white38),
        onPressed: settings.isRestrictedMode
            ? () async {
                final newList = List<String>.from(settings.restrictedFolders)
                  ..remove(path);
                await settings.setRestrictedFolders(newList);
                music.scanLocalSongs();
              }
            : null,
      ),
    );
  }
}
