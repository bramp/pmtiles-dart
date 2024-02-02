import 'package:http/http.dart';

import 'io.dart';

class HttpAt implements ReadAt {
  HttpAt(Object client, Uri url,
      {Map<String, String>? headers, bool closeClient = false}) {
    throw UnsupportedError('HTTP APIs are not supported for nodejs');
  }

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    throw UnsupportedError('HTTP APIs are not supported for nodejs');
  }

  @override
  Future<void> close() {
    throw UnsupportedError('HTTP APIs are not supported for nodejs');
  }
}
