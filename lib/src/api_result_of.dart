import 'dart:async';
import 'package:darc/src/request_exceptions.dart';
import 'package:fpdart/fpdart.dart';

/// Type alias for API operation results using the Either pattern.
///
/// Left side is a [RequestException] (error case), right side is the
/// parsed success data of type `T`.
typedef ApiResultOf<E, T> = Future<Either<RequestException<E>, T>>;
