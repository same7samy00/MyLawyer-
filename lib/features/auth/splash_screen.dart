import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_permission_service.dart';
import 'app_permissions_screen.dart';
import 'session_router.dart';

/// شاشة البداية (Splash Screen)
/// تعرض فيديو موشن جرافيك لتحريك الشعار (Logo Animation Motion Graphics)
/// بخلفية بيضاء ناصعة وفيديو مصغر في المنتصف بدون أي أيقونات أو مؤشرات تحميل
/// وتتحقق من الجلسة بالتوازي مع الفيديو ثم تنتقل مرة واحدة للوجهة الصحيحة
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // الشعار بيكمل حركته للآخر، وده حد أمان بس لو الفيديو ما اشتغلش
  static const Duration _maxLogoDuration = Duration(seconds: 8);

  late VideoPlayerController _controller;
  late final Future<SessionCheck> _sessionCheck;
  final Completer<void> _logoFinished = Completer<void>();
  Timer? _logoTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _sessionCheck = AuthService.restoreSession();

    _controller = VideoPlayerController.asset('assets/videos/splash_logo.mp4')
      ..setVolume(0.0)
      ..initialize().then((_) {
        if (!mounted) return;
        _controller.setVolume(0.0);
        setState(() {});
        _controller.play();
      }).catchError((error) {
        debugPrint('VideoPlayer initialization: $error');
        _markLogoFinished();
      });

    _controller.addListener(_videoListener);
    _logoTimer = Timer(_maxLogoDuration, _markLogoFinished);
    _openDestination();
  }

  void _videoListener() {
    if (_controller.value.isInitialized &&
        _controller.value.duration > Duration.zero &&
        _controller.value.position >= _controller.value.duration) {
      _markLogoFinished();
    }
  }

  void _markLogoFinished() {
    if (!_logoFinished.isCompleted) {
      _logoFinished.complete();
    }
  }

  Future<void> _openDestination() async {
    final check = await _sessionCheck;
    await _logoFinished.future;
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    final navigator = Navigator.of(context);
    if (await DevicePermissionService.instance.hasRequestedInitialPermissions()) {
      await SessionRouter.openSession(navigator, check);
    } else {
      await SessionRouter.replaceStack(navigator, AppPermissionsScreen(check: check));
    }
  }

  @override
  void dispose() {
    _logoTimer?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          // تصغير الفيديو ليكون متناسقاً وفي المنتصف بخلفية بيضاء مدمجة
          constraints: BoxConstraints(
            maxWidth: screenSize.width * 0.65,
            maxHeight: screenSize.height * 0.65,
          ),
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
