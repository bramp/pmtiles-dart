import 'dart:typed_data';

extension ByteData64Ext on ByteData {
  /// Reads the 64-bit unsigned int at the specified byte offset.
  int getSafeUint64(int byteOffset, [Endian endian = Endian.big]) {
    // Use the standard function.
    return getUint64(byteOffset, endian);
  }
}
