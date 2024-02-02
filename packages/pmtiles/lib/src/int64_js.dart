import 'dart:typed_data';

import 'package:fixnum/fixnum.dart';

extension ByteData64Ext on ByteData {
  /// Reads the 64-bit unsigned int at the specified byte offset.
  ///
  /// The standard ByteData API just throws an exception if you try to read
  /// 64bits on dart2js, so we use fixnum to read the int, and then convert it
  /// best it can to a dart int. However, it still can't support values above
  /// 2^53, so we throw a UnsupportedError exception if the value is too large.
  int getSafeUint64(int byteOffset, [Endian endian = Endian.big]) {
    final bytes = buffer.asUint8List(byteOffset, 8);

    if (endian == Endian.big) {
      if (bytes[0] > 0 || bytes[1] > 0x20) {
        // Then this number is greater than 53 bits.
        throw UnsupportedError("dart2js doesn't support ints larger than 2^53");
      }

      return Int64.fromBytesBigEndian(bytes).toInt();
    } else {
      if (bytes[7] > 0 || bytes[6] > 0x20) {
        // Then this number is greater than 53 bits.
        throw UnsupportedError("dart2js doesn't support ints larger than 2^53");
      }

      return Int64.fromBytes(bytes).toInt();
    }
  }
}
