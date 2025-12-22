import 'package:darc/src/request_exceptions.dart';
import 'package:darc/src/status_codes.dart';
import 'package:test/test.dart';

void main() {
  group('RequestException', () {
    group('Message extraction', () {
      test('extracts message from body map when present', () {
        final exception = BadRequestException<void>(
          responseBody: const {'message': 'Custom error message'},
        );

        expect(exception.message, equals('Custom error message'));
      });

      test('uses spare message when body has no message field', () {
        final exception = BadRequestException<void>(
          responseBody: const {'error': 'some error'},
        );

        // Uses the default spare message (translation key)
        expect(exception.message, isNotEmpty);
      });

      test('uses spare message when message field is wrong type', () {
        final exception = BadRequestException<void>(
          responseBody: const {'message': 123},
        );

        expect(exception.message, isNotEmpty);
      });

      test('uses spare message when body is not a Map', () {
        final exception = BadRequestException<void>(
          responseBody: 'string body',
        );

        expect(exception.message, isNotEmpty);
      });
    });
  });

  group('Exceptions without body', () {
    test('FetchDataException has correct properties', () {
      final exception = FetchDataException<void>();

      expect(exception.code, isNull);
      expect(exception.responseBody, isNull);
      expect(exception.message, isNotEmpty);
    });

    test('CancelledRequestException has correct properties', () {
      final exception = CancelledRequestException<void>();

      expect(exception.code, isNull);
      expect(exception.responseBody, isNull);
      expect(exception.message, isNotEmpty);
    });

    test('RequestUnknownException has correct properties', () {
      final exception = RequestUnknownException<void>();

      expect(exception.code, isNull);
      expect(exception.responseBody, isNull);
      expect(exception.message, isNotEmpty);
    });

    test('RequestUnknownException accepts custom message', () {
      final exception = RequestUnknownException<void>(message: 'Custom error');

      expect(exception.message, equals('Custom error'));
    });
  });

  group('Exceptions with body', () {
    test('BadRequestException has status code 400', () {
      final exception = BadRequestException<void>(
        responseBody: const {'message': 'Bad request'},
      );

      expect(exception.code, equals(StatusCodes.badRequest));
      expect(exception.responseBody, isNotNull);
    });

    test('UnauthorizedException has status code 401', () {
      final exception = UnauthenticatedException<void>(
        responseBody: const {'message': 'Unauthorized'},
      );

      expect(exception.code, equals(StatusCodes.unauthenticated));
      expect(exception.responseBody, isNotNull);
    });

    test('NotFoundException has status code 404', () {
      final exception = NotFoundException<void>(
        responseBody: const {'message': 'Not found'},
      );

      expect(exception.code, equals(StatusCodes.notFound));
      expect(exception.responseBody, isNotNull);
    });

    test('ConflictException has status code 409', () {
      final exception = ConflictException<void>(
        responseBody: const {'message': 'Conflict'},
      );

      expect(exception.code, equals(StatusCodes.conflict));
      expect(exception.responseBody, isNotNull);
    });

    test('InvalidTokenException has status code 419', () {
      final exception = InvalidTokenException<void>(
        responseBody: const {'message': 'Token expired'},
      );

      expect(exception.code, equals(StatusCodes.invalidToken));
      expect(exception.responseBody, isNotNull);
    });

    test('UnProcessableDataException has status code 422', () {
      final exception = UnProcessableDataException<void>(
        responseBody: const {'message': 'Validation error'},
      );

      expect(exception.code, equals(StatusCodes.unProcessableData));
      expect(exception.responseBody, isNotNull);
    });

    test('UnProcessableDataException uses errorParser when provided', () {
      final exception = UnProcessableDataException<String>(
        responseBody: const {'message': 'Error', 'customField': 'parsed-value'},
        errorParser: (body) => body['customField'] as String,
      );

      expect(exception.data, equals('parsed-value'));
    });

    test('UnProcessableDataException ignores errorParser when '
        'body is not Map<String, dynamic>', () {
      final exception = UnProcessableDataException<String>(
        responseBody: {1: 'parsed-value'} as Map<dynamic, dynamic>,
        errorParser: (_) => 'should-not-be-called',
      );

      expect(exception.data, isNull);
    });

    test('InternalServerErrorException has status code 500', () {
      final exception = InternalServerErrorException<void>(
        responseBody: const {'message': 'Server error'},
      );

      expect(exception.code, equals(StatusCodes.serverError));
      expect(exception.responseBody, isNotNull);
    });

    test('BadResponseException has status code 500', () {
      final exception = BadResponseException<void>(
        responseBody: const {'message': 'Bad response'},
      );

      expect(exception.code, equals(StatusCodes.serverError));
      expect(exception.responseBody, isNotNull);
    });
  });
}
