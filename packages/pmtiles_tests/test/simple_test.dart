import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';
import 'package:convert/convert.dart';

// We include the test files, so this can work on all platforms.
//
// The following can be used to generate the hex strings:
// ```
// for f in {empty,invalid,invalid,test_fixture_1,test_fixture_2}.pmtiles;
//   do echo -n \'$f\': \'; xxd -p $f; echo \';
// done;
// ```
const fixtures = {
  'empty.pmtiles': '',
  'invalid.pmtiles':
      '5468697320697320616e20696e76616c69642074696c6520617263686976'
          '652c20612074657374206361736520746f206d616b652073757265207468'
          '61742074686520636f6465207468726f777320616e206572726f722c2062'
          '7574206974206e6565647320746f20626520746865206d696e696d756d20'
          '73697a6520746f20706173732074686520666972737420746573740a',
  'invalid_v4.pmtiles':
      '504d54696c6573047f000000000000001900000000000000980000000000'
          '0000f700000000000000000000000000000000000000000000008f010000'
          '000000004500000000000000010000000000000001000000000000000100'
          '00000000000000020201000000000000000000007f969800809698000000'
          '000000000000001f8b0800000000000213636460746504004c3f89000500'
          '00001f8b08000000000002137d4fcb6e833010bce72bac3d0325917ae9b5'
          '3fd07b8590631664097b91bd4421c8ff1edb491bfa508e333b3b8f750756'
          '1a8437018c9edb5e9f7976d8eeabc9b01ed143b1830ebd727a624df6b9f0'
          '84cedf4587847999b235c5c32897440d68d14926979df434a19296509c0e'
          'd56b55ff50b494237d52562f1b6d79194449e2ff1ea22c7b720a6f7d54f2'
          '89d1b158b4f914ab00ddfd1df1bd41fc1e9b28a3ed85c844582724cf1bd4'
          '6b1cbbe4bd06114453403662c999831cfd4eb3e508f7053caadc6f4fba80'
          '7afc0d4806d92d49fe41e332c476054866a78f33e35742bde1724a139a10'
          'ae9b6c0adbe50100001f8b080000000000021393d2af60e2122d492d2e89'
          '4fcbac28292d4a8d372cc82dc9cc492dd668501012946056e2e59ca6f042'
          '5e8a41429481419c1f0097fa6b2d31000000',
  'test_fixture_1.pmtiles':
      '504d54696c6573037f000000000000001900000000000000980000000000'
          '0000f700000000000000000000000000000000000000000000008f010000'
          '000000004500000000000000010000000000000001000000000000000100'
          '00000000000000020201000000000000000000007f969800809698000000'
          '000000000000001f8b0800000000000213636460746504004c3f89000500'
          '00001f8b08000000000002137d4fcb6e833010bce72bac3d0325917ae9b5'
          '3fd07b8590631664097b91bd4421c8ff1edb491bfa508e333b3b8f750756'
          '1a8437018c9edb5e9f7976d8eeabc9b01ed143b1830ebd727a624df6b9f0'
          '84cedf4587847999b235c5c32897440d68d14926979df434a19296509c0e'
          'd56b55ff50b494237d52562f1b6d79194449e2ff1ea22c7b720a6f7d54f2'
          '89d1b158b4f914ab00ddfd1df1bd41fc1e9b28a3ed85c844582724cf1bd4'
          '6b1cbbe4bd06114453403662c999831cfd4eb3e508f7053caadc6f4fba80'
          '7afc0d4806d92d49fe41e332c476054866a78f33e35742bde1724a139a10'
          'ae9b6c0adbe50100001f8b080000000000021393d2af60e2122d492d2e89'
          '4fcbac28292d4a8d372cc82dc9cc492dd668501012946056e2e59ca6f042'
          '5e8a41429481419c1f0097fa6b2d31000000',
  'test_fixture_2.pmtiles':
      '504d54696c6573037f000000000000001900000000000000980000000000'
          '0000f700000000000000000000000000000000000000000000008f010000'
          '000000004300000000000000010000000000000001000000000000000100'
          '00000000000000020201000000000000000000007f969800809698000000'
          '000000000000001f8b080000000000021363646074660400ca98d3560500'
          '00001f8b08000000000002137d4fcb6e833010bce72bac3d03a548bdf4da'
          '1fe8bd42c8350bb284bd96bd4421887f8feda40d7d28c7999d9dc77a002b'
          '0dc2ab00c6c0dda04f3c7bec9aca19d61306280ed063505e3bd6641f0b8f'
          'e8c34dd424cc8bcbd6140f935c1235a2452f997c76d2cea19296501c9bea'
          'a5aa7f283aca912129aba79db63c8fa224f17f0f5196037985d73e2af9c4'
          'e8582cda7c885580eeff8ef8de207e8f4d94d1f64c6422ac1392a71d1a34'
          '4e7df25e37b189b6806cc492330739fa8d66cb113e1770af72bb3de802ea'
          'fe37221964bf24f93b4dcb18db152099bdfe9c19bf12ea1d9753daadddb6'
          '0b75f5f4b4e50100001f8b080000000000021393d2ad60e2122d492d2e89'
          '4fcbac28292d4a8d372ac82dc9cc492dd6685010e2976056e2e66c507821'
          '2f242621cac00f004e3d121b2f000000',
};

// Simple smoke tests, which don't use File or HTTP apis.
void main() async {
  final expected = <String, Matcher>{
    'empty.pmtiles': throwsA(isA<CorruptArchiveException>()),
    'invalid.pmtiles': throwsA(isA<CorruptArchiveException>()),
    'invalid_v4.pmtiles': throwsA(isA<UnsupportedError>()),
    'test_fixture_1.pmtiles': throwsA(isA<UnsupportedError>()),
    'test_fixture_2.pmtiles': throwsA(isA<UnsupportedError>()),

    // TODO Add a valid pmtiles file, that we can test against.
  };

  for (final e in fixtures.entries) {
    final name = e.key;
    final fixture = e.value;

    test('PmTilesArchive($name).metadata', () async {
      expect(() async => await PmTilesArchive.fromBytes(hex.decode(fixture)),
          expected[name]!);
    });
  }
}
