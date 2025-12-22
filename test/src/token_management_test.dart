import 'package:darc/src/api_o_auth2_token.dart';
import 'package:darc/src/impl/dio_consumer.dart';
import 'package:darc/src/status_codes.dart';
import 'package:dio/dio.dart';
import 'package:fresh_dio/fresh_dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks/mocks.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late Fresh<ApiOAuth2Token> interceptor;
  late DioConsumer sut;

  const baseUrl = 'https://api.example.com';

  setUpAll(() {
    registerFallbackValue(FakeOptions());
    registerFallbackValue(FakeOAuth2Token());
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(FakeCancelToken());
    registerFallbackValue(FakeFormData());
  });

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: baseUrl));
    dioAdapter = DioAdapter(dio: dio);
  });

  tearDown(() {
    dioAdapter.close();
  });

  // ===========================================================================
  // BASIC TOKEN MANAGEMENT
  // ===========================================================================

  group('Token Management', () {
    setUp(() {
      interceptor = createAuthInterceptorWithSuccessRefresh();
      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );
    });

    test('hasToken returns false when no initial token', () {
      expect(sut.hasToken, isFalse);
    });

    test(
      'should save the token initially if initial token is provided',
      () async {
        final freshInterceptor = createAuthInterceptorWithSuccessRefresh(
          initialToken: const ApiOAuth2Token(
            accessToken: 'initial-token',
            refreshToken: 'initial-refresh-token',
          ),
        );

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: freshInterceptor,
          baseUrl: baseUrl,
        );

        await sut.isInitialized;

        expect(sut.hasToken, isTrue);
        expect(
          await freshInterceptor.token.then((value) => value?.accessToken),
          'initial-token',
        );
        expect(
          await freshInterceptor.token.then((value) => value?.refreshToken),
          'initial-refresh-token',
        );
      },
    );

    test(
      'should have no token initially if no initial token is provided',
      () async {
        final freshInterceptor = createAuthInterceptorWithSuccessRefresh();

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: freshInterceptor,
          baseUrl: baseUrl,
        );

        await sut.isInitialized;

        expect(sut.hasToken, isFalse);
        expect(await freshInterceptor.token, null);
      },
    );

    test('setToken updates interceptor', () async {
      const token = ApiOAuth2Token(accessToken: 'test-token-123');

      await sut.isInitialized;
      await sut.setToken(token);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sut.hasToken, isTrue);
      expect(
        await sut.tokenInterceptor.token.then((value) => value?.accessToken),
        token.accessToken,
      );
    });

    test('removeToken clears token', () async {
      await sut.setToken(const ApiOAuth2Token(accessToken: 'to-remove'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await sut.removeToken();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(sut.hasToken, isFalse);
      expect(await sut.tokenInterceptor.token, null);
    });

    test('saveLocale sets X-APP-LOCALE header', () {
      sut.saveLocale('ar');
      expect(dio.options.headers['X-APP-LOCALE'], equals('ar'));
    });
  });

  // ===========================================================================
  // ACCESS TOKEN SCENARIOS
  // ===========================================================================

  group('Access Token Scenarios', () {
    test('access token only (no refresh token) - hasToken is true', () async {
      interceptor = createAuthInterceptorWithAccessTokenOnly(
        accessToken: 'access-only-token',
      );

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      expect(sut.hasToken, isTrue);
      expect(
        await interceptor.token.then((t) => t?.accessToken),
        'access-only-token',
      );
      expect(await interceptor.token.then((t) => t?.refreshToken), isNull);
    });

    test(
      'access token expired, server returns 401, refresh succeeds - new tokens '
      'used',
      () async {
        var refreshCalled = false;
        ApiOAuth2Token? newToken;

        interceptor = Fresh<ApiOAuth2Token>(
          tokenHeader: (token) => {
            'Authorization': 'Bearer ${token.accessToken}',
          },
          tokenStorage: FakeTokenStorage(
            initialData: {
              FakeTokenStorage.accessTokenKey: 'expired-access-token',
              FakeTokenStorage.refreshTokenKey: 'valid-refresh-token',
            },
          ),
          shouldRefresh: (response) =>
              response?.statusCode == StatusCodes.unauthenticated,
          refreshToken: (token, httpClient) async {
            refreshCalled = true;
            newToken = const ApiOAuth2Token(
              accessToken: 'new-access-token',
              refreshToken: 'new-refresh-token',
            );
            return newToken!;
          },
        );

        dio.interceptors.add(interceptor);

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: interceptor,
          baseUrl: baseUrl,
        );

        await sut.isInitialized;

        // Mock: first request returns 401, second (retry) returns 200
        dioAdapter
          ..onGet(
            '/protected',
            (server) => server.reply(StatusCodes.unauthenticated, {
              'error': 'Token expired',
            }),
            headers: {'Authorization': 'Bearer expired-access-token'},
          )
          ..onGet(
            '/protected',
            (server) => server.reply(200, {'data': 'success'}),
            headers: {'Authorization': 'Bearer new-access-token'},
          );

        await sut.get<void, Map<String, dynamic>>(
          '/protected',
          parser: (data) => data as Map<String, dynamic>,
        );

        // After 401, refresh was called and new token is used
        expect(refreshCalled, isTrue);
        expect(newToken?.accessToken, 'new-access-token');
        expect(newToken?.refreshToken, 'new-refresh-token');
      },
    );

    test(
      'access token expired, no refresh token available - RevokeTokenException '
      'thrown',
      () async {
        var revokeThrown = false;

        interceptor = Fresh<ApiOAuth2Token>(
          tokenHeader: (token) => {
            'Authorization': 'Bearer ${token.accessToken}',
          },
          tokenStorage: FakeTokenStorage(
            initialData: {FakeTokenStorage.accessTokenKey: 'expired-token'},
          ),
          shouldRefresh: (response) =>
              response?.statusCode == StatusCodes.unauthenticated,
          refreshToken: (token, httpClient) {
            revokeThrown = true;
            throw RevokeTokenException();
          },
        );

        dio.interceptors.add(interceptor);

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: interceptor,
          baseUrl: baseUrl,
        );

        await sut.isInitialized;

        dioAdapter.onGet(
          '/protected',
          (server) => server.reply(StatusCodes.unauthenticated, {
            'error': 'Unauthorized',
          }),
        );

        final result = await sut.get<void, Map<String, dynamic>>(
          '/protected',
          parser: (data) => data as Map<String, dynamic>,
        );

        // The refresh throws, so we get an error
        expect(result.isLeft(), isTrue);
        expect(revokeThrown, isTrue);
      },
    );

    test(
      'access token expired, refresh token also expired - RevokeTokenException '
      'thrown',
      () async {
        var revokeThrown = false;

        interceptor = Fresh<ApiOAuth2Token>(
          tokenHeader: (token) => {
            'Authorization': 'Bearer ${token.accessToken}',
          },
          tokenStorage: FakeTokenStorage(
            initialData: {
              FakeTokenStorage.accessTokenKey: 'expired-access',
              FakeTokenStorage.refreshTokenKey: 'expired-refresh',
            },
          ),
          shouldRefresh: (response) =>
              response?.statusCode == StatusCodes.unauthenticated,
          refreshToken: (token, httpClient) {
            revokeThrown = true;
            throw RevokeTokenException();
          },
        );

        dio.interceptors.add(interceptor);

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: interceptor,
          baseUrl: baseUrl,
        );

        await sut.isInitialized;

        dioAdapter.onGet(
          '/protected',
          (server) => server.reply(StatusCodes.unauthenticated, {
            'error': 'Token expired',
          }),
        );

        final result = await sut.get<void, Map<String, dynamic>>(
          '/protected',
          parser: (data) => data as Map<String, dynamic>,
        );

        expect(result.isLeft(), isTrue);
        expect(revokeThrown, isTrue);
      },
    );
  });

  // ===========================================================================
  // REFRESH TOKEN SCENARIOS
  // ===========================================================================

  group('Refresh Token Scenarios', () {
    test('refresh token callback receives current token and can update both '
        'tokens', () async {
      var receivedToken = const ApiOAuth2Token(accessToken: '');

      interceptor = Fresh<ApiOAuth2Token>(
        tokenHeader: (token) => {
          'Authorization': 'Bearer ${token.accessToken}',
        },
        tokenStorage: FakeTokenStorage(
          initialData: {
            FakeTokenStorage.accessTokenKey: 'old-access',
            FakeTokenStorage.refreshTokenKey: 'old-refresh',
          },
        ),
        shouldRefresh: (response) =>
            response?.statusCode == StatusCodes.unauthenticated,
        refreshToken: (token, httpClient) async {
          receivedToken = token!;
          return const ApiOAuth2Token(
            accessToken: 'refreshed-access',
            refreshToken: 'refreshed-refresh',
          );
        },
      );

      dio.interceptors.add(interceptor);

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      // Verify initial token is loaded correctly
      final initialToken = await interceptor.token;
      expect(initialToken?.accessToken, 'old-access');
      expect(initialToken?.refreshToken, 'old-refresh');

      // Trigger a 401 to invoke refresh callback
      dioAdapter.onGet(
        '/trigger-refresh',
        (server) =>
            server.reply(StatusCodes.unauthenticated, {'error': 'Expired'}),
      );

      await sut.get<void, Map<String, dynamic>>(
        '/trigger-refresh',
        parser: (data) => data as Map<String, dynamic>,
      );

      // Verify the refresh callback received the old token
      expect(receivedToken.accessToken, 'old-access');
      expect(receivedToken.refreshToken, 'old-refresh');

      // Verify new token is stored
      final newToken = await interceptor.token;
      expect(newToken?.accessToken, 'refreshed-access');
      expect(newToken?.refreshToken, 'refreshed-refresh');
    });

    test('refresh token failure triggers unauthenticated status', () async {
      var becameUnauthenticated = false;

      interceptor = Fresh<ApiOAuth2Token>(
        tokenHeader: (token) => {
          'Authorization': 'Bearer ${token.accessToken}',
        },
        tokenStorage: FakeTokenStorage(
          initialData: {
            FakeTokenStorage.accessTokenKey: 'old-access',
            FakeTokenStorage.refreshTokenKey: 'old-refresh',
          },
        ),
        shouldRefresh: (response) =>
            response?.statusCode == StatusCodes.unauthenticated,
        refreshToken: (token, httpClient) => throw RevokeTokenException(),
      );

      interceptor.authenticationStatus.listen((status) {
        if (status == AuthenticationStatus.unauthenticated) {
          becameUnauthenticated = true;
        }
      });

      dio.interceptors.add(interceptor);

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      dioAdapter.onGet(
        '/protected',
        (server) =>
            server.reply(StatusCodes.unauthenticated, {'error': 'Expired'}),
      );

      await sut.get<void, Map<String, dynamic>>(
        '/protected',
        parser: (data) => data as Map<String, dynamic>,
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(becameUnauthenticated, isTrue);
      expect(sut.hasToken, isFalse);
      expect(await interceptor.token, isNull);
    });
  });

  // ===========================================================================
  // EDGE CASES
  // ===========================================================================

  group('Edge Cases', () {
    test(
      'request made before isInitialized - awaits initialization automatically',
      () async {
        interceptor = createAuthInterceptorWithSuccessRefresh(
          initialToken: const ApiOAuth2Token(
            accessToken: 'initial-token',
            refreshToken: 'initial-refresh',
          ),
        );

        sut = DioConsumer(
          client: dio,
          tokenInterceptor: interceptor,
          baseUrl: baseUrl,
        );

        dioAdapter.onGet(
          '/test',
          (server) => server.reply(200, {'data': 'value'}),
        );

        // Make request WITHOUT awaiting isInitialized first
        final result = await sut.get<void, Map<String, dynamic>>(
          '/test',
          parser: (data) => data as Map<String, dynamic>,
        );

        expect(result.isRight(), isTrue);
        expect(sut.hasToken, isTrue);
      },
    );

    test('multiple setToken calls - latest token wins', () async {
      interceptor = createAuthInterceptorWithSuccessRefresh();

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      await sut.setToken(const ApiOAuth2Token(accessToken: 'first-token'));
      await sut.setToken(const ApiOAuth2Token(accessToken: 'second-token'));
      await sut.setToken(const ApiOAuth2Token(accessToken: 'third-token'));

      expect(
        await sut.tokenInterceptor.token.then((t) => t?.accessToken),
        'third-token',
      );
    });

    test('setToken after removeToken restores authentication', () async {
      interceptor = createAuthInterceptorWithSuccessRefresh();

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      // Set initial token
      await sut.setToken(const ApiOAuth2Token(accessToken: 'initial'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sut.hasToken, isTrue);

      // Remove token
      await sut.removeToken();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sut.hasToken, isFalse);

      // Set new token
      await sut.setToken(const ApiOAuth2Token(accessToken: 'restored'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(sut.hasToken, isTrue);
      expect(
        await sut.tokenInterceptor.token.then((t) => t?.accessToken),
        'restored',
      );
    });

    test('successful request with valid token returns Right', () async {
      interceptor = createAuthInterceptorWithSuccessRefresh(
        initialToken: const ApiOAuth2Token(
          accessToken: 'valid-token',
          refreshToken: 'valid-refresh',
        ),
      );

      sut = DioConsumer(
        client: dio,
        tokenInterceptor: interceptor,
        baseUrl: baseUrl,
      );

      await sut.isInitialized;

      dioAdapter.onGet(
        '/data',
        (server) => server.reply(200, {'result': 'success'}),
      );

      final result = await sut.get<void, Map<String, dynamic>>(
        '/data',
        parser: (data) => data as Map<String, dynamic>,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['result'], 'success'),
      );
    });
  });
}
