import 'dart:async';
import 'package:darc/src/download_canceller.dart';
import 'package:dio/dio.dart';

/// Dio-specific implementation of [DownloadCanceller] using [CancelToken].
class DioDownloadCanceller extends DownloadCanceller {
  /// Creates a canceller backed by the provided Dio [CancelToken].
  DioDownloadCanceller(this.cancelToken);
  final CancelToken cancelToken;

  @override
  Future<void> cancel() async {
    cancelToken.cancel();
  }
}
