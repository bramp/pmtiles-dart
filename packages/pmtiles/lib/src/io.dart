import 'dart:collection';
import 'dart:math' as math;
import 'package:http/http.dart';

// Browsers don't support the File APIs
export 'io_file.dart' if (dart.library.browser) 'io_file_fake.dart';

// Node doesn't support the HTTP APIs
// https://github.com/dart-lang/http/issues/1126
export 'io_http.dart' if (dart.library.node) 'io_http_fake.dart';

/// Simple interface so we can abstract reading from Files, or Http.
abstract interface class ReadAt {
  /// Read [length] bytes from [offset].
  ///
  /// If offset+length is beyond the end of the file as many bytes as possible
  /// are returned.
  // TODO Test the edge case behaviours.
  Future<ByteStream> readAt(int offset, int length);

  /// Close any resources.
  Future<void> close();
}

/// An List<int> that is made up of a List of List<int>.
class CordBuffer {
  final _buffers = Queue<List<int>>();

  /// Offset into current buffer, if its been partially read.
  int _offset = 0;

  void addAll(List<int> buffer) {
    _buffers.add(buffer);
  }

  bool get isEmpty {
    return _buffers.isEmpty;
  }

  int get length {
    return _buffers.fold(0, (int sum, List<int> buffer) {
          return sum + buffer.length;
        }) -
        _offset;
  }

  void removeRange(int start, int end) {
    assert(start == 0, "Sorry only zero is supported");
    assert(start <= end);
    assert(end <= length);

    var remaining = end;
    while (remaining > 0 && _buffers.isNotEmpty) {
      final buffer = _buffers.first;

      // Remove the whole buffer
      if (remaining > (buffer.length - _offset)) {
        _buffers.removeFirst();
        remaining -= (buffer.length - _offset);
        _offset = 0;
        continue;
      }

      // Remove part of the buffer
      _offset += remaining;
      remaining -= remaining;
    }

    assert(remaining == 0,
        "Should have removed all the data, but $remaining remain");
  }

  Iterable<int> getRange(int start, int end) {
    // TODO This is making a copy. We could write our own loop, and return
    // a view of the data.
    return _buffers
        .expand((buffer) => buffer)
        .skip(_offset + start)
        .take(end - start);
  }

  List<int> toList({bool growable = true}) {
    return _buffers
        .expand((buffer) => buffer)
        .skip(_offset)
        .toList(growable: growable);
  }
}

/// In memory implementation of ReadAt.
class MemoryAt implements ReadAt {
  final List<int> bytes;

  MemoryAt(this.bytes);

  @override
  Future<ByteStream> readAt(int offset, int length) async {
    if (offset >= bytes.length) {
      return ByteStream.fromBytes([]);
    }

    return ByteStream.fromBytes(
      bytes.sublist(offset, math.min(bytes.length, offset + length)),
    );
  }

  @override
  Future<void> close() async {
    // Does nothing.
  }
}
