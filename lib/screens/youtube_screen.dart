import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/song_model.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

/// Pantalla «Añadir» para analizar y descargar canciones o playlists de YouTube.
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

  void _clearInput(YoutubeDownloadService service) {
    _urlController.clear();
    service.clearPreview();
    setState(() {});
  }

  ButtonStyle get _primaryStyle => FilledButton.styleFrom(
    backgroundColor: AppTheme.textPrimary,
    foregroundColor: AppTheme.bg,
    disabledBackgroundColor: AppTheme.surfaceHigh,
    disabledForegroundColor: AppTheme.textMuted,
    minimumSize: const Size(0, AppTheme.minTouch),
    padding: const EdgeInsets.symmetric(
      horizontal: AppTheme.space24,
      vertical: AppTheme.space12,
    ),
    shape: const StadiumBorder(),
    textStyle: AppTheme.itemTitle,
  );

  String _selectedSubfolder(MusicStorageService storage) {
    return storage.playlists.any((p) => p.name == _targetSubfolder)
        ? _targetSubfolder
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<YoutubeDownloadService, MusicStorageService>(
      builder: (context, service, storage, _) {
        final busy = service.isAnalyzing;
        final preview = service.preview;
        final job = preview != null ? service.jobFor(preview.id) : null;
        final hasContent = preview != null || service.jobs.isNotEmpty;

        return ColoredBox(
          color: AppTheme.bg,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pagePadding,
              20,
              AppTheme.pagePadding,
              120,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Añadir música', style: AppTheme.titleLarge),
                const SizedBox(height: AppTheme.space4),
                Text(
                  'Pega un enlace de YouTube. La canción o la playlist queda en tu biblioteca, sin conexión.',
                  style: AppTheme.itemSubtitle.copyWith(height: 1.45),
                ),
                const SizedBox(height: 20),
                const Text('Enlace de YouTube', style: AppTheme.label),
                const SizedBox(height: AppTheme.space8),
                _urlField(service, busy),
                const SizedBox(height: AppTheme.space12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: _primaryStyle,
                    onPressed: busy || _urlController.text.trim().isEmpty
                        ? null
                        : _analyze,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.textSecondary,
                            ),
                          )
                        : const Icon(Icons.search, size: 20),
                    label: Text(busy ? 'Analizando…' : 'Analizar enlace'),
                  ),
                ),
                if (service.statusMessage.isNotEmpty &&
                    (!service.isDownloading || preview == null)) ...[
                  const SizedBox(height: AppTheme.space16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      service.statusMessage,
                      style: AppTheme.itemSubtitle.copyWith(height: 1.45),
                    ),
                  ),
                ],
                if (preview != null) ...[
                  const SizedBox(height: AppTheme.space16),
                  _previewCard(context, service, storage, preview, job),
                ],
                if (service.jobs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _queueSection(service),
                ],
                if (!hasContent) ...[
                  const SizedBox(height: AppTheme.space24),
                  _emptyStateCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _urlField(YoutubeDownloadService service, bool busy) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: const ShapeDecoration(
        color: AppTheme.surfaceHigh,
        shape: StadiumBorder(),
      ),
      padding: const EdgeInsets.only(left: AppTheme.space16, right: 6),
      child: Row(
        children: [
          const Icon(Icons.link, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: TextField(
              controller: _urlController,
              enabled: !busy,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _analyze(),
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: AppTheme.itemTitle.copyWith(fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                hintText: 'youtube.com/watch?v=…',
                hintStyle: AppTheme.itemTitle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppTheme.textMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: AppTheme.space12,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.space4),
          if (_urlController.text.isEmpty)
            // TextButton para que «Analizar enlace» siga siendo el primer FilledButton.
            TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.textPrimary,
                foregroundColor: AppTheme.bg,
                disabledBackgroundColor: AppTheme.chip,
                disabledForegroundColor: AppTheme.textMuted,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, AppTheme.chipHeight),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: AppTheme.label,
              ),
              onPressed: busy ? null : _pasteFromClipboard,
              icon: const Icon(Icons.content_paste, size: 16),
              label: const Text('Pegar'),
            )
          else
            IconButton(
              tooltip: 'Borrar enlace',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              padding: EdgeInsets.zero,
              onPressed: busy ? null : () => _clearInput(service),
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewCard(
    BuildContext context,
    YoutubeDownloadService service,
    MusicStorageService storage,
    YoutubePreview preview,
    DownloadJob? job,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mediaRow(preview),
          const SizedBox(height: AppTheme.space12),
          _previewActions(context, service, storage, preview, job),
        ],
      ),
    );
  }

  Widget _mediaRow(YoutubePreview preview) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: SizedBox(
            width: AppTheme.playlistThumb,
            height: AppTheme.playlistThumb,
            child: ColoredBox(
              color: AppTheme.surfaceHigh,
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
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.itemTitle,
              ),
              const SizedBox(height: AppTheme.space4),
              Text(
                _previewSubtitle(preview),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.itemSubtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _previewSubtitle(YoutubePreview preview) {
    if (preview.isPlaylist) {
      final unit = preview.trackCount == 1 ? 'canción' : 'canciones';
      return 'Playlist • ${preview.trackCount} $unit';
    }
    final author = preview.author.trim();
    final hasAuthor = author.isNotEmpty && author != Song.unknownArtist;
    final duration = preview.formattedDuration;
    if (hasAuthor && duration.isNotEmpty) {
      return '$author • $duration';
    }
    if (hasAuthor) return author;
    if (duration.isNotEmpty) return 'Canción • $duration';
    return 'Canción';
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
                style: AppTheme.label,
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Text(
              '${(service.currentProgress * 100).toInt()}%',
              style: AppTheme.itemSubtitle,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space12),
        LinearProgressIndicator(
          value: service.currentProgress,
          color: AppTheme.accent,
          backgroundColor: AppTheme.outline,
          minHeight: AppTheme.space4,
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        const SizedBox(height: AppTheme.space16),
        Row(
          children: [
            const Icon(Icons.graphic_eq, color: AppTheme.textPrimary, size: 22),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Text(
                service.currentTrackTitle ?? 'Preparando descarga…',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        Text(
          service.statusMessage,
          style: AppTheme.caption.copyWith(height: 1.45),
        ),
        if (service.failedTracks > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.space8),
            child: Text(
              '${service.failedTracks} pistas no se pudieron descargar',
              style: AppTheme.caption.copyWith(color: AppTheme.danger),
            ),
          ),
        const SizedBox(height: AppTheme.space8),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            minimumSize: const Size(0, AppTheme.minTouch),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space8),
            textStyle: AppTheme.label,
          ),
          onPressed: service.cancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Cancelar esta descarga'),
        ),
      ],
    );
  }

  Widget _subfolderDropdown(MusicStorageService storage) {
    return Container(
      constraints: const BoxConstraints(minHeight: AppTheme.minTouch),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusArtwork),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.folder_outlined,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppTheme.space8),
          Text(
            'Guardar en',
            style: AppTheme.label.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedSubfolder(storage),
              isExpanded: true,
              dropdownColor: AppTheme.surfaceHigh,
              icon: const Icon(
                Icons.expand_more,
                color: AppTheme.textPrimary,
                size: 20,
              ),
              style: AppTheme.label,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text(
                    'Descargas generales',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          ),
        ],
      ),
    );
  }

  Widget _previewActions(
    BuildContext context,
    YoutubeDownloadService service,
    MusicStorageService storage,
    YoutubePreview preview,
    DownloadJob? job,
  ) {
    if (job?.status == DownloadJobStatus.downloading) {
      return _downloadProgress(service);
    }

    if (job?.status == DownloadJobStatus.waiting) {
      final waitingList = service.jobs
          .where((j) => j.status == DownloadJobStatus.waiting)
          .toList();
      final pos = waitingList.indexOf(job!) + 1;
      final position = pos > 0 ? pos : 1;
      return Row(
        children: [
          const Icon(
            Icons.hourglass_empty,
            color: AppTheme.textSecondary,
            size: 20,
          ),
          const SizedBox(width: AppTheme.space8),
          Expanded(
            child: Text(
              'En cola · posición $position',
              style: AppTheme.itemSubtitle,
            ),
          ),
        ],
      );
    }

    if (job?.status == DownloadJobStatus.done || service.isPreviewDownloaded) {
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, color: AppTheme.textPrimary, size: 22),
          SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Descargada en tu biblioteca', style: AppTheme.label),
                SizedBox(height: AppTheme.space4),
                Text(
                  'Pega otro enlace para descargar más.',
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
        ],
      );
    }

    final isRetry = job?.status == DownloadJobStatus.failed;
    final buttonIcon = isRetry
        ? Icons.refresh
        : (service.isDownloading
              ? Icons.queue_music
              : Icons.download_outlined);
    final buttonLabel = isRetry
        ? 'Reintentar ${job!.failed > 0 ? job.failed : preview.trackCount} fallidas'
        : (service.isDownloading
              ? 'Añadir a la cola'
              : (preview.isPlaylist
                    ? 'Descargar playlist'
                    : 'Descargar canción'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!preview.isPlaylist) ...[
          _subfolderDropdown(storage),
          const SizedBox(height: AppTheme.space12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: _primaryStyle,
            onPressed: () => service.enqueue(
              storage,
              targetSubfolder: _selectedSubfolder(storage),
            ),
            icon: Icon(buttonIcon, size: 20),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }

  Widget _queueSection(YoutubeDownloadService service) {
    final hasFinished = service.jobs.any(
      (j) =>
          j.status == DownloadJobStatus.done ||
          j.status == DownloadJobStatus.failed ||
          j.status == DownloadJobStatus.cancelled,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Cola de descargas', style: AppTheme.itemTitle),
            ),
            if (hasFinished)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  minimumSize: const Size(0, AppTheme.minTouch),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.space8,
                  ),
                  textStyle: AppTheme.label,
                ),
                onPressed: service.clearFinished,
                child: const Text('Limpiar terminadas'),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.space8),
        ...service.jobs.map((job) => _queueRow(service, job)),
      ],
    );
  }

  Widget _queueRow(YoutubeDownloadService service, DownloadJob job) {
    final String statusText;
    switch (job.status) {
      case DownloadJobStatus.downloading:
        statusText = job.tracks.isEmpty
            ? 'Descargando'
            : 'Descargando ${job.completed}/${job.tracks.length}';
        break;
      case DownloadJobStatus.waiting:
        statusText = 'En espera';
        break;
      case DownloadJobStatus.done:
        statusText = 'Descargada';
        break;
      case DownloadJobStatus.failed:
        statusText = '${job.failed} fallidas';
        break;
      case DownloadJobStatus.cancelled:
        statusText = 'Cancelada';
        break;
    }

    final double progress;
    if (service.currentJob?.id == job.id) {
      progress = service.currentProgress.clamp(0.0, 1.0);
    } else if (job.tracks.isNotEmpty) {
      progress = (job.completed / job.tracks.length).clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppTheme.playlistThumb),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: SizedBox(
                width: AppTheme.songThumb,
                height: AppTheme.songThumb,
                child: ColoredBox(
                  color: AppTheme.surfaceHigh,
                  child: job.preview.thumbnailUrl.isEmpty
                      ? Icon(
                          job.preview.isPlaylist
                              ? Icons.queue_music
                              : Icons.music_note,
                          color: AppTheme.textSecondary,
                          size: 20,
                        )
                      : Image.network(
                          job.preview.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Icon(
                            job.preview.isPlaylist
                                ? Icons.queue_music
                                : Icons.music_note,
                            color: AppTheme.textSecondary,
                            size: 20,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    job.preview.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.itemTitle,
                  ),
                  const SizedBox(height: AppTheme.space4),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: job.status == DownloadJobStatus.failed
                        ? AppTheme.itemSubtitle.copyWith(color: AppTheme.danger)
                        : AppTheme.itemSubtitle,
                  ),
                  if (job.status == DownloadJobStatus.downloading) ...[
                    const SizedBox(height: AppTheme.space4),
                    LinearProgressIndicator(
                      value: progress,
                      color: AppTheme.accent,
                      backgroundColor: AppTheme.outline,
                      minHeight: AppTheme.space4,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                  ],
                ],
              ),
            ),
            _queueTrailing(service, job),
          ],
        ),
      ),
    );
  }

  Widget _queueTrailing(YoutubeDownloadService service, DownloadJob job) {
    switch (job.status) {
      case DownloadJobStatus.downloading:
        return IconButton(
          tooltip: 'Cancelar descarga',
          constraints: const BoxConstraints(
            minWidth: AppTheme.minTouch,
            minHeight: AppTheme.minTouch,
          ),
          icon: const Icon(
            Icons.close,
            size: 20,
            color: AppTheme.textPrimary,
          ),
          onPressed: service.cancel,
        );
      case DownloadJobStatus.waiting:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_empty,
              size: 18,
              color: AppTheme.textSecondary,
              semanticLabel: 'En espera',
            ),
            IconButton(
              tooltip: 'Quitar de la cola',
              constraints: const BoxConstraints(
                minWidth: AppTheme.minTouch,
                minHeight: AppTheme.minTouch,
              ),
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              onPressed: () => service.removeJob(job.id),
            ),
          ],
        );
      case DownloadJobStatus.done:
        return const SizedBox(
          width: AppTheme.minTouch,
          height: AppTheme.minTouch,
          child: Center(
            child: Icon(
              Icons.check_circle,
              size: 22,
              color: AppTheme.textPrimary,
              semanticLabel: 'Completada',
            ),
          ),
        );
      case DownloadJobStatus.failed:
        return const SizedBox(
          width: AppTheme.minTouch,
          height: AppTheme.minTouch,
          child: Center(
            child: Icon(
              Icons.error_outline,
              size: 22,
              color: AppTheme.danger,
              semanticLabel: 'Fallida',
            ),
          ),
        );
      case DownloadJobStatus.cancelled:
        return const SizedBox(
          width: AppTheme.minTouch,
          height: AppTheme.minTouch,
          child: Center(
            child: Icon(
              Icons.cancel_outlined,
              size: 22,
              color: AppTheme.textMuted,
              semanticLabel: 'Cancelada',
            ),
          ),
        );
    }
  }

  Widget _emptyStateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.space16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.library_music_outlined,
            color: AppTheme.textSecondary,
            size: 22,
          ),
          SizedBox(width: AppTheme.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tu música, sin conexión', style: AppTheme.itemTitle),
                SizedBox(height: AppTheme.space4),
                Text(
                  'Las playlists públicas o no listadas se guardan en su propia carpeta y aparecen en Biblioteca.',
                  style: AppTheme.itemSubtitle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
