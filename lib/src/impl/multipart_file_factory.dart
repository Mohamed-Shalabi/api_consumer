part of 'dio_consumer.dart';

/// abstract factory to allow mocking of MultipartFile creation
@visibleForTesting
abstract class MultipartFileFactory {
  Future<MultipartFile> create({required String filePath, String? filename});
}

@visibleForTesting
class DefaultMultipartFileFactory implements MultipartFileFactory {
  @override
  Future<MultipartFile> create({required String filePath, String? filename}) =>
      MultipartFile.fromFile(filePath, filename: filename);
}
