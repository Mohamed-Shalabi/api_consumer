/// HTTP status code constants used by the API layer.
abstract class StatusCodes {
  static const ok = 200;
  static const done = 201;
  static const badRequest = 400;
  static const unauthenticated = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const conflict = 409;
  static const badResponse = 413;
  static const invalidToken = 419;
  static const unProcessableData = 422;
  static const serverError = 500;
}
