/// The error messages used for mapping API errors to user-friendly strings.
final class ApiErrorMessages {
  ApiErrorMessages({
    required this.connectionError,
    required this.downloadCanceled,
    required this.unknownError,
    required this.pleaseLogin,
    required this.wrongData,
    required this.serverError,
    required this.unauthorized,
  });

  ApiErrorMessages.defaults()
      : this(
          connectionError: () => 'Connection error',
          downloadCanceled: () => 'Download canceled',
          unknownError: () => 'Unknown error',
          pleaseLogin: () => 'Please login',
          wrongData: () => 'Wrong data',
          serverError: () => 'Server error',
          unauthorized: () => 'Unauthorized',
        );

  final String Function() connectionError;
  final String Function() downloadCanceled;
  final String Function() unknownError;
  final String Function() pleaseLogin;
  final String Function() wrongData;
  final String Function() serverError;
  final String Function() unauthorized;

  static ApiErrorMessages instance = ApiErrorMessages.defaults();
}
