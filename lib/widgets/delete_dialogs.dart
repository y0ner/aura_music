import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../services/player_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

/// Diálogos de confirmación para eliminar álbumes (carpetas) y canciones.
///
/// Después de borrar del disco: quita la canción de la cola del reproductor
/// (o limpia todo si sonaba la que se eliminó) y re-escanea la biblioteca.
class DeleteDialogs {
  DeleteDialogs._();

  /// Pregunta y elimina un álbum/playlist (carpeta física + todas sus
  /// canciones). Devuelve true si se eliminó.
  static Future<bool> confirmDeletePlaylist(
    BuildContext context,
    Playlist playlist,
  ) async {
    final storage = Provider.of<MusicStorageService>(context, listen: false);
    final player = PlayerServiceMaybe.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          '¿Eliminar álbum?',
          style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '«${playlist.name}» y sus ${playlist.trackCount} pista(s) se eliminarán del disco. Esta acción no se puede deshacer.',
          style: AppTheme.itemSubtitle.copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: AppTheme.label.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(
              'Eliminar',
              style: AppTheme.label.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    // Si sonaba una canción del álbum eliminado, se detiene y limpia la cola.
    if (player != null && player.currentSong != null) {
      final belongedToDeletedFolder = playlist.songs
          .any((s) => s.id == player.currentSong!.id);
      // Compara por carpeta también: al re-escanear los ids pueden cambiar.
      final currentFolder = _folderOf(player.currentSong!.filePath);
      final folderMatches = currentFolder == _folderOf(playlist.folderPath);
      if (belongedToDeletedFolder || (folderMatches && playlist.folderPath.isNotEmpty)) {
        await player.stopAndClear();
      }
    }

    final ok = await storage.deletePlaylistFolder(playlist);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Álbum «${playlist.name}» eliminado'
                : 'No se pudo eliminar el álbum',
            style: AppTheme.itemSubtitle.copyWith(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.surfaceHigh,
        ),
      );
    }
    return ok;
  }

  /// Pregunta y elimina una canción del disco. Quita también las canciones
  /// del mismo archivo de la cola del reproductor.
  static Future<bool> confirmDeleteSong(
    BuildContext context,
    Song song,
    {List<Song>? queueContext}
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        ),
        title: Text(
          '¿Eliminar canción?',
          style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '«${song.title}» se eliminará del disco. Esta acción no se puede deshacer.',
          style: AppTheme.itemSubtitle.copyWith(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: AppTheme.label.copyWith(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: Text(
              'Eliminar',
              style: AppTheme.label.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return false;

    final player = PlayerServiceMaybe.of(context);
    final storage = Provider.of<MusicStorageService>(context, listen: false);

    final ok = await storage.deleteSongFile(song);
    if (ok && player != null) {
      // La canción sonando se eliminó: parar y limpiar para no apuntar a un
      // archivo que ya no existe.
      if (player.currentSong?.id == song.id) {
        await player.stopAndClear();
      } else {
        player.removeSongFromQueue(song.id);
      }
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Canción «${song.title}» eliminada' : 'No se pudo eliminar la canción',
            style: AppTheme.itemSubtitle.copyWith(color: AppTheme.textPrimary),
          ),
          backgroundColor: AppTheme.surfaceHigh,
        ),
      );
    }
    return ok;
  }

  static String? _folderOf(String filePath) {
    final idx = filePath.lastIndexOf('/');
    return idx > 0 ? filePath.substring(0, idx) : null;
  }
}

/// Acceso tolerante al PlayerService (por si algún día una pantalla no lo
/// tiene en el árbol de providers).
class PlayerServiceMaybe {
  PlayerServiceMaybe._();

  static PlayerService? of(BuildContext context) {
    try {
      return Provider.of<PlayerService>(context, listen: false);
    } catch (_) {
      return null;
    }
  }
}
