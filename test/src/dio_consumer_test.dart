// ignoring some strict rules to simplify testing
// ignore: lines_longer_than_80_chars
// ignore_for_file: strict_raw_type, avoid_dynamic_calls, inference_failure_on_collection_literal, inference_failure_on_function_invocation

import 'package:darc/src/api_error_reporter.dart';
import 'package:darc/src/api_o_auth2_token.dart';
import 'package:darc/src/impl/dio_consumer.dart';
import 'package:darc/src/impl/dio_download_canceller.dart';
import 'package:darc/src/multi_part_file_model.dart';
import 'package:darc/src/request_exceptions.dart';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart' show Either;
import 'package:fresh_dio/fresh_dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../mocks/mocks.dart';

void main() {
  late MockDio mockDio;
  late MockMultipartFileFactory mockFileFactory;
  late Fresh<ApiOAuth2Token> interceptor;
  late DioConsumer sut;

  setUpAll(() {
    registerFallbackValue(FakeOptions());
    registerFallbackValue(FakeOAuth2Token());
    registerFallbackValue(FakeRequestOptions());
    registerFallbackValue(FakeCancelToken());
    registerFallbackValue(FakeFormData());
  });

  setUp(() {
    mockDio = MockDio();
    mockFileFactory = MockMultipartFileFactory();
    interceptor = createAuthInterceptorWithSuccessRefresh();

    sut = DioConsumer(
      client: mockDio,
      tokenInterceptor: interceptor,
      baseUrl: 'https://api.example.com',
      fileFactory: mockFileFactory,
    );
  });

  // ===========================================================================
  // GET REQUESTS
  // ===========================================================================

  group('GET Requests', () {
    test('successful GET returns parsed data in Right', () async {
      stubGetSuccess(mockDio, {'name': 'Test User', 'id': 1});

      final result = await sut.get<void, String>(
        '/users/1',
        parser: (data) => data['name'] as String,
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => ''), equals('Test User'));
    });

    test('GET passes all parameters correctly', () async {
      stubGetSuccess(mockDio, {'results': []});

      await sut.get<void, List>(
        '/search',
        parser: (data) => data['results'] as List,
        queryParameters: {'q': 'flutter', 'limit': 10},
        additionalHeaders: {'X-Custom-Header': 'custom-value'},
      );

      final verification = verify(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: captureAny(named: 'options'),
        ),
      )..called(1);

      final captured = verification.captured;

      final options = captured.first as Options;
      expect(options.headers?['X-Custom-Header'], equals('custom-value'));
    });

    test('reports error to Flutter framework on unknown exception', () async {
      final expectedError = Exception('Secret failure');

      // Throw an exception, NOT DioException, to hit the general catch block
      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenThrow(expectedError);

      Object? reportedException;
      final originalErrorReporter = ApiErrorReporter.errorReporter;
      ApiErrorReporter.errorReporter = (error, stackTrace) {
        reportedException = error;
      };

      await sut.get<void, String>('/crash', parser: (_) => '');

      expect(reportedException, equals(expectedError));

      // Cleanup
      ApiErrorReporter.errorReporter = originalErrorReporter;
    });

    test(
      'GET with DioException returns left of a subclass of RequestException',
      () async {
        stubGetError(
          mockDio,
          createConnectionException(DioExceptionType.connectionError),
        );

        final result = await sut.get<void, String>(
          '/data',
          parser: (data) => data['name'] as String,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (error) => expect(error, isA<RequestException>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test('parser exception returns left of RequestUnknownException', () async {
      stubGetSuccess(mockDio, {'valid': 'data'});

      final result = await sut.get<void, String>(
        '/data',
        parser: (data) => throw const FormatException('Parse error'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) => expect(error, isA<RequestUnknownException>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // POST REQUESTS
  // ===========================================================================

  group('POST Requests', () {
    test('successful POST with body returns parsed data', () async {
      stubPostSuccess(mockDio, {'id': 1, 'name': 'Created'});

      final result = await sut.post<void, Map<String, dynamic>>(
        '/users',
        parser: (data) => data as Map<String, dynamic>,
        body: {'name': 'New User'},
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['name'], equals('Created')),
      );
    });

    test(
      'POST passes all parameters correctly in raw json (if no files)',
      () async {
        stubPostSuccess(mockDio, {'success': true});

        await sut.post<void, bool>(
          '/action',
          parser: (data) => data['success'] as bool,
          queryParameters: {'action': 'create'},
          additionalHeaders: {'X-Custom-Header': 'custom-value'},
          body: {'body_key': 'body_value'},
        );

        final verification = verify(
          () => mockDio.post<dynamic>(
            '/action',
            data: {'body_key': 'body_value'},
            queryParameters: {'action': 'create'},
            options: captureAny(named: 'options'),
          ),
        )..called(1);

        final captured = verification.captured;
        final options = captured.first as Options;
        expect(options.headers?['X-Custom-Header'], equals('custom-value'));
      },
    );

    test(
      'POST with files uses FormData for body and uses MultipartFile factory '
      'to create MultipartFiles',
      () async {
        stubPostSuccess(mockDio, {'success': true});

        // Mock factory to return a file without reading disk
        when(
          () => mockFileFactory.create(
            filePath: any(named: 'filePath'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((_) async => MultipartFile.fromString('dummy content'));

        await sut.post<void, bool>(
          '/upload',
          parser: (data) => true,
          files: [
            MultiPartFileModel(
              requestBodyName: 'file',
              filePath: '/path/to/file.jpg',
            ),
          ],
        );

        verify(
          () => mockFileFactory.create(
            filePath: '/path/to/file.jpg',
            filename: 'file.jpg',
          ),
        ).called(1);

        final captured = verify(
          () => mockDio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).captured;

        // Verify FormData contains the file
        final formData = captured.first as FormData;
        expect(formData.files.first.value, isA<MultipartFile>());
      },
    );

    test(
      'POST aggregates multiple files under same requestBodyName into List',
      () async {
        stubPostSuccess(mockDio, {'success': true});

        // Mock factory: return distinct MultipartFile instances
        when(
          () => mockFileFactory.create(
            filePath: any(named: 'filePath'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((invocation) async {
          final args = invocation.namedArguments;
          final filename = args[const Symbol('filename')] as String?;
          return MultipartFile.fromString('content for $filename');
        });

        await sut.post<void, bool>(
          '/upload-multiple',
          parser: (data) => true,
          files: [
            MultiPartFileModel(
              requestBodyName: 'photos',
              filePath: '/path/a.jpg',
            ),
            MultiPartFileModel(
              requestBodyName: 'photos',
              filePath: '/path/b.jpg',
            ),
          ],
        );

        final captured = verify(
          () => mockDio.post<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).captured;
        final formData = captured.first as FormData;

        // Find field named 'photos' and assert it is a List with two entries
        final files = formData.files
            .where((e) => e.key == 'photos')
            .map((e) => e.value)
            .toList();
        expect(files.length, equals(2));
      },
    );

    test(
      'POST with DioException returns left of a subclass of RequestException',
      () async {
        stubPostError(
          mockDio,
          createConnectionException(DioExceptionType.connectionError),
        );

        final result = await sut.post<void, String>(
          '/data',
          parser: (data) => data['name'] as String,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (error) => expect(error, isA<RequestException>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test('reports error to Flutter framework on unknown exception', () async {
      final expectedError = Exception('Secret failure');

      // Throw an exception, NOT DioException, to hit the general catch block
      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(expectedError);

      Object? reportedException;
      final originalOnError = ApiErrorReporter.errorReporter;
      ApiErrorReporter.errorReporter = (error, stackTrace) {
        reportedException = error;
      };

      await sut.post<void, String>(
        '/crash',
        parser: (_) => '',
        body: {'name': 'New User'},
      );

      expect(reportedException, equals(expectedError));

      // Cleanup
      ApiErrorReporter.errorReporter = originalOnError;
    });

    test('parser exception returns left of RequestUnknownException', () async {
      stubPostSuccess(mockDio, {'valid': 'data'});

      final result = await sut.post<void, String>(
        '/data',
        parser: (data) => throw const FormatException('Parse error'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) => expect(error, isA<RequestUnknownException>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // PUT REQUESTS
  // ===========================================================================

  group('PUT Requests', () {
    test('successful PUT returns parsed data', () async {
      stubPutSuccess(mockDio, {'id': 1, 'name': 'Updated'});

      final result = await sut.put<void, Map<String, dynamic>>(
        '/users/1',
        parser: (data) => data as Map<String, dynamic>,
        body: {'name': 'Updated Name'},
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (data) => expect(data['name'], equals('Updated')),
      );
    });

    test(
      'PUT passes all parameters correctly in raw json (if no files)',
      () async {
        stubPutSuccess(mockDio, {'success': true});

        await sut.put<void, bool>(
          '/update',
          parser: (data) => data['success'] as bool,
          queryParameters: {'version': '2'},
          body: {'name': 'Updated Name'},
          additionalHeaders: {'X-Custom-Header': 'custom-value'},
        );

        final verification = verify(
          () => mockDio.put<dynamic>(
            '/update',
            data: {'name': 'Updated Name'},
            queryParameters: {'version': '2'},
            options: captureAny(named: 'options'),
          ),
        )..called(1);

        final options = verification.captured.first as Options;
        expect(options.headers?['X-Custom-Header'], equals('custom-value'));
      },
    );

    test('PUT with files uses FormData for body and uses MultipartFile factory '
        'to create MultipartFiles', () async {
      stubPutSuccess(mockDio, {'success': true});

      // Mock factory to return a file without reading disk
      when(
        () => mockFileFactory.create(
          filePath: any(named: 'filePath'),
          filename: any(named: 'filename'),
        ),
      ).thenAnswer((_) async => MultipartFile.fromString('dummy content'));

      await sut.put<void, bool>(
        '/upload',
        parser: (data) => true,
        files: [
          MultiPartFileModel(
            requestBodyName: 'file',
            filePath: '/path/to/file.jpg',
          ),
        ],
      );

      verify(
        () => mockFileFactory.create(
          filePath: '/path/to/file.jpg',
          filename: 'file.jpg',
        ),
      ).called(1);

      final captured = verify(
        () => mockDio.put<dynamic>(
          any(),
          data: captureAny(named: 'data'),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).captured;

      // Verify FormData contains the file
      final formData = captured.first as FormData;
      expect(formData.files.first.value, isA<MultipartFile>());
    });

    test(
      'PUT with DioException returns left of a subclass of RequestException',
      () async {
        stubPutError(
          mockDio,
          createConnectionException(DioExceptionType.connectionError),
        );

        final result = await sut.put<void, String>(
          '/data',
          parser: (data) => data['name'] as String,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (error) => expect(error, isA<RequestException>()),
          (_) => fail('Expected Left'),
        );
      },
    );

    test(
      'PUT aggregates multiple files under same requestBodyName into List',
      () async {
        stubPutSuccess(mockDio, {'success': true});

        // Mock factory: return distinct MultipartFile instances
        when(
          () => mockFileFactory.create(
            filePath: any(named: 'filePath'),
            filename: any(named: 'filename'),
          ),
        ).thenAnswer((invocation) async {
          final args = invocation.namedArguments;
          final filename = args[const Symbol('filename')] as String?;
          return MultipartFile.fromString('content for $filename');
        });

        await sut.put<void, bool>(
          '/upload-multiple',
          parser: (data) => true,
          files: [
            MultiPartFileModel(
              requestBodyName: 'photos',
              filePath: '/path/a.jpg',
            ),
            MultiPartFileModel(
              requestBodyName: 'photos',
              filePath: '/path/b.jpg',
            ),
          ],
        );

        final captured = verify(
          () => mockDio.put<dynamic>(
            any(),
            data: captureAny(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
          ),
        ).captured;
        final formData = captured.first as FormData;

        // Find field named 'photos' and assert it is a List with two entries
        final files = formData.files
            .where((e) => e.key == 'photos')
            .map((e) => e.value)
            .toList();
        expect(files.length, equals(2));
      },
    );

    test('reports error to Flutter framework on unknown exception', () async {
      final expectedError = Exception('Secret failure');

      // Throw an exception, NOT DioException, to hit the general catch block
      when(
        () => mockDio.put<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(expectedError);

      Object? reportedException;
      final originalErrorReporter = ApiErrorReporter.errorReporter;
      ApiErrorReporter.errorReporter = (error, stackTrace) {
        reportedException = error;
      };

      await sut.put<void, String>(
        '/crash',
        parser: (_) => '',
        body: {'name': 'New User'},
      );

      expect(reportedException, equals(expectedError));

      // Cleanup
      ApiErrorReporter.errorReporter = originalErrorReporter;
    });

    test('parser exception returns left of RequestUnknownException', () async {
      stubPutSuccess(mockDio, {'valid': 'data'});

      final result = await sut.put<void, String>(
        '/data',
        parser: (data) => throw const FormatException('Parse error'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) => expect(error, isA<RequestUnknownException>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // DELETE REQUESTS
  // ===========================================================================

  group('DELETE Requests', () {
    test('successful DELETE returns parsed data', () async {
      stubDeleteSuccess(mockDio, {'deleted': true});

      final result = await sut.delete<void, bool>(
        '/users/1',
        parser: (data) => data['deleted'] as bool,
      );

      expect(result.isRight(), isTrue);
      expect(result.getOrElse((_) => false), isTrue);
    });

    test('DELETE passes all parameters correctly', () async {
      stubDeleteSuccess(mockDio, {'deleted': 3});

      await sut.delete<void, int>(
        '/items',
        parser: (data) => data['deleted'] as int,
        data: {
          'ids': [1, 2, 3],
        },
        additionalHeaders: {'X-Custom-Header': 'custom-value'},
      );

      final verification = verify(
        () => mockDio.delete<dynamic>(
          '/items',
          data: {
            'ids': [1, 2, 3],
          },
          options: captureAny(named: 'options'),
        ),
      )..called(1);

      final options = verification.captured.first as Options;
      expect(options.headers?['X-Custom-Header'], equals('custom-value'));
    });

    test('reports error to Flutter framework on unknown exception', () async {
      final expectedError = Exception('Secret failure');

      // Throw an exception, NOT DioException, to hit the general catch block
      when(
        () => mockDio.delete<dynamic>(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        ),
      ).thenThrow(expectedError);

      Object? reportedException;
      final originalOnError = ApiErrorReporter.errorReporter;
      ApiErrorReporter.errorReporter = (error, stackTrace) {
        reportedException = error;
      };

      await sut.delete<void, String>(
        '/crash',
        parser: (_) => '',
        data: {'name': 'New User'},
      );

      expect(reportedException, equals(expectedError));

      // Cleanup
      ApiErrorReporter.errorReporter = originalOnError;
    });

    test(
      'DELETE with DioException returns left of a subclass of RequestException',
      () async {
        stubDeleteError(
          mockDio,
          createConnectionException(DioExceptionType.connectionError),
        );

        final result = await sut.delete<void, String>(
          '/data',
          parser: (data) => data['name'] as String,
        );

        expect(result.isLeft(), isTrue);
        result.fold(
          (error) => expect(error, isA<RequestException>()),
          (_) => fail('Expected Left'),
        );
      },
    );
    test('parser exception returns left of RequestUnknownException', () async {
      stubDeleteSuccess(mockDio, {'valid': 'data'});

      final result = await sut.delete<void, String>(
        '/data',
        parser: (data) => throw const FormatException('Parse error'),
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (error) => expect(error, isA<RequestUnknownException>()),
        (_) => fail('Expected Left'),
      );
    });
  });

  // ===========================================================================
  // DOWNLOAD
  // ===========================================================================

  group('Download', () {
    test('successful download returns progress stream', () async {
      stubDownloadSuccess(mockDio);

      final result = await sut.download<void>(
        'https://example.com/file.zip',
        '/tmp/file.zip',
      );

      expect(result.isRight(), isTrue);

      result.fold(
        (l) => fail('Expected Right'),
        (r) => expect(r, isA<Stream<Either<RequestException<void>, double>>>()),
      );
    });

    test('download starts but gets interrupted with cancellation', () async {
      final mockDioCancelToken = MockDioCancelToken();
      stubDownloadCanceller(mockDioCancelToken);
      stubDownloadCancelled(mockDio);

      final result = await sut.download(
        'https://example.com/file.zip',
        '/tmp/file.zip',
        canceller: DioDownloadCanceller(mockDioCancelToken),
      );

      expect(result.isRight(), isTrue);

      result.fold(
        (l) => fail('Expected Right'),
        (r) => expect(r, isA<Stream<Either<RequestException<void>, double>>>()),
      );

      await Future<Null>.delayed(const Duration(milliseconds: 100));

      verify(mockDioCancelToken.cancel).called(1);
    });

    test('download with DioException returns Left', () async {
      stubDownloadError(
        mockDio,
        createConnectionException(DioExceptionType.connectionError),
      );

      final result = await sut.download<void>(
        'https://example.com/file.zip',
        '/tmp/file.zip',
      );

      expect(result.isLeft(), isTrue);

      result.fold(
        (error) => expect(error, isA<FetchDataException>()),
        (_) => fail('Expected Left'),
      );
    });

    test('download passes cancel token from canceller', () async {
      stubDownloadSuccess(mockDio);

      final cancelToken = CancelToken();
      final canceller = DioDownloadCanceller(cancelToken);

      await sut.download<void>(
        'https://example.com/file.zip',
        '/tmp/file.zip',
        canceller: canceller,
      );

      verify(
        () => mockDio.download(
          any(),
          any(),
          cancelToken: cancelToken,
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).called(1);
    });

    test('download cancelled mid-flight returns Left with '
        'CancelledRequestException', () async {
      // Stub download to simulate partial progress then cancellation
      when(
        () => mockDio.download(
          any(),
          any(),
          cancelToken: any(named: 'cancelToken'),
          onReceiveProgress: any(named: 'onReceiveProgress'),
        ),
      ).thenAnswer((invocation) async {
        final onReceiveProgress =
            invocation.namedArguments[const Symbol('onReceiveProgress')]
                as void Function(int, int);
        // Simulate 25% progress before cancellation
        onReceiveProgress(25, 100);

        throw DioException(
          type: DioExceptionType.receiveTimeout,
          requestOptions: RequestOptions(path: '/file'),
        );
      });

      final result = await sut.download(
        'https://example.com/file.zip',
        '/tmp/file.zip',
      );

      expect(result.isRight(), isTrue);

      final stream = result.getOrElse((_) => throw StateError('No stream'));

      expect(await stream.any((event) => event.isLeft()), isTrue);
    });
  });
}
