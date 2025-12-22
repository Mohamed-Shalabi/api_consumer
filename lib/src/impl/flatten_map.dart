part of 'dio_consumer.dart';

@visibleForTesting
Map<String, dynamic> flattenMap(
  String prefix,
  Map<String, dynamic> map,
  Map<String, dynamic> formData,
) {
  var result = formData;
  map.forEach((key, value) {
    final newKey = prefix.isEmpty ? key : '$prefix[$key]';
    if (value is Map<String, dynamic>) {
      result = flattenMap(newKey, value, result);
    } else if (value is List) {
      for (var i = 0; i < value.length; i++) {
        result = flattenMap(newKey, {i.toString(): value[i]}, result);
      }
    } else {
      if (value != null) {
        result[newKey] = value.toString();
      }
    }
  });

  return result;
}
