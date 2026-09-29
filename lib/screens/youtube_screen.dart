import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../services/youtube_service.dart';

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
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _urlController.text = data.text!.trim();
      _analyze();
    }
  }

  void _analyze() {
    final text = _urlController.text.trim();
    if (text.isNotEmpty) {
      final ytService = Provider.of<YoutubeDownloadService>(context, listen: false);
      ytService.analyzeUrl(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<YoutubeDownloadService, MusicStorageService>(
      builder: (context, ytService, storage, child) {
        final preview = ytService.preview;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // URL Input Container
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: Color(0xFFFF0000), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Pega enlace de YouTube o Playlist...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13.5),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _analyze(),
                      ),
                    ),
                    if (_urlController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                        onPressed: () {
                          _urlController.clear();
                          ytService.clearPreview();
                          setState(() {});
                        },
                      ),
                    // Paste Button
                    GestureDetector(
                      onTap: _pasteFromClipboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C2C2C),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.content_paste_rounded, color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Pegar',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Analyze Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: ytService.isAnalyzing ? null : _analyze,
                  icon: ytService.isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.manage_search_rounded, size: 20),
                  label: Text(
                    ytService.isAnalyzing ? 'Analizando...' : 'Analizar Enlace',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Status / Notification Message
              if (ytService.statusMessage.isNotEmpty && !ytService.isDownloading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        ytService.statusMessage.contains('Error')
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        color: ytService.statusMessage.contains('Error')
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ytService.statusMessage,
                          style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),

              // Active Download Progress Card
              if (ytService.isDownloading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E2E2E)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF0000),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Descarga en progreso...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(ytService.currentProgress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ytService.currentProgress > 0 ? ytService.currentProgress : null,
                          backgroundColor: Colors.white10,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF0000)),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ytService.statusMessage,
                        style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 16),
                          label: const Text('Cancelar', style: TextStyle(fontSize: 12.5)),
                          onPressed: () => ytService.cancel(),
                        ),
                      ),
                    ],
                  ),
                ),

              // Preview Card
              if (preview != null && !ytService.isDownloading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C2C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: preview.isPlaylist
                              ? const Color(0xFF7C4DFF)
                              : const Color(0xFFFF0000),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          preview.isPlaylist
                              ? 'PLAYLIST (${preview.trackCount} CANCIONES)'
                              : 'CANCIÓN (${preview.formattedDuration})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Thumbnail and Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 90,
                              height: 90,
                              color: const Color(0xFF242424),
                              child: Image.network(
                                preview.thumbnailUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.music_note,
                                  color: Colors.white54,
                                  size: 36,
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
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  preview.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFAAAAAA),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  preview.isPlaylist
                                      ? 'Se creará carpeta propia para la playlist'
                                      : 'Máxima calidad de audio (M4A/AAC)',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Destination Playlist selection (for single songs)
                      if (!preview.isPlaylist && storage.playlists.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Text(
                          'Guardar en Playlist / Subcarpeta:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101010),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: DropdownButton<String>(
                            value: _targetSubfolder.isEmpty ? '' : _targetSubfolder,
                            dropdownColor: const Color(0xFF212121),
                            isExpanded: true,
                            underline: const SizedBox(),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            items: [
                              const DropdownMenuItem(
                                value: '',
                                child: Text('Descargas Generales (Raíz)'),
                              ),
                              ...storage.playlists.map((p) => DropdownMenuItem(
                                    value: p.name,
                                    child: Text(p.name),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _targetSubfolder = val ?? '';
                              });
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Start Download Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF0000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () {
                            ytService.startDownload(
                              storage,
                              targetSubfolder: _targetSubfolder,
                            );
                          },
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: Text(
                            preview.isPlaylist
                                ? 'Descargar Playlist Completa'
                                : 'Descargar Canción',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Educational Tips Section
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFFD54F), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Mecánica Inteligente de Playlists',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Al descargar una playlist, se creará automáticamente una carpeta con el mismo nombre y sus canciones se agruparán ahí.\n• En la pestaña BIBLIOTECA aparecerá de inmediato con el mosaico 2x2.\n• Las playlists deben ser Públicas o No Listadas en YouTube.',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12, height: 1.45),
                    ),
                  ],
                ),
              ),

              // Bottom spacing for MiniPlayer
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}
