import 'package:darc/src/impl/dio_consumer.dart';
import 'package:test/test.dart';

void main() {
  test(
    'flattenMap flattens nested maps and lists in FormData correctly',
    () async {
      final nestedBody = {
        'user': {
          'name': 'Mohamed',
          'details': {'age': 30},
        },
        'tags': ['a', 'b'],
        'items': [
          {'id': 1},
          {'id': 2},
        ],
      };

      final result = flattenMap('', nestedBody, {});

      // Verify flattened fields
      // user[name] -> Mohamed
      expect(result['user[name]'], 'Mohamed');
      // user[details][age] -> 30
      expect(result['user[details][age]'], '30');
      // tags[0] -> a
      expect(result['tags[0]'], 'a');
      // tags[1] -> a
      expect(result['tags[1]'], 'b');
      // items[0][id] -> 1
      expect(result['items[0][id]'], '1');
      // items[1][id] -> 2
      expect(result['items[1][id]'], '2');
    },
  );
}
