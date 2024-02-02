import 'package:http/http.dart';

import 'io.dart';

class FileAt implements ReadAt {
  FileAt(Object file) {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }

  @override
  Future<void> close() {
    throw UnsupportedError('File APIs are not supported for dart2js');
  }
}
