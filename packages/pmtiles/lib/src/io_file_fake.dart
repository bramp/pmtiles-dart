import 'package:http/http.dart';

import 'io.dart';

class FileAt implements ReadAt {
  FileAt(Object file) {
    throw UnimplementedError('File APIs are not implemented on the web');
  }

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    throw UnimplementedError('File APIs are not implemented on the web');
  }

  @override
  Future<void> close() {
    throw UnimplementedError('File APIs are not implemented on the web');
  }
}
