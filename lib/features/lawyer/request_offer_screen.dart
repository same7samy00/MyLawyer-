import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/request_repository.dart';
import '../urgent_service/order_details_screen.dart';

/// المحامي يقرأ الطلب ويبعت سعره جوه الحدود
class RequestOfferScreen extends StatefulWidget {
  final IncomingRequest request;

  const RequestOfferScreen({super.key, required this.request});

  @override
  State<RequestOfferScreen> createState() => _RequestOfferScreenState();
}

class _RequestOfferScreenState extends State<RequestOfferScreen> {
  late final TextEditingController _priceController = TextEditingController();
  late int _secondsLeft = widget.request.secondsLeft;
  late int? _sentPrice = widget.request.myPrice;
  Timer? _timer;
  bool _isBusy = false;
  bool _isChecking = false;

  IncomingRequest get _request => widget.request;
  int? get _price => int.tryParse(_priceController.text.trim());
  bool get _isInRange {
    final price = _price;
    return price != null && price >= _request.minPrice && price <= _request.maxPrice;
  }

  @override
  void initState() {
    super.initState();
    LiveUpdates.changes.addListener(_checkStatus);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft > 0) setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    LiveUpdates.changes.removeListener(_checkStatus);
    _priceController.dispose();
    super.dispose();
  }

  /// لو الموكل اختار العرض الصفحة بتتحول للطلب، ولو الطلب اتقفل بترجع للاستقبال
  Future<void> _checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;
    final res = await RequestRepository.incoming();
    _isChecking = false;
    if (!mounted || !res.isOk) return;

    final current = (res.data ?? const <IncomingRequest>[]).where((item) => item.id == _request.id).firstOrNull;
    final navigator = Navigator.of(context);
    if (current == null) {
      _showNotice('الطلب اتقفل');
      navigator.pop();
      return;
    }
    final orderId = current.orderId;
    if (current.isChosen && orderId != null) {
      LiveUpdates.changes.removeListener(_checkStatus);
      final order = (await OrderRepository.getOrderById(orderId)).data;
      if (!mounted || order == null) return;
      _showNotice('الموكل اختار عرضك');
      await navigator.pushReplacement(MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order, isLawyer: true)));
    }
  }

  void _setPrice(int price) {
    _priceController.text = '$price';
    setState(() {});
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback))),
    );
  }

  Future<void> _send() async {
    final price = _price;
    if (price == null || _isBusy) return;
    setState(() => _isBusy = true);
    final res = await RequestRepository.sendOffer(_request.id, price);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (res.isOk) _sentPrice = price;
    });
    _showNotice(res.isOk ? 'عرضك اتبعت للموكل' : (res.error ?? 'تعذر إرسال العرض'));
  }

  Future<void> _withdraw() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final res = await RequestRepository.withdrawOffer(_request.id);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      if (res.isOk) _sentPrice = null;
    });
    _showNotice(res.isOk ? 'تم سحب عرضك' : (res.error ?? 'تعذر سحب العرض'));
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentPrice;
    final min = _request.minPrice;
    final max = _request.maxPrice;
    final price = _price;
    final minutes = _secondsLeft ~/ 60;
    final seconds = (_secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'طلب جديد', isInnerPage: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_request.problemType, style: _titleStyle),
                  const SizedBox(height: 8),
                  if (_request.problemDescription.isNotEmpty) ...[
                    Text(_request.problemDescription, style: _bodyStyle),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    '${_request.area ?? 'مكان الموكل'} • على بعد ${_request.distanceKm} كم تقريبًا',
                    style: _mutedStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: sent != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('عرضك: $sent ج.م', textAlign: TextAlign.center, style: _titleStyle),
                        const SizedBox(height: 4),
                        Text('صافي ليك: ${_request.netOf(sent)} ج.م', textAlign: TextAlign.center, style: _mutedStyle),
                        const SizedBox(height: 4),
                        const Text('مستنيين الموكل يختار', textAlign: TextAlign.center, style: _mutedStyle),
                        const SizedBox(height: 12),
                        AppButton.outlined(text: 'اسحب العرض', height: 44, onPressed: _isBusy ? null : _withdraw),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('السعر المسموح: من $min لـ $max ج.م', style: _titleStyle),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'سعرك بالجنيه'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: AppButton.outlined(text: 'أقل سعر', height: 40, fontSize: 12, onPressed: () => _setPrice(min))),
                            const SizedBox(width: 6),
                            Expanded(child: AppButton.outlined(text: 'المتوسط', height: 40, fontSize: 12, onPressed: () => _setPrice(((min + max) / 2).round()))),
                            const SizedBox(width: 6),
                            Expanded(child: AppButton.outlined(text: 'أعلى سعر', height: 40, fontSize: 12, onPressed: () => _setPrice(max))),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (price != null)
                          Text(
                            _isInRange ? 'صافي ليك: ${_request.netOf(price)} ج.م' : 'السعر لازم يكون من $min لـ $max ج.م',
                            textAlign: TextAlign.center,
                            style: _isInRange ? _mutedStyle : _mutedStyle.copyWith(color: AppColors.danger),
                          ),
                        const SizedBox(height: 10),
                        AppButton.primary(
                          text: 'ابعت العرض',
                          height: 46,
                          onPressed: _isInRange && _secondsLeft > 0 && !_isBusy ? _send : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _secondsLeft > 0 ? 'باقي $minutes:$seconds' : 'وقت إرسال العروض خلص',
                          textAlign: TextAlign.center,
                          style: _mutedStyle,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static const TextStyle _titleStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.dark,
  );
  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 13,
    height: 1.5,
    color: AppColors.textMain,
  );
  static const TextStyle _mutedStyle = TextStyle(
    fontFamily: 'AppFont',
    fontFamilyFallback: appFontFallback,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
  );
}
