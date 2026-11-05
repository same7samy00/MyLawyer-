import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/live_updates.dart';
import '../../core/widgets/app_button.dart';
import '../../data/models/service_request.dart';
import '../../data/repositories/request_repository.dart';

/// تفاصيل الطلب الجديد، و«ابعت عرضك» يغير المحتوى لخانة السعر، والإرسال يقفل الشيت
class RequestOfferSheet extends StatefulWidget {
  final IncomingRequest request;

  const RequestOfferSheet({super.key, required this.request});

  static Future<void> open(BuildContext context, IncomingRequest request) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.0))),
      builder: (_) => RequestOfferSheet(request: request),
    );
  }

  @override
  State<RequestOfferSheet> createState() => _RequestOfferSheetState();
}

class _RequestOfferSheetState extends State<RequestOfferSheet> {
  final TextEditingController _priceController = TextEditingController();
  late int _secondsLeft = widget.request.secondsLeft;
  late final int? _sentPrice = widget.request.myPrice;
  Timer? _timer;
  bool _isWritingPrice = false;
  bool _isBusy = false;
  bool _isChecking = false;
  String? _error;

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

  /// لو الطلب اتقفل أو اتختار، الشيت يتقفل والبطاقة تعرض الحالة
  Future<void> _checkStatus() async {
    if (_isChecking) return;
    _isChecking = true;
    final res = await RequestRepository.incoming();
    _isChecking = false;
    if (!mounted || !res.isOk) return;

    final current = (res.data ?? const <IncomingRequest>[]).where((item) => item.id == _request.id).firstOrNull;
    if (current == null || current.isChosen) Navigator.of(context).pop();
  }

  void _setPrice(int price) {
    _priceController.text = '$price';
    setState(() {});
  }

  Future<void> _send() async {
    final price = _price;
    if (price == null || _isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final res = await RequestRepository.sendOffer(_request.id, price);
    if (!mounted) return;
    if (res.isOk) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isBusy = false;
      _error = res.error ?? 'تعذر إرسال العرض';
    });
  }

  Future<void> _withdraw() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    final res = await RequestRepository.withdrawOffer(_request.id);
    if (!mounted) return;
    if (res.isOk) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isBusy = false;
      _error = res.error ?? 'تعذر سحب العرض';
    });
  }

  List<Widget> _details() {
    final sent = _sentPrice;
    return [
      Text(_request.problemType, textAlign: TextAlign.center, style: _titleStyle),
      const SizedBox(height: 10),
      if (_request.problemDescription.isNotEmpty) ...[
        Text(_request.problemDescription, style: _bodyStyle),
        const SizedBox(height: 10),
      ],
      Text('${_request.area ?? 'مكان الموكل'} • على بعد ${_request.distanceKm} كم تقريبًا', style: _mutedStyle),
      const SizedBox(height: 4),
      Text('السعر المسموح: من ${_request.minPrice} لـ ${_request.maxPrice} ج.م', style: _mutedStyle),
      const SizedBox(height: 16),
      if (sent != null) ...[
        Text('عرضك: $sent ج.م • صافي ليك: ${_request.netOf(sent)} ج.م', textAlign: TextAlign.center, style: _titleStyle),
        const SizedBox(height: 10),
        AppButton.outlined(text: 'اسحب العرض', height: 44, onPressed: _isBusy ? null : _withdraw),
      ] else ...[
        AppButton.primary(
          text: 'ابعت عرضك',
          height: 46,
          onPressed: _secondsLeft > 0 ? () => setState(() => _isWritingPrice = true) : null,
        ),
        const SizedBox(height: 8),
        Text(_timeText, textAlign: TextAlign.center, style: _mutedStyle),
      ],
      const SizedBox(height: 6),
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
    ];
  }

  String get _timeText {
    if (_secondsLeft <= 0) return 'وقت إرسال العروض خلص';
    return 'باقي ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}';
  }

  List<Widget> _priceForm() {
    final min = _request.minPrice;
    final max = _request.maxPrice;
    final price = _price;
    return [
      const Text('اكتب سعرك', textAlign: TextAlign.center, style: _titleStyle),
      const SizedBox(height: 4),
      Text('من $min لـ $max ج.م', textAlign: TextAlign.center, style: _mutedStyle),
      const SizedBox(height: 12),
      TextField(
        controller: _priceController,
        autofocus: true,
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
        text: 'إرسال',
        height: 46,
        onPressed: _isInRange && _secondsLeft > 0 && !_isBusy ? _send : null,
      ),
      const SizedBox(height: 6),
      Text(_timeText, textAlign: TextAlign.center, style: _mutedStyle),
      TextButton(onPressed: () => setState(() => _isWritingPrice = false), child: const Text('رجوع')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...(_isWritingPrice ? _priceForm() : _details()),
              if (_error != null)
                Text(_error!, textAlign: TextAlign.center, style: _mutedStyle.copyWith(color: AppColors.danger)),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _titleStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.dark);
  static const TextStyle _bodyStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 13, height: 1.5, color: AppColors.textMain);
  static const TextStyle _mutedStyle = TextStyle(fontFamily: 'AppFont', fontFamilyFallback: appFontFallback, fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted);
}
