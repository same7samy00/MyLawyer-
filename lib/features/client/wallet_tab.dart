import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_state_message.dart';
import '../../data/repositories/order_repository.dart';

/// محفظة الموكل: المبالغ المرتجعة من الطلبات والشكاوى
class WalletTab extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const WalletTab({super.key, this.refreshSignal});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  bool _isLoading = true;
  String? _error;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_load);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_load);
    ApiService.isServerReachable.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  void _onReachabilityChanged() {
    if (ApiService.isServerReachable.value && _error != null) _load();
  }

  Future<void> _load() async {
    final res = await OrderRepository.getClientBalance();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (res.isOk) {
        _balance = res.data ?? 0;
        _error = null;
      } else {
        _error = res.error ?? 'تعذر تحميل الرصيد';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return SafeArea(
        child: AppStateMessage(
          icon: Icons.wifi_off_rounded,
          title: 'تعذر تحميل الرصيد',
          message: _error,
          onRetry: _load,
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              backgroundColor: AppColors.dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'الرصيد المتاح',
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 13,
                      color: AppColors.cardBorder,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_balance.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'المبالغ المرتجعة من طلباتك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'AppFont',
                      fontFamilyFallback: appFontFallback,
                      fontSize: 12,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
