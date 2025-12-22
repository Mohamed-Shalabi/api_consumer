import 'dart:async';

/// Abstraction for canceling an in-flight download operation.
abstract class DownloadCanceller {
  /// Requests cancellation of the associated download.
  Future<void> cancel();
}
