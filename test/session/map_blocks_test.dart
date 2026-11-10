import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_lawyer/core/services/map_lawyer_loader.dart';

import '../helpers/session_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpSessionTests();

  test('موبايلين في نفس المنطقة بيطلبوا نفس بلوكات الخريطة بالظبط، عشان السيرفر يحفظ الرد مرة للكل', () async {
    final asked = <String>[];
    backend.overrides['GET /lawyers/map'] = (request) {
      asked.add(request.url.query);
      return FakeBackend.json(200, {
        'success': true,
        'data': {'size': 's', 'kind': 'cards', 'cells': <String, dynamic>{}, 'seconds': 300},
      });
    };

    // مكانين جنب بعض في نفس البلوك، وكل واحد شايف منطقة مختلفة شوية
    final first = MapLawyerLoader(onChanged: () {});
    await first.loadAround(const LatLng(30.05, 31.25), radiusKm: 2);
    final fromFirst = List<String>.from(asked);
    asked.clear();

    final second = MapLawyerLoader(onChanged: () {});
    await second.loadAround(const LatLng(30.07, 31.27), radiusKm: 2);

    expect(fromFirst, isNotEmpty);
    expect(asked.toSet(), fromFirst.toSet());
    // البلوك 2 في 2 مربعات صغيرة، كلها في طلب واحد
    expect(Uri.splitQueryString(fromFirst.first)['cells']!.split(',').length, 4);
  });
}
