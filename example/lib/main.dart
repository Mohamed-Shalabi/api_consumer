import 'dart:async';
import 'dart:io';

import 'package:darc/darc.dart';
import 'package:darc_example/models/post.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:fresh_dio/fresh_dio.dart';
import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final advanced = args.contains('--advanced');
  final cancelDownload = args.contains('--cancel');

  print('== darc console example ==');
  print('Config: ${advanced ? "advanced" : "basic"}');

  final api = await _buildApi(advanced: advanced);

  await _runCrudDemo(api);
  await _runDownloadDemo(api, cancel: cancelDownload);

  print('\nDone.');
}

Future<ApiConsumer<DioDownloadCanceller>> _buildApi({
  required bool advanced,
}) async {
  const baseUrl = 'https://dummyjson.com';

  if (advanced) {
    ApiErrorMessages.instance = ApiErrorMessages(
      connectionError: () => 'Network error. Check connection.',
      downloadCanceled: () => 'Download cancelled.',
      unknownError: () => 'Unknown error.',
      pleaseLogin: () => 'Please login.',
      wrongData: () => 'Wrong data.',
      serverError: () => 'Server error.',
      unauthorized: () => 'Unauthorized.',
    );
  }

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        print(options.uri);
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ),
  );

  final fresh = Fresh<ApiOAuth2Token>(
    tokenHeader: (token) => {'Authorization': 'Bearer ${token.accessToken}'},
    tokenStorage: _InMemoryTokenStorage(),
    shouldRefresh: (response) => response?.statusCode == 401,
    refreshToken: (token, httpClient) async => throw RevokeTokenException(),
  );

  final api = DioConsumer(
    client: dio,
    tokenInterceptor: fresh,
    baseUrl: baseUrl,
  );

  api.saveLocale('en');
  return api;
}

Future<void> _runCrudDemo(ApiConsumer<DioDownloadCanceller> api) async {
  print('\n== CRUD demo (DummyJSON) ==');

  final postsResult = await api.get<Object, List<Post>>(
    '/posts',
    parser: (data) {
      final list = data['posts'] as List<dynamic>;
      return list.map(Post.fromJson).toList();
    },
  );

  await postsResult.fold(
    (e) async => print('GET /posts failed: ${e.message} - ${e.code}'),
    (posts) async {
      print('GET /posts ok, count=${posts.length}');
      for (final post in posts.take(3)) {
        print(' - #${post.id}: ${post.title}');
      }
    },
  );

  final createResult = await api.post<Object, Post>(
    '/posts/add',
    body: const PostCreateRequest(
      userId: 1,
      title: 'Hello from darc console',
      body: 'Created using darc + DummyJSON',
    ).toJson(),
    parser: Post.fromJson,
  );

  final Post? created = createResult.fold(
    (e) {
      print('POST /posts failed: ${e.message} - ${e.code}');
      return null;
    },
    (post) {
      print('POST /posts ok, id=${post.id}');
      return post;
    },
  );

  final putResult = await api.put<Object, Post>(
    '/posts/1',
    body: const PostUpdateRequest(
      title: 'Updated title',
      body: 'Updated body',
    ).toJson(),
    parser: (data) {
      final json = data as Map<String, dynamic>;
      return Post.fromJson({...json, 'id': 1, 'userId': 1});
    },
  );

  putResult.fold(
    (e) => print('PUT /posts/1 failed: ${e.message} - ${e.code}'),
    (post) => print('PUT /posts/1 ok: ${post.title}'),
  );

  final deleteResult = await api.delete<Object, bool>(
    '/posts/1',
    parser: (_) => true,
  );

  deleteResult.fold(
    (e) => print('DELETE /posts/1 failed: ${e.message} - ${e.code}'),
    (ok) => print('DELETE /posts/1 ok: $ok'),
  );

  if (created != null) {
    print('Created post title (typed): ${created.title}');
  }
}

Future<void> _runDownloadDemo(
  ApiConsumer<DioDownloadCanceller> api, {
  required bool cancel,
}) async {
  print('\n== Download demo ==');

  const url =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  final dir = await Directory.systemTemp.createTemp('darc_example_');
  final savePath = p.join(dir.path, 'butterfly.mp4');
  print('Saving to: $savePath');

  final canceller = DioDownloadCanceller(CancelToken());

  Timer? cancelTimer;
  if (cancel) {
    cancelTimer = Timer(const Duration(milliseconds: 800), () async {
      print('\nCancelling download...');
      await canceller.cancel();
    });
  }

  final result = await api.download<Object>(
    url,
    savePath,
    canceller: canceller,
  );

  await result.fold(
    (e) async {
      cancelTimer?.cancel();
      print('Download start failed: ${e.message} - ${e.code}');
    },
    (stream) async {
      final completer = Completer<void>();

      late final StreamSubscription<Either<RequestException<Object>, double>>
      sub;
      sub = stream.listen((event) {
        event.fold(
          (e) async {
            cancelTimer?.cancel();
            print('\nDownload failed: ${e.message} - ${e.code}');
            await sub.cancel();
            completer.complete();
          },
          (progress) {
            final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
            stdout.write('\rProgress: $pct%\n');
            if (progress >= 1) {
              cancelTimer?.cancel();
              stdout.writeln('\nDownload complete.');
              completer.complete();
            }
          },
        );
      });

      await completer.future;
      await sub.cancel();
    },
  );
}

final class _InMemoryTokenStorage extends TokenStorage<ApiOAuth2Token> {
  ApiOAuth2Token? _token;

  @override
  Future<void> delete() async {
    _token = null;
  }

  @override
  Future<ApiOAuth2Token?> read() async {
    return _token;
  }

  @override
  Future<void> write(ApiOAuth2Token token) async {
    _token = token;
  }
}
