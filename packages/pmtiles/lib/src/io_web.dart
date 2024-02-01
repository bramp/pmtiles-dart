import 'package:http/http.dart';

import 'io.dart';

class FileAt implements ReadAt {
  FileAt(Object file) {
    throw UnimplementedError('On the web, File APIs are not implemented');
  }

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    throw UnimplementedError('On the web, File APIs are not implemented');
  }

  @override
  Future<void> close() {
    throw UnimplementedError('On the web, File APIs are not implemented');
  }
}
