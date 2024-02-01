import 'package:http/http.dart';
import 'package:pmtiles/pmtiles.dart';

/// Wrapper for a ReadAt, that counts how many requests/bytes are read.
class CountingReadAt implements ReadAt {
  final ReadAt _inner;
  int requests = 0;
  int bytes = 0;

  CountingReadAt(this._inner);

  @override
  Future<void> close() {
    return _inner.close();
  }

  @override
  Future<ByteStream> readAt(int offset, int length) {
    requests++;
    bytes += length;
    return _inner.readAt(offset, length);
  }

  void reset() {
    requests = 0;
    bytes = 0;
  }
}
