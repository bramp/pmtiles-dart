import 'dart:io'; // TODO Remove this

import 'package:http/http.dart';

import 'io.dart';

class HttpAt implements ReadAt {
  final Client client;
  final Uri url;
  final Map<String, String>? headers;

  // We are assuming the remote server supports range reads.
  HttpAt(this.client, this.url, {this.headers});

  @override
  Future<ByteStream> readAt(int offset, int length) async {
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
  }

  @override
  Future<void> close() async {
    return client.close();
  }
}
