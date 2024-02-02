import 'dart:io';
import 'package:http/http.dart';

import 'io.dart';

class HttpAt implements ReadAt {
  final Client client;
  final Uri url;
  final Map<String, String>? headers;

  /// Should the client be closed once the HttpAt is finished with
  final bool closeClient;

  // We are assuming the remote server supports range reads.
  const HttpAt(this.client, this.url, {this.headers, this.closeClient = false});

  @override
  Future<ByteStream> readAt(int offset, int length) async {
    try {
      final request = Request("GET", url);

      if (headers != null) request.headers.addAll(headers!);
      request.headers[HttpHeaders.rangeHeader] =
          'bytes=$offset-${offset + length - 1}';

      final response = await client.send(request);

      if (response.statusCode != 206) {
        throw HttpException('Unexpected status code: ${response.statusCode}');
      }

      final responseLength = response.headers[HttpHeaders.contentLengthHeader];
      if (responseLength != null && int.parse(responseLength) != length) {
        throw HttpException(
            'Unexpected Content-Length: $responseLength expected $length');
      }

      // TODO check Content-Range: bytes 0-1023/146515

      return response.stream;
    } catch (e) {
      if (e
          .toString()
          .contains('Error: self.XMLHttpRequest is not a constructor')) {
        // Node doesn't support the HTTP APIs
        // https://github.com/dart-lang/http/issues/1126
        //
        // I don't know a better way to detect this, then after the error has
        // happened. But hopefully this helps someone recongise what the odd
        // error.
        throw UnsupportedError('HTTP APIs are not supported for nodejs');
      }

      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (closeClient) {
      client.close();
    }
  }
}
