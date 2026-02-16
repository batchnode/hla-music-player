import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'providers/settings_provider.dart';
import 'providers/music_provider.dart';

class ExcludedFoldersPage extends StatelessWidget {
  const ExcludedFoldersPage({super.key});

  Future<void> _pickFolder(BuildContext context, SettingsProvider settings, MusicProvider music) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      if (!settings.excludedFolders.contains(selectedDirectory)) {
        final newList = List<String>.from(settings.excludedFolders)..add(selectedDirectory);
        await settings.setExcludedFolders(newList);
        music.scanLocalSongs();
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
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Excluded Folders',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Music from these folders will be hidden from your library.',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Consumer<SettingsProvider>(
                  builder: (context, settings, child) {
                    if (settings.excludedFolders.isEmpty) {
                      return const Center(
                        child: Text(
                          'No excluded folders',
                          style: TextStyle(color: Colors.white24),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: settings.excludedFolders.length,
                      itemBuilder: (context, index) {
                        return _buildFolderTile(context, settings.excludedFolders[index], settings, music);
                      },
                    );
                  },
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickFolder(context, settings, music),
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildFolderTile(BuildContext context, String path, SettingsProvider settings, MusicProvider music) {
    return ListTile(
      leading: const Icon(Icons.folder_off_outlined, color: Colors.redAccent),
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
        onPressed: () async {
          final newList = List<String>.from(settings.excludedFolders)..remove(path);
          await settings.setExcludedFolders(newList);
          music.scanLocalSongs();
        },
      ),
    );
  }
}
