// ignoring some strict rules to simplify testing
// ignore: lines_longer_than_80_chars
// ignore_for_file: inference_failure_on_function_invocation, strict_raw_type, avoid_dynamic_calls

import 'package:darc/src/impl/dio_consumer.dart';
import 'package:darc/src/request_exceptions.dart';
import 'package:darc/src/status_codes.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import '../mocks/mocks.dart';

void main() {
  group('Connection errors', () {
    test('connectionTimeout returns FetchDataException', () async {
      final exception = createConnectionException(
        DioExceptionType.connectionTimeout,
      );
      final error = handleDioError(exception);

      expect(error, isA<FetchDataException>());
    });

    test('connectionError returns FetchDataException', () async {
      final exception = createConnectionException(
        DioExceptionType.connectionError,
      );
      final error = handleDioError(exception);

      expect(error, isA<FetchDataException>());
    });

    test('receiveTimeout returns FetchDataException', () async {
      final exception = createConnectionException(
        DioExceptionType.receiveTimeout,
      );
      final error = handleDioError(exception);

      expect(error, isA<FetchDataException>());
    });

    test('sendTimeout returns FetchDataException', () async {
      final exception = createConnectionException(DioExceptionType.sendTimeout);
      final error = handleDioError(exception);

      expect(error, isA<FetchDataException>());
    });

    test('cancel returns CancelledRequestException', () async {
      final exception = createConnectionException(DioExceptionType.cancel);
      final error = handleDioError(exception);

      expect(error, isA<CancelledRequestException>());
    });

    test('badCertificate returns FetchDataException', () async {
      final exception = createConnectionException(
        DioExceptionType.badCertificate,
      );
      final error = handleDioError(exception);

      expect(error, isA<FetchDataException>());
    });

    test('unknown returns RequestUnknownException', () async {
      final exception = createConnectionException(DioExceptionType.unknown);
      final error = handleDioError(exception);

      expect(error, isA<RequestUnknownException>());
    });

    test(
      'badResponse with StatusCodes.badRequest returns BadRequestException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.badRequest,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<BadRequestException>());
      },
    );

    test(
        'badResponse with StatusCodes.unauthenticated '
        'returns UnauthenticatedException', () async {
      final exception = createConnectionException(
        DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: StatusCodes.unauthenticated,
          data: {'error': 'Error'},
        ),
      );

      final error = handleDioError(exception);

      expect(error, isA<UnauthenticatedException>());
    });

    test(
      'badResponse with StatusCodes.forbidden returns UnauthorizedException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.forbidden,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<UnauthorizedException>());
      },
    );

    test(
      'badResponse with StatusCodes.notFound returns NotFoundException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.notFound,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<NotFoundException>());
      },
    );

    test(
      'badResponse with StatusCodes.conflict returns ConflictException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.conflict,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<ConflictException>());
      },
    );

    test(
      'badResponse with StatusCodes.badResponse returns BadResponseException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.badResponse,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<BadResponseException>());
      },
    );

    test(
      'badResponse with StatusCodes.invalidToken returns InvalidTokenException',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.invalidToken,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(exception);

        expect(error, isA<InvalidTokenException>());
      },
    );

    test(
        'badResponse with StatusCodes.unprocessableData '
        'returns UnProcessableDataException', () async {
      final exception = createConnectionException(
        DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: StatusCodes.unProcessableData,
          data: {'error': 'Error'},
        ),
      );

      final error = handleDioError(exception);

      expect(error, isA<UnProcessableDataException>());
    });

    test(
      'badResponse with StatusCodes.unprocessableData calls errorParser',
      () async {
        final exception = createConnectionException(
          DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: StatusCodes.unProcessableData,
            data: {'error': 'Error'},
          ),
        );

        final error = handleDioError(
          exception,
          errorParser: (body) => body['error'] as String,
        );

        expect(error, isA<UnProcessableDataException>());
        expect(error.data, equals('Error'));
      },
    );

    test(
        'badResponse with StatusCodes.serverError '
        'returns InternalServerErrorException', () async {
      final exception = createConnectionException(
        DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: StatusCodes.serverError,
          data: {'error': 'Error'},
        ),
      );

      final error = handleDioError(exception);

      expect(error, isA<InternalServerErrorException>());
    });
  });
}
