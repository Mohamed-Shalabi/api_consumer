part of 'dio_consumer.dart';

@visibleForTesting
RequestException<E> handleDioError<E>(
  DioException error, {
  E Function(dynamic body)? errorParser,
}) {
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout =>
      FetchDataException(),
    DioExceptionType.cancel => CancelledRequestException(),
    DioExceptionType.badResponse => handleResponseError(
        error,
        errorParser: errorParser,
      ),
    DioExceptionType.unknown => RequestUnknownException(),
  };
}

@visibleForTesting
RequestException<E> handleResponseError<E>(
  DioException error, {
  E Function(dynamic body)? errorParser,
}) {
  return switch (error.response?.statusCode) {
    null => RequestUnknownException(),
    StatusCodes.badRequest => BadRequestException(
        responseBody: error.response!.data,
      ),
    StatusCodes.unauthenticated => UnauthenticatedException(
        responseBody: error.response!.data,
      ),
    StatusCodes.forbidden => UnauthorizedException(
        responseBody: error.response!.data,
      ),
    StatusCodes.notFound => NotFoundException(
        responseBody: error.response!.data,
      ),
    StatusCodes.conflict => ConflictException(
        responseBody: error.response!.data,
      ),
    StatusCodes.badResponse => BadResponseException(
        responseBody: error.response!.data,
      ),
    StatusCodes.invalidToken => InvalidTokenException(
        responseBody: error.response!.data,
      ),
    StatusCodes.unProcessableData => UnProcessableDataException(
        responseBody: error.response!.data as Map<String, dynamic>,
        errorParser: errorParser,
      ),
    StatusCodes.serverError => InternalServerErrorException(
        responseBody: error.response!.data as Map<String, dynamic>,
      ),
    _ => RequestUnknownException(),
  };
}
