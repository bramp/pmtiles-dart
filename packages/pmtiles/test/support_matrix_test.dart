import 'dart:io';

import 'package:pmtiles/src/io.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('File API is available', () {
    expect(() => FileAt(File('/tmp/blah')), returnsNormally);
  }, testOn: '!js');

  test('File API is not available', () {
    expect(() => FileAt(File('/tmp/blah')), throwsUnsupportedError);
  }, testOn: 'js');

  test('HTTP API is available', () {
    final client = http.Client();
    expect(() => HttpAt(client, Uri.parse("http://localhost/")).readAt(0, 1),
        returnsNormally);
  }, testOn: '!node');

  test('HTTP API is not available', () {
    final client = http.Client();
    expect(() => HttpAt(client, Uri.parse("http://localhost/")).readAt(0, 1),
        throwsUnsupportedError);
  }, testOn: 'node');
}
