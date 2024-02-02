import 'dart:collection';
import 'dart:math' as math;
import 'package:http/http.dart';

export 'js/io_file.dart' //
    if (dart.library.io) 'native/io_file.dart'; // JS don't support the File APIs

export 'io_http.dart';

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

/// An List<int> that is made up internally of a List of List<int>.
// TODO Merge sublist and removeRange. Both are always called at the
// same time, so we can do it in one pass.
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
    assert(start == 0, 'Sorry only zero is supported');
    assert(start <= end);
    assert(end <= length);

    int remaining = end;
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
        'Should have removed all the data, but $remaining remain');
  }

  /// Returns a single sublist made up of a copy of the data in the buffers.
  List<int> sublist(final int start, final int end) {
    assert(start == 0, 'Sorry only zero is supported');
    assert(start <= end);
    assert(end <= length);

    final result = List<int>.empty(growable: true);
    int remaining = end - start;

    final b = _buffers.iterator;
    int offset = _offset;

    while (b.moveNext()) {
      final remainingInBuffer = b.current.length - offset;
      final toCopy = math.min(remainingInBuffer, remaining);

      result.addAll(b.current.sublist(offset, offset + toCopy));

      offset = 0;
      remaining -= toCopy;

      if (remaining == 0) {
        break;
      }
    }

    assert(remaining == 0,
        'Should have removed all the data, but $remaining remain');
    assert(result.length == end - start,
        'Results length is wrong ${result.length} != ${end - start}');

    return result;
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
