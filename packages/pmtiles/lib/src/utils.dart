/// Convert the number to a 8 character wide zero padded hex number.
String hexPad(int x) {
  return x.toRadixString(16).padLeft(8, '0');
}
