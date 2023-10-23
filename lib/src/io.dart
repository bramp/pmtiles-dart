import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Simple interface so we can abstract reading from Files, or Http.
abstract interface class ReadAt {
  /// Read [length] bytes from [offset].
  Future<Uint8List> readAt(int offset, int length);

  /// Close any resources.
  Future<void> close();
}

class RandomAccessFileAt implements ReadAt {
  final RandomAccessFile file;

  RandomAccessFileAt(this.file);

  @override
  Future<Uint8List> readAt(int offset, int length) async {
    return (await file.setPosition(offset)).read(length);
  }

  @override
  Future<void> close() {
    return file.close();
  }
}

class HttpAt implements ReadAt {
  final http.Client client;
  final Uri url;
  final Map<String, String>? headers;

  // We are assuming the remote server supports range reads.
  HttpAt(this.client, this.url, {this.headers});

  @override
  Future<Uint8List> readAt(int offset, int length) async {
    final response = await client.get(url, headers: {
      if (headers != null) ...headers!,
      HttpHeaders.rangeHeader: 'bytes=$offset-${offset + length - 1}',
    });

    if (response.statusCode != 206) {
      throw Exception('Unexpected status code: ${response.statusCode}');
    }

    final responseLength = response.headers[HttpHeaders.contentLengthHeader];
    if (responseLength != null && int.parse(responseLength) != length) {
      throw Exception(
          'Unexpected Content-Length: $responseLength expected $length');
    }

    // TODO check Content-Range: bytes 0-1023/146515

    return response.bodyBytes;
  }

  @override
  Future<void> close() async {
    return client.close();
  }
}
