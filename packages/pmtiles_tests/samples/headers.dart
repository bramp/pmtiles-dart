/// The headers from each sample file, formatted in the Header.toString() format.
// TODO Consider turning this into a more sensible encoding, e.g JSON.
const sampleHeaders = <String, String>{
  'countries-leaf.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 30,
    metadataOffset: 157,
    metadataLength: 463,
    leafDirectoriesOffset: 620,
    leafDirectoriesLength: 8388,
    tileDataOffset: 9008,
    tileDataLength: 7910833,
    numberOfAddressedTiles: 4099,
    numberOfTileEntries: 3963,
    numberOfTileContents: 3474,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.gzip,
    tileType: TileType.mvt,
    minZoom: 0,
    maxZoom: 6,
    minPosition: LatLng(latitude:-85.0, longitude:-180.0),
    maxPosition: LatLng(latitude:85.0, longitude:180.0),
    centerZoom: 0,
    centerPosition: LatLng(latitude:7.0137, longitude:0.0),
''',
  'countries-leafs.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 145,
    metadataOffset: 272,
    metadataLength: 463,
    leafDirectoriesOffset: 735,
    leafDirectoriesLength: 10888,
    tileDataOffset: 11623,
    tileDataLength: 7910833,
    numberOfAddressedTiles: 4099,
    numberOfTileEntries: 3963,
    numberOfTileContents: 3474,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.gzip,
    tileType: TileType.mvt,
    minZoom: 0,
    maxZoom: 6,
    minPosition: LatLng(latitude:-85.0, longitude:-180.0),
    maxPosition: LatLng(latitude:85.0, longitude:180.0),
    centerZoom: 0,
    centerPosition: LatLng(latitude:7.0137, longitude:0.0),
    ''',
  'countries-raster.pmtiles': ''' 
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 8227,
    metadataOffset: 8354,
    metadataLength: 100,
    leafDirectoriesOffset: 8454,
    leafDirectoriesLength: 0,
    tileDataOffset: 8454,
    tileDataLength: 7423783,
    numberOfAddressedTiles: 5461,
    numberOfTileEntries: 2883,
    numberOfTileContents: 2204,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.none,
    tileType: TileType.png,
    minZoom: 0,
    maxZoom: 6,
    minPosition: LatLng(latitude:-85.738076, longitude:-180.0),
    maxPosition: LatLng(latitude:84.798428, longitude:180.0),
    centerZoom: 2,
    centerPosition: LatLng(latitude:0.0, longitude:0.0),
''',
  'countries.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 8388,
    metadataOffset: 8515,
    metadataLength: 463,
    leafDirectoriesOffset: 8978,
    leafDirectoriesLength: 0,
    tileDataOffset: 8978,
    tileDataLength: 7910833,
    numberOfAddressedTiles: 4099,
    numberOfTileEntries: 3963,
    numberOfTileContents: 3474,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.gzip,
    tileType: TileType.mvt,
    minZoom: 0,
    maxZoom: 6,
    minPosition: LatLng(latitude:-85.0, longitude:-180.0),
    maxPosition: LatLng(latitude:85.0, longitude:180.0),
    centerZoom: 0,
    centerPosition: LatLng(latitude:7.0137, longitude:0.0),
''',
  'protomaps(vector)ODbL_firenze.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 406,
    metadataOffset: 533,
    metadataLength: 575,
    leafDirectoriesOffset: 1108,
    leafDirectoriesLength: 0,
    tileDataOffset: 1108,
    tileDataLength: 3958871,
    numberOfAddressedTiles: 108,
    numberOfTileEntries: 108,
    numberOfTileContents: 106,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.gzip,
    tileType: TileType.mvt,
    minZoom: 0,
    maxZoom: 14,
    minPosition: LatLng(latitude:43.727013, longitude:11.154026),
    maxPosition: LatLng(latitude:43.832546, longitude:11.32894),
    centerZoom: 0,
    centerPosition: LatLng(latitude:43.779779, longitude:11.241483),
''',
  'stamen_toner(raster)CC-BY+ODbL_z3.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 246,
    metadataOffset: 373,
    metadataLength: 22,
    leafDirectoriesOffset: 395,
    leafDirectoriesLength: 0,
    tileDataOffset: 395,
    tileDataLength: 715657,
    numberOfAddressedTiles: 85,
    numberOfTileEntries: 84,
    numberOfTileContents: 80,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.none,
    tileType: TileType.png,
    minZoom: 0,
    maxZoom: 3,
    minPosition: LatLng(latitude:-85.0, longitude:-180.0),
    maxPosition: LatLng(latitude:85.0, longitude:180.0),
    centerZoom: 0,
    centerPosition: LatLng(latitude:0.0, longitude:0.0),
''',
  'trails.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 2417,
    metadataOffset: 2544,
    metadataLength: 311,
    leafDirectoriesOffset: 2855,
    leafDirectoriesLength: 0,
    tileDataOffset: 2855,
    tileDataLength: 969515,
    numberOfAddressedTiles: 1201,
    numberOfTileEntries: 1201,
    numberOfTileContents: 1201,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.gzip,
    tileType: TileType.mvt,
    minZoom: 0,
    maxZoom: 14,
    minPosition: LatLng(latitude:48.253941, longitude:-114.477539),
    maxPosition: LatLng(latitude:49.009051, longitude:-113.225098),
    centerZoom: 14,
    centerPosition: LatLng(latitude:48.6402, longitude:-113.8348),
''',
  'usgs-mt-whitney-8-15-webp-512.pmtiles': '''
    magic: PMTiles,
    version: 3,
    rootDirectoryOffset: 127,
    rootDirectoryLength: 232,
    metadataOffset: 359,
    metadataLength: 210,
    leafDirectoriesOffset: 569,
    leafDirectoriesLength: 0,
    tileDataOffset: 569,
    tileDataLength: 1964030,
    numberOfAddressedTiles: 50,
    numberOfTileEntries: 50,
    numberOfTileContents: 50,
    clustered: Clustered.clustered,
    internalCompression: Compression.gzip,
    tileCompression: Compression.none,
    tileType: TileType.webp,
    minZoom: 8,
    maxZoom: 15,
    minPosition: LatLng(latitude:36.56109, longitude:-118.31982),
    maxPosition: LatLng(latitude:36.59301, longitude:-118.26069),
    centerZoom: 12,
    centerPosition: LatLng(latitude:36.577, longitude:-118.2903),
'''
};