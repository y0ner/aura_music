import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:aura_music/services/lyrics_fetcher.dart';

void main() {
  group('LrclibFetcher', () {
    test(
      'construye la consulta q separando artista si es desconocido y limpiando palabras clave',
      () async {
        String? capturedQuery;
        String? capturedUserAgent;

        final client = MockClient((request) async {
          expect(request.url.path, '/api/search');
          capturedQuery = request.url.queryParameters['q'];
          capturedUserAgent = request.headers['User-Agent'];

          return http.Response(
            jsonEncode([
              {
                'trackName': 'BANSHEE',
                'artistName': 'FloyyMenor',
                'duration': 188.0,
                'syncedLyrics': '[00:01.00]Letra sincronizada',
              },
            ]),
            200,
          );
        });

        final fetcher = LrclibFetcher(client: client);
        final result = await fetcher.fetch(
          title: 'FloyyMenor - BANSHEE Ft J Balvin (Video Official)',
          artist: 'Artista desconocido',
        );

        expect(result, isNotNull);
        expect(capturedQuery, isNotNull);
        expect(capturedQuery, contains('FloyyMenor'));
        expect(capturedQuery, contains('BANSHEE'));
        expect(capturedQuery, isNot(contains('Video Official')));
        expect(capturedUserAgent, 'AuraMusic/1.0');
      },
    );

    test('conserva (Remix) y (feat. X) en la consulta', () {
      final q1 = LrclibFetcher.buildSearchQuery(
        title: 'Song (Remix) [Audio Oficial]',
        artist: 'Artista',
      );
      expect(q1, contains('Song (Remix)'));
      expect(q1, isNot(contains('Audio Oficial')));

      final q2 = LrclibFetcher.buildSearchQuery(
        title: 'Song (feat. Invitado) (Official Video)',
        artist: 'Artista',
      );
      expect(q2, contains('Song (feat. Invitado)'));
      expect(q2, isNot(contains('Official Video')));
    });

    test(
      'elige resultado sincronizado dentro de tolerancia de +-3s (188s vs 208s para 189s)',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'trackName': 'BANSHEE',
                'artistName': 'FloyyMenor',
                'duration': 208.0,
                'syncedLyrics': '[00:01.00]Versión larga',
              },
              {
                'trackName': 'BANSHEE',
                'artistName': 'FloyyMenor',
                'duration': 188.0,
                'syncedLyrics': '[00:01.00]Versión correcta',
              },
            ]),
            200,
          );
        });

        final fetcher = LrclibFetcher(client: client);
        final result = await fetcher.fetch(
          title: 'BANSHEE',
          artist: 'FloyyMenor',
          duration: const Duration(seconds: 189),
        );

        expect(result, '[00:01.00]Versión correcta');
      },
    );

    test('si ninguno está dentro de +-3s devuelve null', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'BANSHEE',
              'artistName': 'FloyyMenor',
              'duration': 180.0,
              'syncedLyrics': '[00:01.00]Versión desfasada',
            },
          ]),
          200,
        );
      });

      final fetcher = LrclibFetcher(client: client);
      final result = await fetcher.fetch(
        title: 'BANSHEE',
        artist: 'FloyyMenor',
        duration: const Duration(seconds: 189),
      );

      expect(result, isNull);
    });

    test(
      'con duración null toma primero sincronizado y si no el plano',
      () async {
        final clientSynced = MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'trackName': 'Tema',
                'plainLyrics': 'Letra plana previa',
              },
              {
                'trackName': 'Tema',
                'syncedLyrics': '[00:01.00]Letra con tiempo',
              },
            ]),
            200,
          );
        });

        final fetcherSynced = LrclibFetcher(client: clientSynced);
        final resSynced = await fetcherSynced.fetch(title: 'Tema');
        expect(resSynced, '[00:01.00]Letra con tiempo');

        final clientPlain = MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'trackName': 'Tema',
                'plainLyrics': 'Solo letra plana',
              },
            ]),
            200,
          );
        });

        final fetcherPlain = LrclibFetcher(client: clientPlain);
        final resPlain = await fetcherPlain.fetch(title: 'Tema');
        expect(resPlain, 'Solo letra plana');
      },
    );

    test('lanza LyricsFetchException si HTTP != 200', () async {
      final client = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final fetcher = LrclibFetcher(client: client);
      expect(
        () => fetcher.fetch(title: 'BANSHEE'),
        throwsA(isA<LyricsFetchException>()),
      );
    });

    test('lanza LyricsFetchException si el cliente lanza excepción', () async {
      final client = MockClient((request) async {
        throw http.ClientException('Fallo de conexión');
      });

      final fetcher = LrclibFetcher(client: client);
      expect(
        () => fetcher.fetch(title: 'BANSHEE'),
        throwsA(isA<LyricsFetchException>()),
      );
    });

    test(
      'una respuesta 200 que no es JSON (portal cautivo) es error de red',
      () async {
        final client = MockClient(
          (request) async =>
              http.Response('<html>Inicia sesión en el WiFi</html>', 200),
        );
        final fetcher = LrclibFetcher(client: client);
        expect(
          () => fetcher.fetch(title: 'BANSHEE'),
          throwsA(isA<LyricsFetchException>()),
        );
      },
    );

    test('descarta otra canción que solo coincide en duración', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'trackName': 'Mañana',
              'artistName': 'Otro',
              'duration': 161.0,
              'syncedLyrics': '[00:01.00]Letra de otra canción',
            },
          ]),
          200,
        );
      });
      final fetcher = LrclibFetcher(client: client);
      final result = await fetcher.fetch(
        title: 'Hoy',
        artist: 'Artista desconocido',
        duration: const Duration(seconds: 161),
      );
      expect(result, isNull);
    });

    test('titlesMatch tolera tildes, prefijo de artista y ft', () {
      expect(
        LrclibFetcher.titlesMatch(
          'BANSHEE',
          'FloyyMenor - BANSHEE ft J Balvin',
        ),
        isTrue,
      );
      expect(LrclibFetcher.titlesMatch('Soltandote', 'Soltándote'), isTrue);
      expect(
        LrclibFetcher.titlesMatch('Prendo (feat. Thommykill)', 'Prendo'),
        isTrue,
      );
      expect(LrclibFetcher.titlesMatch('Hoy', 'Mañana'), isFalse);
    });
  });
}
