import 'dart:io';

import 'package:pmtiles/src/io.dart';
import 'package:test/test.dart';

void main() {
  test('File API is available', () {
    expect(() => FileAt(File('/tmp/blah')), returnsNormally);
  }, testOn: '!js');

  test('File API is not available', () {
    expect(() => FileAt(File('/tmp/blah')), throwsUnsupportedError);
  }, testOn: 'js');
}
