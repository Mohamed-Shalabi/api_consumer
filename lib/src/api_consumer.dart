import 'dart:async';

import 'package:darc/darc.dart';
import 'package:fpdart/fpdart.dart';

/// The main API consumer interface that defines the contract for all HTTP
/// operations (GET/POST/PUT/DELETE) with token and locale handling.
abstract class ApiConsumer<Canceller extends DownloadCanceller> {
  /// Sets the current OAuth2 token and prepares the client for authenticated
  /// requests (typically by setting an Authorization header).
  Future<void> setToken(ApiOAuth2Token token);

  /// Indicates whether there is a token currently configured for
  /// authenticated requests.
  bool get hasToken;

  /// Removes any configured token and clears authentication state.
  Future<void> removeToken();

  /// Persists the app locale to be sent with outgoing requests (e.g. via
  /// a custom header) so the backend can localize responses.
  void saveLocale(String locale);

  /// Performs a GET request to [path] and parses the response.
  ///
  /// Parameters:
  /// - [parser]: Transforms the raw JSON/data into the required type `T`.
  /// - [errorParser]: Optional function that maps an error body into a custom
  /// error `E`.
  /// - [queryParameters]: Optional query parameters to append to the request
  /// URL.
  /// - [additionalHeaders]: Optional additional headers for this specific
  /// request.
  ApiResultOf<E?, T> get<E, T>(
    String path, {
    required T Function(dynamic data) parser,
    E Function(dynamic data)? errorParser,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? additionalHeaders,
  });

  /// Downloads a file to [filePath] from [url], emitting progress 0..1.
  ///
  /// Provide a [canceller] to allow the caller to cancel the download.
  ApiResultOf<E, Stream<Either<RequestException<E>, double>>> download<E>(
    String url,
    String filePath, {
    E Function(dynamic data)? errorParser,
    Canceller? canceller,
  });

  /// Performs a POST request to [path].
  ///
  /// Parameters:
  /// - [parser]: Transforms the raw JSON/data into the required type `T`.
  /// - [errorParser]: Optional function that maps an error body into a custom
  /// error `E`.
  /// - [body]: Optional request body for JSON or form data.
  /// - [queryParameters]: Optional query parameters to append to the request
  /// URL.
  /// - [additionalHeaders]: Optional additional headers for this specific
  /// request.
  /// - [files]: Files to include as multipart form data (if provided).
  ApiResultOf<E?, T> post<E, T>(
    String path, {
    required T Function(dynamic data) parser,
    E Function(dynamic data)? errorParser,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? additionalHeaders,
    List<MultiPartFileModel>? files,
  });

  /// Performs a PUT request to [path].
  ///
  /// Parameters:
  /// - [parser]: Transforms the raw JSON/data into the required type `T`.
  /// - [errorParser]: Optional function that maps an error body into a custom
  /// error `E`.
  /// - [body]: Optional request body for JSON or form data.
  /// - [queryParameters]: Optional query parameters to append to the request
  /// URL.
  /// - [additionalHeaders]: Optional additional headers for this specific
  /// request.
  /// - [files]: Files to include as multipart form data (if provided).
  ApiResultOf<E?, T> put<E, T>(
    String path, {
    required T Function(dynamic data) parser,
    E Function(dynamic data)? errorParser,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? additionalHeaders,
    List<MultiPartFileModel>? files,
  });

  /// Performs a DELETE request to [path].
  ///
  /// Parameters:
  /// - [parser]: Transforms the raw JSON/data into the required type `T`.
  /// - [errorParser]: Optional function that maps an error body into a custom
  /// error `E`.
  /// - [additionalHeaders]: Optional additional headers for this specific
  /// request.
  /// - [data]: Optional request body for delete operations.
  ApiResultOf<E?, T> delete<E, T>(
    String path, {
    required T Function(dynamic data) parser,
    E Function(dynamic data)? errorParser,
    Map<String, dynamic>? additionalHeaders,
    Map<String, dynamic>? data,
  });
}
