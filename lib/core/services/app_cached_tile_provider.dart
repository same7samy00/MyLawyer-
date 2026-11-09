import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../constants/map_config.dart';

/// مزود بلاطات متقدم يدعم التخزين المؤقت الدائم على هاتف المستخدم (Persistent Disk Cache)
/// مع كاش فائق السرعة في الذاكرة العشوائية (RAM Memory Cache) وحماية من البلاطات التالفة
class AppCachedTileProvider extends TileProvider {
  AppCachedTileProvider._();
  static final AppCachedTileProvider instance = AppCachedTileProvider._();

  static Directory? _diskCacheDirectory;
  static bool _isCleaning = false;

  /// تهيئة مجلد التخزين المؤقت الدائم على جهاز المستخدم
  static Future<Directory> getCacheDirectory() async {
    if (_diskCacheDirectory != null) return _diskCacheDirectory!;
    Directory baseDir;
    try {
      baseDir = await getTemporaryDirectory();
    } catch (_) {
      baseDir = Directory.systemTemp;
    }
    // رقم المجلد يتغير مع شكل الخريطة، فالموبايل ما يعرضش الصور القديمة
    // Folders of earlier maps are removed from the phone once
    for (final old in ['my_lawyer_map_tiles', 'my_lawyer_map_tiles_v2', 'my_lawyer_map_tiles_v3']) {
      final oldCacheDir = Directory('${baseDir.path}/$old');
      if (oldCacheDir.existsSync()) oldCacheDir.deleteSync(recursive: true);
    }

    // v4: خريطة TomTom بمربعات 512
    final cacheDir = Directory('${baseDir.path}/my_lawyer_map_tiles_v4');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    _diskCacheDirectory = cacheDir;

    // تنظيف دوري خفيف في الخلفية لملفات الكاش القديمة
    _scheduleCachePruning(cacheDir);

    return cacheDir;
  }

  /// إدارة مساحة التخزين وحذف البلاطات القديمة تلقائياً دون التأثير على استجابة التطبيق
  static void _scheduleCachePruning(Directory dir) {
    if (_isCleaning) return;
    _isCleaning = true;
    Future.microtask(() async {
      try {
        final now = DateTime.now();
        int totalSize = 0;
        final List<File> files = [];

        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File) {
            files.add(entity);
            final stat = await entity.stat();
            totalSize += stat.size;
            // حذف أي ملف عمره أكثر من 30 يوماً
            if (now.difference(stat.modified).inDays > 30) {
              await entity.delete();
            }
          }
        }

        // إذا تجاوز الحجم الكلي 150 ميجابايت، يتم حذف أقدم 25% من الملفات تلقائياً
        const int maxCacheBytes = 150 * 1024 * 1024;
        if (totalSize > maxCacheBytes && files.isNotEmpty) {
          files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
          final deleteCount = (files.length * 0.25).ceil();
          for (int i = 0; i < deleteCount && i < files.length; i++) {
            try {
              await files[i].delete();
            } catch (_) {}
          }
        }
      } catch (_) {
      } finally {
        _isCleaning = false;
      }
    });
  }

  static final Set<String> _warmed = {};

  /// بيحمّل مربعات الخريطة حوالين مكان على القرص من بدري، فأول ما الخريطة تتفتح تظهر كاملة.
  /// مربعات قليلة (حوالي 50)، بالتوازي على اتصال واحد، واللي متحفوظ ما بيتطلبش تاني
  static Future<void> warmAround(double lat, double lon, {List<int> zooms = const [13, 14]}) async {
    final place = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';
    if (!_warmed.add(place)) return;
    final dir = await getCacheDirectory();
    final jobs = <Future<void>>[];
    for (final z in zooms) {
      final n = 1 << z;
      final x = ((lon + 180) / 360 * n).floor();
      final rad = lat * 3.141592653589793 / 180;
      final y = ((1 - (math.log(math.tan(rad) + 1 / math.cos(rad)) / 3.141592653589793)) / 2 * n).floor();
      for (var dx = -2; dx <= 2; dx++) {
        for (var dy = -3; dy <= 2; dy++) {
          final file = File('${dir.path}/map_${z}_${x + dx}_${y + dy}.tile');
          if (file.existsSync()) continue;
          final url = MapConfig.serverTileUrl.replaceAll('{z}', '$z').replaceAll('{x}', '${x + dx}').replaceAll('{y}', '${y + dy}');
          jobs.add(() async {
            try {
              final res = await AppCachedMapImageProvider._client.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
              if (res.statusCode == 200 && res.bodyBytes.length > 200) await file.writeAsBytes(res.bodyBytes, flush: false);
            } catch (_) {}
          }());
        }
      }
    }
    await Future.wait(jobs);
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final primaryUrl = getTileUrl(coordinates, options);
    final fallbackUrl = getTileFallbackUrl(coordinates, options);

    return AppCachedMapImageProvider(
      coordinates: coordinates,
      primaryUrl: primaryUrl,
      fallbackUrl: fallbackUrl,
      headers: headers,
    );
  }
}

/// ImageProvider مخصص لإدارة الكاش الثنائي (RAM + Flash Storage) للبلاطات النقطية
@immutable
class AppCachedMapImageProvider extends ImageProvider<AppCachedMapImageProvider> {
  /// اتصال واحد مفتوح لكل المربعات بدل اتصال جديد لكل مربع، وده أكبر فرق في السرعة
  static final http.Client _client = http.Client();

  final TileCoordinates coordinates;
  final String primaryUrl;
  final String? fallbackUrl;
  final Map<String, String> headers;

  const AppCachedMapImageProvider({
    required this.coordinates,
    required this.primaryUrl,
    required this.fallbackUrl,
    this.headers = const {},
  });

  @override
  ImageStreamCompleter loadImage(
    AppCachedMapImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      _loadTinted(key, decode),
      informationCollector: () => [
        DiagnosticsProperty('Coordinates', coordinates),
        DiagnosticsProperty('Primary URL', primaryUrl),
      ],
    );
  }

  /// ألوان الخريطة أقرب لهوية التطبيق (رمادي مزرق هادي بدل البيج). اللون بيتطبق مرة واحدة لما المربع
  /// يتحمل، مش في كل إطار، فمفيش أي تقل وقت تحريك الخريطة
  static const List<double> _brandTint = [
    0.35 + 0.6175 * 0.2126, 0.6175 * 0.7152, 0.6175 * 0.0722, 0, 0,
    0.6305 * 0.2126, 0.35 + 0.6305 * 0.7152, 0.6305 * 0.0722, 0, 0,
    0.6695 * 0.2126, 0.6695 * 0.7152, 0.35 + 0.6695 * 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];
  static final Paint _tintPaint = Paint()
    ..colorFilter = const ColorFilter.matrix(_brandTint)
    ..filterQuality = FilterQuality.none;

  Future<ImageInfo> _loadTinted(AppCachedMapImageProvider key, ImageDecoderCallback decode) async {
    final codec = await _loadAsync(key, decode);
    final frame = await codec.getNextFrame();
    final raw = frame.image;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImage(raw, Offset.zero, _tintPaint);
    final picture = recorder.endRecording();
    final tinted = await picture.toImage(raw.width, raw.height);
    picture.dispose();
    raw.dispose();
    return ImageInfo(image: tinted, debugLabel: primaryUrl);
  }

  Future<ui.Codec> _loadAsync(
    AppCachedMapImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final fileName = 'map_${coordinates.z}_${coordinates.x}_${coordinates.y}.tile';

    // 1. الفحص الفوري في التخزين الدائم على قرص الهاتف (Disk Cache Hit)
    try {
      final cacheDir = await AppCachedTileProvider.getCacheDirectory();
      final localFile = File('${cacheDir.path}/$fileName');

      if (localFile.existsSync() && localFile.lengthSync() > 200) {
        final bytes = await localFile.readAsBytes();
        if (_isValidTile(bytes)) {
          final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
          return await decode(buffer);
        } else {
          // ملف تالف أو غير مكتمل؛ يتم حذفه من القرص
          try {
            localFile.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {
      // المتابعة لجلب البلاطة من الشبكة في حال حدوث أي خطأ بالقرص
    }

    // 2. الجلب من السيرفر الأساسي للتطبيق (VPS Cache)
    Uint8List? downloadedBytes;
    try {
      final response = await _client.get(
        Uri.parse(primaryUrl),
        headers: headers,
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200 && _isValidTile(response.bodyBytes)) {
        downloadedBytes = response.bodyBytes;
      }
    } catch (_) {}

    // 3. المحاولة التلقائية مع خادم الـ Fallback إذا تعذر الخادم الأساسي
    if (downloadedBytes == null && fallbackUrl != null && fallbackUrl!.isNotEmpty) {
      try {
        final fbResponse = await _client.get(
          Uri.parse(fallbackUrl!),
          headers: headers,
        ).timeout(const Duration(milliseconds: 3500));

        if (fbResponse.statusCode == 200 && _isValidTile(fbResponse.bodyBytes)) {
          // الخريطة الاحتياطية لا تُحفظ حتى ترجع خريطتنا أول ما الخادم يتوفر
          final buffer = await ui.ImmutableBuffer.fromUint8List(fbResponse.bodyBytes);
          return await decode(buffer);
        }
      } catch (_) {}
    }

    // 4. حفظ البلاطة السليمة على قرص الهاتف بشكل غير متزامن
    if (downloadedBytes != null) {
      _saveTileToDiskAsync(fileName, downloadedBytes);
      final buffer = await ui.ImmutableBuffer.fromUint8List(downloadedBytes);
      return decode(buffer);
    }

    // 5. في حال انقطاع الشبكة تماماً وعدم توفر البلاطة في الكاش: إعادة بلاطة شفافة لمنع تجمد أو انهيار الواجهة
    final transparentBuffer = await ui.ImmutableBuffer.fromUint8List(TileProvider.transparentImage);
    return decode(transparentBuffer);
  }

  void _saveTileToDiskAsync(String fileName, Uint8List bytes) {
    Future.microtask(() async {
      try {
        final cacheDir = await AppCachedTileProvider.getCacheDirectory();
        final file = File('${cacheDir.path}/$fileName');
        await file.writeAsBytes(bytes, flush: false);
      } catch (_) {}
    });
  }

  /// التحقق من بداية الملف لمنع تخزين صفحات خطأ HTML بدل صور الخريطة
  bool _isValidTile(Uint8List bytes) {
    if (bytes.length < 12) return false;
    final isPng = bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    final isWebp = bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50;
    return isPng || isWebp;
  }

  @override
  Future<AppCachedMapImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AppCachedMapImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppCachedMapImageProvider &&
        other.coordinates.z == coordinates.z &&
        other.coordinates.x == coordinates.x &&
        other.coordinates.y == coordinates.y &&
        other.primaryUrl == primaryUrl;
  }

  @override
  int get hashCode => Object.hash(
        coordinates.z,
        coordinates.x,
        coordinates.y,
        primaryUrl,
      );
}
