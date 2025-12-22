import 'dart:developer' as developer;

import 'package:meta/meta.dart';

abstract final class ApiErrorReporter {
  static void _defaultErrorReporter(Object error, StackTrace stackTrace) {
    developer.log(
      'Unhandled exception',
      name: 'darc',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void Function(Object error, StackTrace stackTrace) errorReporter =
      _defaultErrorReporter;

  @internal
  static void reportError(Object error, StackTrace stackTrace) {
    errorReporter(error, stackTrace);
  }
}
