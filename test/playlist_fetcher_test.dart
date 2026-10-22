import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura_music/services/playlist_fetcher.dart';

void main() {
  test(
    'extrae pistas del renderer nuevo y del renderer legado sin duplicar',
    () {
      final initialData = {
        'contents': [
          {
            'lockupViewModel': {
              'contentId': 'AAAAAAAAAAA',
              'contentType': 'VIDEO',
              'metadata': {
                'lockupMetadataViewModel': {
                  'title': {'content': 'Canción nueva'},
                },
              },
            },
          },
          {
            'playlistVideoRenderer': {
              'videoId': 'BBBBBBBBBBB',
              'title': {
                'runs': [
                  {'text': 'Canción legacy'},
                ],
              },
              'lengthText': {'simpleText': '3:21'},
            },
          },
          {
            // El mismo ID en otro renderer no debe crear una tercera pista.
            'playlistVideoRenderer': {
              'videoId': 'AAAAAAAAAAA',
              'title': {
                'runs': [
                  {'text': 'Duplicada'},
                ],
              },
            },
          },
        ],
      };

      final html = 'var ytInitialData = ${jsonEncode(initialData)};';
      final parsed = PlaylistFetcher.extractYtInitialData(html);
      expect(parsed, isNotNull);

      final tracks = PlaylistFetcher.parseTracks(parsed);
      expect(tracks, hasLength(2));
      expect(tracks[0].videoId, 'AAAAAAAAAAA');
      expect(tracks[0].title, 'Canción nueva');
      expect(tracks[1].videoId, 'BBBBBBBBBBB');
      expect(tracks[1].title, 'Canción legacy');
      expect(tracks[1].durationText, '3:21');
    },
  );

  test('pagina el nuevo formato real sin contenedor legado y usa el contexto de la página', () async {
    final requests = <http.Request>[];
    Map<String, dynamic> track(String id) => {
      'lockupViewModel': {
        'contentId': id,
        'contentType': 'VIDEO',
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': id},
          },
        },
      },
    };
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') {
        final initial = {
          'contents': {
            'twoColumnBrowseResultsRenderer': {
              'tabs': [
                {
                  'tabRenderer': {
                    'selected': true,
                    'content': {
                      'sectionListRenderer': {
                        'contents': [
                          {
                            'itemSectionRenderer': {
                              'contents': [track('AAAAAAAAAAA')],
                            },
                          },
                          {
                            'continuationItemViewModel': {
                              'continuationCommand': {'token': 'page2'},
                            },
                          },
                        ],
                      },
                    },
                  },
                },
              ],
            },
          },
          'recommendations': [track('XXXXXXXXXXX')],
          'header': {
            'pageHeaderRenderer': {'pageTitle': 'Mi playlist'},
          },
        };
        return http.Response(
          'var ytInitialData = ${jsonEncode(initial)}; var ytcfg = {"INNERTUBE_CLIENT_VERSION":"test-version"};',
          200,
        );
      }
      final body = jsonDecode(request.body);
      expect(body['context']['client']['clientVersion'], 'test-version');
      expect(body['continuation'], 'page2');
      return http.Response(
        jsonEncode({
          'onResponseReceivedActions': [
            {
              'appendContinuationItemsAction': {
                'continuationItems': [track('BBBBBBBBBBB')],
              },
            },
          ],
        }),
        200,
      );
    });
    try {
      final playlist = await PlaylistFetcher.fetchOverview(
        'PLtest',
        client: client,
      );
      expect(playlist.title, 'Mi playlist');
      expect(playlist.tracks.map((t) => t.videoId), [
        'AAAAAAAAAAA',
        'BBBBBBBBBBB',
      ]);
      expect(requests, hasLength(2));
    } finally {
      client.close();
    }
  });

  test('ignora pistas privadas y elementos que no son vídeos', () {
    expect(
      PlaylistFetcher.parseTracks({
        'contents': [
          {
            'playlistVideoRenderer': {
              'videoId': 'AAAAAAAAAAA',
              'isPlayable': false,
            },
          },
          {
            'lockupViewModel': {
              'contentId': 'PLtest',
              'metadata': {
                'lockupMetadataViewModel': {
                  'title': {'content': 'Playlist'},
                },
              },
            },
          },
        ],
      }),
      isEmpty,
    );
  });

  test('devuelve null si la página no contiene ytInitialData válido', () {
    expect(
      PlaylistFetcher.extractYtInitialData('<html>sin datos</html>'),
      isNull,
    );
    expect(
      PlaylistFetcher.extractYtInitialData('ytInitialData = {"incompleto": '),
      isNull,
    );
  });
}
