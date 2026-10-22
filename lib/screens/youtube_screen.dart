import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

class YoutubeScreen extends StatefulWidget {
  const YoutubeScreen({super.key});

  @override
  State<YoutubeScreen> createState() => _YoutubeScreenState();
}

class _YoutubeScreenState extends State<YoutubeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String _targetSubfolder = '';

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null || data!.text!.trim().isEmpty) return;
    setState(() => _urlController.text = data.text!.trim());
    _analyze();
  }

  void _analyze() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      context.read<YoutubeDownloadService>().analyzeUrl(text);
    }
  }

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: AppTheme.textPrimary,
    foregroundColor: AppTheme.bgDark,
    disabledBackgroundColor: AppTheme.cardDark,
    disabledForegroundColor: AppTheme.textMuted,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: const StadiumBorder(),
  );

  @override
  Widget build(BuildContext context) {
    return Consumer2<YoutubeDownloadService, MusicStorageService>(
      builder: (context, service, storage, _) {
        final busy = service.isAnalyzing || service.isDownloading;
        final preview = service.preview;
        return ColoredBox(
          color: AppTheme.bgDark,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Añadir música',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Una canción o una playlist, directamente a tu biblioteca.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _urlController,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _analyze(),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enlace de YouTube',
                    hintStyle: const TextStyle(color: AppTheme.textMuted),
                    filled: true,
                    fillColor: AppTheme.cardDark,
                    prefixIcon: const Icon(
                      Icons.link,
                      color: AppTheme.textSecondary,
                    ),
                    suffixIcon: _urlController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Borrar enlace',
                            onPressed: busy
                                ? null
                                : () {
                                    _urlController.clear();
                                    service.clearPreview();
                                    setState(() {});
                                  },
                            icon: const Icon(Icons.close, size: 20),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: _primaryStyle,
                      onPressed: busy || _urlController.text.trim().isEmpty
                          ? null
                          : _analyze,
                      icon: service.isAnalyzing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.textSecondary,
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: Text(
                        service.isAnalyzing ? 'Analizando…' : 'Analizar enlace',
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: AppTheme.dividerColor),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      onPressed: busy ? null : _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('Pegar'),
                    ),
                  ],
                ),
                if (service.statusMessage.isNotEmpty &&
                    !service.isDownloading) ...[
                  const SizedBox(height: 18),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      service.statusMessage,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                if (preview != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(height: 1),
                  ),
                  _mediaRow(preview),
                  const SizedBox(height: 20),
                  if (service.isDownloading)
                    _downloadProgress(service)
                  else ...[
                    if (!preview.isPlaylist) ...[
                      const Text(
                        'Guardar en',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      DropdownButton<String>(
                        value:
                            storage.playlists.any(
                              (p) => p.name == _targetSubfolder,
                            )
                            ? _targetSubfolder
                            : '',
                        isExpanded: true,
                        dropdownColor: AppTheme.cardDark,
                        icon: const Icon(
                          Icons.expand_more,
                          color: AppTheme.textSecondary,
                        ),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                        ),
                        underline: const SizedBox.shrink(),
                        items: [
                          const DropdownMenuItem(
                            value: '',
                            child: Text('Descargas generales'),
                          ),
                          ...storage.playlists.map(
                            (p) => DropdownMenuItem(
                              value: p.name,
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _targetSubfolder = value ?? ''),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton.icon(
                      style: _primaryStyle,
                      onPressed: () => service.startDownload(
                        storage,
                        targetSubfolder:
                            storage.playlists.any(
                              (p) => p.name == _targetSubfolder,
                            )
                            ? _targetSubfolder
                            : '',
                      ),
                      icon: const Icon(Icons.download_outlined, size: 20),
                      label: Text(
                        preview.isPlaylist
                            ? 'Descargar playlist'
                            : 'Descargar canción',
                      ),
                    ),
                  ],
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(height: 1),
                ),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.library_music_outlined,
                      color: AppTheme.textSecondary,
                      size: 22,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tu música, sin conexión',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Las playlists públicas o no listadas se guardan en su propia carpeta y aparecen en Biblioteca.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mediaRow(YoutubePreview preview) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 64,
            height: 64,
            child: ColoredBox(
              color: AppTheme.cardDark,
              child: preview.thumbnailUrl.isEmpty
                  ? const Icon(Icons.music_note, color: AppTheme.textSecondary)
                  : Image.network(
                      preview.thumbnailUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.music_note,
                        color: AppTheme.textSecondary,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                preview.isPlaylist
                    ? 'Playlist • ${preview.trackCount} canciones'
                    : '${preview.author} • ${preview.formattedDuration}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _downloadProgress(YoutubeDownloadService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Descargando • ${service.completedTracks}/${service.totalTracks}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(service.currentProgress * 100).toInt()}%',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: service.currentProgress,
          color: AppTheme.textPrimary,
          backgroundColor: AppTheme.dividerColor,
          minHeight: 3,
          borderRadius: BorderRadius.circular(2),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppTheme.textPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                service.currentTrackTitle ?? 'Preparando descarga…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          service.statusMessage,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        if (service.failedTracks > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${service.failedTracks} pistas no se pudieron descargar',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 12),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppTheme.textPrimary),
          onPressed: service.cancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar descarga'),
        ),
      ],
    );
  }
}
