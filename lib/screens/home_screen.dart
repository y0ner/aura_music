import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fullscreen_player.dart';
import '../widgets/mini_player.dart';
import 'buscar_screen.dart';
import 'inicio_screen.dart';
import 'library_screen.dart';
import 'youtube_screen.dart';

/// Contenedor principal con barra inferior de 4 destinos y mini reproductor.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeTab { inicio, buscar, biblioteca, anadir }

class _HomeScreenState extends State<HomeScreen> {
  _HomeTab _currentTab = _HomeTab.inicio;

  void _selectTab(_HomeTab tab) {
    if (_currentTab == tab) return;
    if (_currentTab == _HomeTab.buscar) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    setState(() => _currentTab = tab);
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
          final tween = Tween(
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
    showDialog<void>(
      context: context,
      builder: (_) => const _CreatePlaylistDialog(),
    );
  }

  void _showFolderOptions(BuildContext context) {
    final storage = Provider.of<MusicStorageService>(context, listen: false);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (ctx) {
        Widget quick(IconData icon, String label, VoidCallback action) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.space8,
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: AppTheme.playerPlayButtonSize,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.chip,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusArtwork,
                            ),
                          ),
                        ),
                        onPressed: action,
                        child: Icon(
                          icon,
                          color: AppTheme.textPrimary,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.space12),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTheme.label,
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
                  const SizedBox(height: AppTheme.space8),
                  Container(
                    width: AppTheme.chipHeight,
                    height: AppTheme.space4,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppTheme.pagePadding),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Configuración',
                                style: AppTheme.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                storage.rootMusicDirectory?.path ??
                                    'No configurada',
                                style: AppTheme.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar configuración',
                          onPressed: () => Navigator.pop(ctx),
                          constraints: const BoxConstraints.tightFor(
                            width: AppTheme.minTouch,
                            height: AppTheme.minTouch,
                          ),
                          icon: const Icon(
                            Icons.close,
                            color: AppTheme.textPrimary,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppTheme.outline, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space12,
                      vertical: AppTheme.space24,
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
                      horizontal: AppTheme.space24,
                      vertical: AppTheme.space8,
                    ),
                    leading: const Icon(
                      Icons.playlist_add,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    title: const Text(
                      'Crear nueva playlist',
                      style: AppTheme.itemTitle,
                    ),
                    subtitle: const Text(
                      'Crea una carpeta con emojis que aparecerá en Biblioteca',
                      style: AppTheme.caption,
                    ),
                    onTap: createPlaylist,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space24,
                      vertical: AppTheme.space8,
                    ),
                    leading: const Icon(
                      Icons.folder_open_outlined,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    title: const Text(
                      'Seleccionar carpeta de música',
                      style: AppTheme.itemTitle,
                    ),
                    subtitle: const Text(
                      'Elige otra carpeta de tu celular o PC',
                      style: AppTheme.caption,
                    ),
                    onTap: selectFolder,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.space24,
                      vertical: AppTheme.space8,
                    ),
                    leading: const Icon(
                      Icons.sync,
                      color: AppTheme.textPrimary,
                      size: 24,
                    ),
                    title: const Text(
                      'Escanear biblioteca ahora',
                      style: AppTheme.itemTitle,
                    ),
                    onTap: scan,
                  ),
                  const SizedBox(height: AppTheme.space24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentTab == _HomeTab.inicio,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentTab != _HomeTab.inicio) {
          _selectTab(_HomeTab.inicio);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: IndexedStack(
          index: _currentTab.index,
          children: [
            InicioScreen(
              onOpenSearch: () => _selectTab(_HomeTab.buscar),
              onOpenSettings: () => _showFolderOptions(context),
              onAddMusic: () => _selectTab(_HomeTab.anadir),
            ),
            const BuscarScreen(),
            LibraryScreen(
              onSearch: () => _selectTab(_HomeTab.buscar),
              onCreatePlaylist: () => _showCreateFolderDialog(context),
              bottomInset: AppTheme.space16,
            ),
            const SafeArea(
              bottom: false,
              child: YoutubeScreen(),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MiniPlayer(onExpand: _openFullscreenPlayer),
            NavigationBar(
              selectedIndex: _currentTab.index,
              onDestinationSelected: (index) =>
                  _selectTab(_HomeTab.values[index]),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search),
                  label: 'Buscar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark_border),
                  selectedIcon: Icon(Icons.bookmark),
                  label: 'Biblioteca',
                ),
                NavigationDestination(
                  icon: Icon(Icons.download_outlined),
                  selectedIcon: Icon(Icons.download),
                  label: 'Añadir',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatePlaylistDialog extends StatefulWidget {
  const _CreatePlaylistDialog();

  @override
  State<_CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<_CreatePlaylistDialog> {
  final TextEditingController _controller = TextEditingController(text: '🔥 ');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final storage = Provider.of<MusicStorageService>(context, listen: false);
    Navigator.pop(context);
    await storage.createPlaylistFolder(text);
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Carpeta y Playlist "$text" creada!',
          style: AppTheme.itemSubtitle.copyWith(color: AppTheme.textPrimary),
        ),
        backgroundColor: AppTheme.surfaceHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
      ),
      title: Text(
        'Crear Playlist (Subcarpeta)',
        style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escribe el nombre con tus emojis favoritos. Se creará una carpeta dentro de la app y actuará al instante como tu playlist:',
            style: AppTheme.itemSubtitle.copyWith(height: 1.4),
          ),
          const SizedBox(height: AppTheme.space12),
          TextField(
            controller: _controller,
            autofocus: true,
            style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w400),
            decoration: InputDecoration(
              hintText: 'Ej: 🏋️ Gym Motivación',
              hintStyle: AppTheme.itemTitle.copyWith(
                fontWeight: FontWeight.w400,
                color: AppTheme.textMuted,
              ),
              filled: true,
              fillColor: AppTheme.surfaceDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: const BorderSide(color: AppTheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: const BorderSide(color: AppTheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                borderSide: const BorderSide(color: AppTheme.textPrimary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancelar',
            style: AppTheme.label.copyWith(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.textPrimary,
            foregroundColor: AppTheme.bg,
          ),
          onPressed: _submit,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}
