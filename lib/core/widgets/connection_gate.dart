import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'app_button.dart';

/// التطبيق يعتمد على الاتصال، فعند انقطاعه تغطي صفحة كاملة كل الشاشات لحد ما يرجع
class ConnectionGate extends StatefulWidget {
  final Widget child;
  final Duration recheckInterval;

  const ConnectionGate({
    super.key,
    required this.child,
    this.recheckInterval = const Duration(seconds: 8),
  });

  @override
  State<ConnectionGate> createState() => _ConnectionGateState();
}

class _ConnectionGateState extends State<ConnectionGate> with WidgetsBindingObserver {
  Timer? _recheckTimer;
  bool _isChecking = false;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  /// فتح التطبيق بعد غيابه يفحص الاتصال، وأثناء الاستخدام الطلبات العادية بتكشف الانقطاع
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value) {
      _recheckTimer?.cancel();
      _recheckTimer = null;
      if (_isOffline) setState(() => _isOffline = false);
    } else {
      _confirmOffline();
    }
  }

  /// طلب واحد فاشل ممكن يكون نت ضعيف، فالصفحة تظهر بعد فحص تأكيدي
  Future<void> _confirmOffline() async {
    await _recheck();
    if (!mounted || ApiService.isServerReachable.value) return;

    if (!_isOffline) setState(() => _isOffline = true);
    _recheckTimer ??= Timer.periodic(widget.recheckInterval, (_) => _recheck());
  }

  Future<void> _recheck() async {
    if (_isChecking) return;
    _isChecking = true;
    await ApiService.checkServer();
    _isChecking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isOffline) _ConnectionLostPage(onRetry: _recheck),
      ],
    );
  }
}

class _ConnectionLostPage extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ConnectionLostPage({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 18),
              const Text(
                'مفيش اتصال بالإنترنت',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'التطبيق محتاج إنترنت عشان يشتغل، وهيرجع لوحده أول ما الاتصال يرجع',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              AppButton.primary(text: 'إعادة المحاولة', height: 50, onPressed: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}
