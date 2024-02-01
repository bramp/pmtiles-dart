import 'dart:io';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:pmtiles/src/archive.dart';
import 'package:test/test.dart';

/// Simple archive tests. More comprehensive tests are in the pmtiles_tests
/// package.
void main() {
  group('http', () {
    test('Connection Refused', () async {
      try {
        final tiles =
            await PmTilesArchive.fromUri(Uri.parse('http://localhost:1234'));
        tiles.close();
      } on ClientException catch (e) {
        expect(
            e.message,
            anyOf(
              contains('Connection refused'),

              // In the browser, a "ClientException: XMLHttpRequest error" is
              // thrown which doesn't tell us the error :(
              contains('XMLHttpRequest error'),
            ));
        return;
      }

      fail('Expected ClientException');
    }, testOn: "!node");

    test('404 Not Found', () async {
      var client = MockClient((request) async {
        return Response("", 404);
      });

      try {
        final tiles = await PmTilesArchive.fromUri(
          Uri.parse('http://localhost:1234'),
          client: client,
        );
        tiles.close();
      } on HttpException catch (e) {
        expect(e.message, contains('404'));
        return;
      }

      fail('Expected HttpException');
    });
  });

  group('file', () {
    test('not found', () async {
      try {
        final tiles = await PmTilesArchive.fromFile(File("not-found"));
        tiles.close();
      } on PathNotFoundException catch (e) {
        expect(e.message, contains('Cannot open file'));
        return;
      }

      fail('Expected PathNotFoundException');
    });
  }, testOn: "!browser");
}
