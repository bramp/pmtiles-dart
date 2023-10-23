import 'dart:io';
import 'package:pmtiles/pmtiles.dart';

main() async {
  //final file = File('samples/trails.pmtiles');
  final file = File('samples/countries-raster.pmtiles');
  //final file = File('samples/countries.pmtiles');
  final f = await file.open(mode: FileMode.read);

  try {
    final tiles = await PmTilesArchive.from(f);
    print("Header:");
    print(await tiles.header);

    print("Metadata:");
    print("      ${await tiles.metadata}");

    print("Root:");
    print("      ${await tiles.root}");
  } finally {
    await f.close();
  }
}
