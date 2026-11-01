import 'package:url_launcher/url_launcher.dart';

/// فتح الملاحة في تطبيق خرائط Google على موقع الموكل الدقيق
class ExternalNavigation {
  ExternalNavigation._();

  static Uri directionsUri(double lat, double lon) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lon',
      'travelmode': 'driving',
    });
  }

  static Future<bool> openDirections(double lat, double lon) {
    return launchUrl(directionsUri(lat, lon), mode: LaunchMode.externalApplication);
  }
}
