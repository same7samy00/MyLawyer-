import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/order_action_sheets.dart';
import '../../data/repositories/order_repository.dart';

/// محفظة الموكل: المبالغ المرتجعة والتحويلات، ومنها التحويل لأي حساب
class WalletTab extends StatefulWidget {
  final ValueListenable<int>? refreshSignal;

  const WalletTab({super.key, this.refreshSignal});

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  // الرصيد المحفوظ بيظهر من أول لحظة
  static num? get _savedBalance => OrderRepository.peekWallet()?['balance'] as num?;
  bool _isLoading = _savedBalance == null;
  String? _error;
  double _balance = (_savedBalance ?? 0).toDouble();

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_load);
    LiveUpdates.orders.addListener(_load);
    ApiService.isServerReachable.addListener(_onReachabilityChanged);
    _showSaved();
    _load();
  }

  Future<void> _showSaved() async {
    final saved = await OrderRepository.savedWallet();
    final balance = saved?['balance'];
    if (!mounted || balance is! num || !_isLoading) return;
    setState(() {
      _balance = balance.toDouble();
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_load);
    LiveUpdates.orders.removeListener(_load);
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


  Future<void> _openTransfer() async {
    final sent = await OrderActionSheets.transfer(
      context,
      findRecipient: OrderRepository.findTransferRecipient,
      onSubmit: OrderRepository.transfer,
    );
    if (!sent || !mounted) return;
    showAppMessage(context, 
      const SnackBar(content: Text('تم التحويل'), backgroundColor: AppColors.success),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoader());
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
                    AppConfig.walletTransfers
                        ? 'المبالغ المرتجعة من طلباتك والتحويلات اللي وصلتك'
                        : 'المبالغ المرتجعة من طلباتك',
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
            if (AppConfig.walletTransfers) ...[
              const SizedBox(height: 16),
              AppButton.primary(
                text: 'تحويل لحساب تاني',
                icon: Icons.send_rounded,
                onPressed: _openTransfer,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
