/// The main entry point for the darc library.
///
/// This library provides a clean and simple API for making HTTP requests
/// using Dio, with built-in support for authentication (OAuth2),
///  error handling, and file downloads.
library;

export 'src/api_consumer.dart';
export 'src/api_error_messages.dart';
export 'src/api_error_reporter.dart';
export 'src/api_o_auth2_token.dart';
export 'src/api_result_of.dart';
export 'src/download_canceller.dart';
export 'src/impl/dio_consumer.dart';
export 'src/impl/dio_download_canceller.dart';
export 'src/multi_part_file_model.dart';
export 'src/request_exceptions.dart';
