import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// شريط حالة الاتصال أسفل التطبيق، يظهر عند تعذر الوصول للخادم
/// ويعيد الفحص تلقائياً ليختفي فور عودة الاتصال دون أي تدخل من المستخدم
class ConnectionBanner extends StatefulWidget {
  final Widget child;
  final Duration recheckInterval;

  const ConnectionBanner({
    super.key,
    required this.child,
    this.recheckInterval = const Duration(seconds: 8),
  });

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  Timer? _recheckTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _onReachabilityChanged();
  }

  @override
  void dispose() {
    _recheckTimer?.cancel();
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value) {
      _recheckTimer?.cancel();
      _recheckTimer = null;
    } else {
      _recheckTimer ??= Timer.periodic(widget.recheckInterval, (_) => _recheck());
    }
  }

  Future<void> _recheck() async {
    if (_isChecking) return;
    _isChecking = true;
    await ApiService.checkServer();
    _isChecking = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: widget.child),
        ValueListenableBuilder<bool>(
          valueListenable: ApiService.isServerReachable,
          builder: (context, isReachable, _) {
            if (isReachable) return const SizedBox.shrink();
            return const Material(
              color: AppColors.dark,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'لا يوجد اتصال بالخادم، البيانات المعروضة قد لا تكون محدثة.',
                          style: TextStyle(
                            fontFamily: 'AppFont',
                            fontFamilyFallback: appFontFallback,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
