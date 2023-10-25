import 'dart:collection';
import 'dart:io';

import 'package:http/http.dart';
import 'package:pool/pool.dart';

/// Simple interface so we can abstract reading from Files, or Http.
abstract interface class ReadAt {
  /// Read [length] bytes from [offset].
  Future<ByteStream> readAt(int offset, int length);

  /// Close any resources.
  Future<void> close();
}

class FileAt implements ReadAt {
  final File file;

  /// RandomAccessFile only allows a single outstanding read at any time, so
  /// we open a new RandomAccessFile for each read. To bound the number
  /// we use a pool to cap us to 8 outstanding reads.
  final _pool = Pool(8, timeout: Duration(seconds: 30));

  FileAt(this.file);

  @override
  Future<ByteStream> readAt(final int offset, final int length) async {
    return _pool.withResource(() async {
      // TODO Consider caching the open files.
      final file = await this.file.open(mode: FileMode.read);
      try {
        final f = await file.setPosition(offset);
        final data = await f.read(length);

        return ByteStream.fromBytes(data);
      } finally {
        await file.close();
      }
    });
  }

  @override
  Future<void> close() {
    return _pool.close();
  }
}

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
