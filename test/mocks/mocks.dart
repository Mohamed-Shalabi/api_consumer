// ignoring some strict rules to simplify testing
// ignore_for_file: inference_failure_on_function_invocation

import 'dart:async';

import 'package:darc/src/api_o_auth2_token.dart';
import 'package:darc/src/impl/dio_consumer.dart';
import 'package:darc/src/status_codes.dart';
import 'package:dio/dio.dart';
import 'package:fresh_dio/fresh_dio.dart';
import 'package:mocktail/mocktail.dart';

// =============================================================================
// MOCK CLASSES
// =============================================================================

/// Mock Dio client for testing HTTP operations.
class MockDio extends Mock implements Dio {
  MockDio() {
    // Set up real BaseOptions so headers can be modified
    _options = BaseOptions();
    _interceptors = Interceptors();
  }

  late final BaseOptions _options;
  late final Interceptors _interceptors;

  @override
  BaseOptions get options => _options;

  @override
  Interceptors get interceptors => _interceptors;
}

/// Mock DioDownloadCanceller for testing download cancellation.
class MockDioCancelToken extends Mock implements CancelToken {}

// =============================================================================
// FAKE CLASSES FOR simulation
// =============================================================================

class FakeTokenStorage extends Fake implements TokenStorage<ApiOAuth2Token> {
  FakeTokenStorage({Map<String, String>? initialData})
    : _storage = initialData ?? {};

  static const accessTokenKey = 'access-token';
  static const refreshTokenKey = 'refresh-token';

  final Map<String, String?> _storage;

  @override
  Future<ApiOAuth2Token?> read() async {
    final (accessToken, refreshToken) = (
      _storage[accessTokenKey],
      _storage[refreshTokenKey],
    );

    if (accessToken == null) {
      return null;
    }

    return ApiOAuth2Token(accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> write(ApiOAuth2Token token) async {
    _storage[accessTokenKey] = token.accessToken;
    _storage[refreshTokenKey] = token.refreshToken;
  }

  @override
  Future<void> delete() async {
    _storage
      ..remove(accessTokenKey)
      ..remove(refreshTokenKey);
  }
}

// =============================================================================
// FAKE CLASSES FOR registerFallbackValue
// =============================================================================

class FakeOptions extends Fake implements Options {}

class FakeOAuth2Token extends Fake implements OAuth2Token {}

class FakeRequestOptions extends Fake implements RequestOptions {}

class FakeCancelToken extends Fake implements CancelToken {}

class FakeFormData extends Fake implements FormData {}

class MockMultipartFileFactory extends Mock implements MultipartFileFactory {}

// =============================================================================
// TEST HELPERS
// =============================================================================

/// Creates an auth interceptor with successful refresh process
Fresh<ApiOAuth2Token> createAuthInterceptorWithSuccessRefresh({
  ApiOAuth2Token? initialToken,
}) {
  return Fresh<ApiOAuth2Token>(
    tokenHeader: (token) => {'Authorization': 'Bearer ${token.accessToken}'},
    tokenStorage: FakeTokenStorage(
      initialData: initialToken == null
          ? null
          : {
              FakeTokenStorage.accessTokenKey: initialToken.accessToken,
              if (initialToken.refreshToken != null)
                FakeTokenStorage.refreshTokenKey: initialToken.refreshToken!,
            },
    ),
    shouldRefresh: (response) =>
        response?.statusCode == StatusCodes.unauthenticated,
    refreshToken: (token, httpClient) async => const ApiOAuth2Token(
      accessToken: 'new_access_token',
      refreshToken: 'new_refresh_token',
    ),
  );
}

/// Creates an auth interceptor with failing refresh process
Fresh<ApiOAuth2Token> createAuthInterceptorWithFailureRefresh() {
  return Fresh<ApiOAuth2Token>(
    tokenHeader: (token) => {'Authorization': 'Bearer ${token.accessToken}'},
    tokenStorage: FakeTokenStorage(),
    shouldRefresh: (response) =>
        response?.statusCode == StatusCodes.unauthenticated,
    refreshToken: (token, httpClient) => throw Exception('Refresh failed'),
  );
}

/// Creates an auth interceptor that simulates an expired refresh token
/// (refresh attempt throws RevokeTokenException)
Fresh<ApiOAuth2Token> createAuthInterceptorWithExpiredRefreshToken({
  required ApiOAuth2Token initialToken,
}) {
  return Fresh<ApiOAuth2Token>(
    tokenHeader: (token) => {'Authorization': 'Bearer ${token.accessToken}'},
    tokenStorage: FakeTokenStorage(
      initialData: {
        FakeTokenStorage.accessTokenKey: initialToken.accessToken,
        if (initialToken.refreshToken != null)
          FakeTokenStorage.refreshTokenKey: initialToken.refreshToken!,
      },
    ),
    shouldRefresh: (response) =>
        response?.statusCode == StatusCodes.unauthenticated,
    refreshToken: (token, httpClient) => throw RevokeTokenException(),
  );
}

/// Creates an auth interceptor with access token only (no refresh token)
Fresh<ApiOAuth2Token> createAuthInterceptorWithAccessTokenOnly({
  required String accessToken,
}) {
  return Fresh<ApiOAuth2Token>(
    tokenHeader: (token) => {'Authorization': 'Bearer ${token.accessToken}'},
    tokenStorage: FakeTokenStorage(
      initialData: {
        FakeTokenStorage.accessTokenKey: accessToken,
        // No refresh token
      },
    ),
    shouldRefresh: (response) =>
        response?.statusCode == StatusCodes.unauthenticated,
    refreshToken: (token, httpClient) => throw RevokeTokenException(),
  );
}

/// Creates a successful Dio Response with the given data.
Response<Map<String, dynamic>> createSuccessResponse(
  Map<String, dynamic> data, {
  int statusCode = 200,
  String path = '/test',
}) {
  return Response<Map<String, dynamic>>(
    data: data,
    statusCode: statusCode,
    requestOptions: RequestOptions(path: path),
  );
}

/// Creates a DioException for bad response testing.
DioException createBadResponseException({
  required int statusCode,
  dynamic data,
  String path = '/test',
}) {
  final requestOptions = RequestOptions(path: path);
  return DioException(
    type: DioExceptionType.badResponse,
    response: Response(
      statusCode: statusCode,
      data: data ?? {'message': 'Error'},
      requestOptions: requestOptions,
    ),
    requestOptions: requestOptions,
  );
}

/// Creates a DioException for connection/timeout errors.
DioException createConnectionException(
  DioExceptionType type, {
  Response<dynamic>? response,
}) {
  final requestOptions =
      response?.requestOptions ?? RequestOptions(path: '/test');
  return DioException(
    type: type,
    response: response,
    requestOptions: requestOptions,
  );
}

/// Helper to set up mock for successful GET request.
void stubGetSuccess(
  MockDio mockDio,
  Map<String, dynamic> responseData, {
  String? path,
}) {
  when(
    () => mockDio.get<dynamic>(
      path ?? any(),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => createSuccessResponse(responseData));
}

/// Helper to set up mock for GET request throwing DioException.
void stubGetError(MockDio mockDio, DioException exception) {
  when(
    () => mockDio.get<dynamic>(
      any(),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenThrow(exception);
}

/// Helper to set up mock for successful POST request.
void stubPostSuccess(
  MockDio mockDio,
  Map<String, dynamic> responseData, {
  String? path,
}) {
  when(
    () => mockDio.post<dynamic>(
      path ?? any(),
      data: any(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => createSuccessResponse(responseData));
}

/// Helper to set up mock for POST request throwing DioException.
void stubPostError(MockDio mockDio, DioException exception) {
  when(
    () => mockDio.post<dynamic>(
      any(),
      data: any(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenThrow(exception);
}

/// Helper to set up mock for successful PUT request.
void stubPutSuccess(
  MockDio mockDio,
  Map<String, dynamic> responseData, {
  String? path,
}) {
  when(
    () => mockDio.put<dynamic>(
      path ?? any(),
      data: any(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => createSuccessResponse(responseData));
}

/// Helper to set up mock for PUT request throwing DioException.
void stubPutError(MockDio mockDio, DioException exception) {
  when(
    () => mockDio.put<dynamic>(
      any(),
      data: any(named: 'data'),
      queryParameters: any(named: 'queryParameters'),
      options: any(named: 'options'),
    ),
  ).thenThrow(exception);
}

/// Helper to set up mock for successful DELETE request.
void stubDeleteSuccess(
  MockDio mockDio,
  Map<String, dynamic> responseData, {
  String? path,
}) {
  when(
    () => mockDio.delete<dynamic>(
      path ?? any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => createSuccessResponse(responseData));
}

/// Helper to set up mock for DELETE request throwing DioException.
void stubDeleteError(MockDio mockDio, DioException exception) {
  when(
    () => mockDio.delete<dynamic>(
      any(),
      data: any(named: 'data'),
      options: any(named: 'options'),
    ),
  ).thenThrow(exception);
}

/// Helper to set up mock for download.
void stubDownloadSuccess(MockDio mockDio) {
  when(
    () => mockDio.download(
      any(),
      any(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((invocation) async {
    // Get the onReceiveProgress callback and invoke it
    final onReceiveProgress =
        invocation.namedArguments[const Symbol('onReceiveProgress')]
            as void Function(int, int)?;
    if (onReceiveProgress != null) {
      onReceiveProgress(50, 100);
      onReceiveProgress(100, 100);
    }
    return Response(
      statusCode: 200,
      requestOptions: RequestOptions(path: '/download'),
    );
  });
}

/// Helper to set up mock for interrupted download without cancellation.
void stubDownloadCancelled(MockDio mockDio) {
  when(
    () => mockDio.download(
      any(),
      any(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenAnswer((invocation) async {
    // Get the onReceiveProgress callback and invoke it
    final onReceiveProgress =
        invocation.namedArguments[const Symbol('onReceiveProgress')]
            as void Function(int, int);
    final cancelToken =
        invocation.namedArguments[const Symbol('cancelToken')] as CancelToken;

    onReceiveProgress(50, 100);
    unawaited(Future.microtask(cancelToken.cancel));

    return Response(
      statusCode: 200,
      requestOptions: RequestOptions(path: '/download'),
    );
  });
}

/// Helper to set up mock download canceller
void stubDownloadCanceller(MockDioCancelToken mockDioCancelToken) {
  when(() => mockDioCancelToken.cancel()).thenAnswer((_) async {});
}

/// Helper to set up mock for download throwing DioException.
void stubDownloadError(MockDio mockDio, DioException exception) {
  when(
    () => mockDio.download(
      any(),
      any(),
      cancelToken: any(named: 'cancelToken'),
      onReceiveProgress: any(named: 'onReceiveProgress'),
    ),
  ).thenThrow(exception);
}
