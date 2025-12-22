import 'package:path/path.dart' as path;

/// Represents a file to be uploaded as multipart form data.
class MultiPartFileModel {
  /// Creates a model for a file named by [requestBodyName] at [filePath].
  ///
  /// The [fileName] is automatically derived from [filePath].
  MultiPartFileModel({required this.requestBodyName, required this.filePath})
    : fileName = path.basename(filePath);

  /// The form field name that should contain this file.
  final String requestBodyName;

  /// The file name (basename of [filePath]) sent to the server.
  final String fileName;

  /// Absolute or relative path to the file on disk.
  final String filePath;
}
