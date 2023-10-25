import 'dart:math';

import 'package:collection/collection.dart';

import 'package:meta/meta.dart';

import 'utils.dart';

/// Simple class to hold a range of numbers
@immutable
class IntRange {
  // Inclusive
  final int begin;

  // Exclusive
  final int end;

  IntRange(this.begin, this.end) : assert(begin < end);

  /// Does this range contain this value?
  bool contains(int value) {
    return value >= begin && value < end;
  }

  /// Do these two ranges overlap?
  bool overlaps(IntRange other) {
    return contains(other.begin) || other.contains(begin);
  }

  bool adjacent(IntRange other) {
    return end == other.begin || begin == other.end;
  }

  /// Returns a new range which is the union of these two ranges.
  IntRange union(IntRange other) {
    if (!overlaps(other) && !adjacent(other)) {
      throw FormatException(
          'Ranges do not overlap and are not adjacent ($this and $other)');
    }

    return IntRange(
      min(begin, other.begin),
      max(end, other.end),
    );
  }

  /// Returns a list of non-overlapping ranges made from the union of the overlapping ranges.
  static List<IntRange> unionAll(Iterable<IntRange> ranges) {
    final newRanges = ranges.sorted((a, b) => a.end.compareTo(b.end));
    if (newRanges.length < 2) {
      return newRanges;
    }

    for (int i = newRanges.length - 1; i > 0; i--) {
      final a = newRanges[i - 1];
      final b = newRanges[i];

      if (a.overlaps(b) || a.adjacent(b)) {
        newRanges[i - 1] = a.union(b);
        newRanges.removeAt(i);
      }
    }

    return newRanges;
  }

  @override
  bool operator ==(Object other) {
    if (other is IntRange) {
      return begin == other.begin && end == other.end;
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(begin, end);

  @override
  String toString() => '[${hexPad(begin)}, ${hexPad(end)})';
}
