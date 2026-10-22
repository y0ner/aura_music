import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../services/storage_service.dart';
import '../services/player_service.dart';
import '../widgets/header_bar.dart';
import '../widgets/mini_player.dart';
import '../widgets/fullscreen_player.dart';
import 'library_screen.dart';
import 'downloads_screen.dart';
import 'youtube_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openFullscreenPlayer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullscreenPlayer(onCollapse: () => Navigator.pop(context)),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _showCreateFolderDialog(BuildContext context) {
    final controller = TextEditingController(text: '🔥 ');
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF212121),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text(
            'Crear Playlist (Subcarpeta)',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Escribe el nombre con tus emojis favoritos. Se creará una carpeta dentro de la app y actuará al instante como tu playlist:',
                style: TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej: 🏋️ Gym Motivación',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF141414),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(ctx);
                  final storage = Provider.of<MusicStorageService>(
                    context,
                    listen: false,
                  );
                  await storage.createPlaylistFolder(text);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Carpeta y Playlist "$text" creada!'),
                        backgroundColor: const Color(0xFF333333),
                      ),
                    );
                  }
                }
              },
              child: const Text('Crear'),
            ),
          ],
        );
      },
    );
  }

  void _showFolderOptions(BuildContext context) {
    final storage = Provider.of<MusicStorageService>(context, listen: false);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        Widget quick(IconData icon, String label, VoidCallback action) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 80,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF343434),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: action,
                        child: Icon(icon, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            );
        Future<void> selectFolder() async {
          Navigator.pop(ctx);
          final selected = await FilePicker.getDirectoryPath();
          if (selected != null) await storage.setCustomRootDirectory(selected);
        }

        void createPlaylist() {
          Navigator.pop(ctx);
          _showCreateFolderDialog(context);
        }

        void scan() {
          Navigator.pop(ctx);
          storage.scanLibrary();
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Configuración',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storage.rootMusicDirectory?.path ??
                                    'No configurada',
                                style: const TextStyle(
                                  color: Color(0xFFAAAAAA),
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar configuración',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF444444), height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 24,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        quick(
                          Icons.playlist_add,
                          'Crear una\nplaylist',
                          createPlaylist,
                        ),
                        quick(
                          Icons.folder_open_outlined,
                          'Elegir\ncarpeta',
                          selectFolder,
                        ),
                        quick(Icons.sync, 'Actualizar\nbiblioteca', scan),
                      ],
                    ),
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: const Icon(
                      Icons.playlist_add,
                      color: Colors.white,
                      size: 28,
                    ),
                    title: const Text(
                      'Crear nueva playlist',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    subtitle: const Text(
                      'Crea una carpeta con emojis que aparecerá en Biblioteca',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                    ),
                    onTap: createPlaylist,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: const Icon(
                      Icons.folder_open_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    title: const Text(
                      'Seleccionar carpeta de música',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    subtitle: const Text(
                      'Elige otra carpeta de tu celular o PC',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                    ),
                    onTap: selectFolder,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: const Icon(
                      Icons.sync,
                      color: Colors.white,
                      size: 28,
                    ),
                    title: const Text(
                      'Escanear biblioteca ahora',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    onTap: scan,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSearchModal(BuildContext context) {
    showSearch(
      context: context,
      delegate: MusicSearchDelegate(
        storage: Provider.of<MusicStorageService>(context, listen: false),
        player: Provider.of<PlayerService>(context, listen: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Bar
                HeaderBar(
                  onMenuPressed: () => _showFolderOptions(context),
                  onOpenFolderPressed: () => _showFolderOptions(context),
                  onSearchPressed: () => _showSearchModal(context),
                  onProfilePressed: () => _showFolderOptions(context),
                ),

                // Navigation Tabs ("BIBLIOTECA" & "DESCARGAS")
                Container(
                  color: const Color(0xFF030303),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFF888888),
                    labelStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    indicatorPadding: const EdgeInsets.only(bottom: 2),
                    tabs: const [
                      Tab(text: 'BIBLIOTECA'),
                      Tab(text: 'DESCARGAS'),
                      Tab(text: 'YOUTUBE'),
                    ],
                  ),
                ),

                const Divider(color: Color(0xFF1C1C1C), height: 1),

                // Tab Views
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      LibraryScreen(),
                      DownloadsScreen(),
                      YoutubeScreen(),
                    ],
                  ),
                ),
              ],
            ),

            // Floating Bottom Mini Player
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: MiniPlayer(onExpand: _openFullscreenPlayer),
            ),
          ],
        ),
      ),
    );
  }
}

class MusicSearchDelegate extends SearchDelegate {
  final MusicStorageService storage;
  final PlayerService player;

  MusicSearchDelegate({required this.storage, required this.player});

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF030303),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF181818),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear, color: Colors.white),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildResultsList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildResultsList(context);
  }

  Widget _buildResultsList(BuildContext context) {
    final filteredSongs = storage.allSongs.where((s) {
      final q = query.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    if (filteredSongs.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron canciones.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredSongs.length,
      itemBuilder: (context, i) {
        final song = filteredSongs[i];
        return ListTile(
          leading: const Icon(Icons.music_note, color: Colors.white),
          title: Text(song.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(
            song.artist,
            style: const TextStyle(color: Colors.white54),
          ),
          onTap: () {
            player.playSong(song, playlist: filteredSongs);
            close(context, null);
          },
        );
      },
    );
  }
}
