import 'package:test/test.dart';

import 'io_helpers.dart';

// Quis custodiet ipsos custodes?
void main() async {
  test('pmtilesServingToUrl', () {
    String actual = pmtilesServingToUrl(
        '2024/02/01 10:21:28 main.go:152: Serving  . on port 8080 and interface 0.0.0.0 with Access-Control-Allow-Origin:');
    expect(actual, 'http://0.0.0.0:8080');
  });
}
