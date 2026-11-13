import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_choice_chip.dart';
import '../../core/widgets/app_field_error.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_message.dart';
import '../../data/models/order_model.dart';
import '../../data/models/support_ticket.dart';
import '../../data/repositories/order_repository.dart';
import '../../data/repositories/support_repository.dart';
import 'support_widgets.dart';

/// تذكرة جديدة: النوع، والطلب لو المشكلة على طلب، والعنوان، والتفاصيل، ولحد 5 صور
class NewTicketScreen extends StatefulWidget {
  /// لما التذكرة تتفتح من صفحة طلب، الطلب بيكون متحدد لوحده
  final OrderModel? order;

  const NewTicketScreen({super.key, this.order});

  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  late String _category = widget.order == null ? 'OTHER' : 'ORDER';
  late OrderModel? _order = widget.order;
  List<OrderModel> _orders = const [];
  List<String> _images = const [];
  /// غلط الإرسال نفسه من السيرفر، تحت الزرار
  String? _error;

  /// غلط كل خانة، أحمر تحت الخانة نفسها وبيختفي لما تتصلّح
  final Map<String, String> _errors = {};
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.order == null) _loadOrders();
    _title.addListener(() => _clearError('title'));
    _body.addListener(() => _clearError('body'));
  }

  void _clearError(String key) {
    if (_errors.containsKey(key)) setState(() => _errors.remove(key));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final res = await OrderRepository.getOrders();
    if (!mounted || !res.isOk) return;
    setState(() => _orders = res.data ?? const []);
  }

  Future<void> _send() async {
    final errors = <String, String>{
      if (_category == 'ORDER' && _order == null) 'order': 'اختار الطلب اللي فيه المشكلة',
      if (_title.text.trim().length < 3) 'title': 'اكتب عنوان للمشكلة',
      if (_body.text.trim().length < 10) 'body': 'اكتب تفاصيل المشكلة في 10 أحرف على الأقل',
    };
    if (errors.isNotEmpty) {
      setState(() {
        _error = null;
        _errors
          ..clear()
          ..addAll(errors);
      });
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });
    final res = await SupportRepository.createTicket(
      category: _category,
      title: _title.text.trim(),
      body: _body.text.trim(),
      orderId: _order?.id,
      imagePaths: _images,
    );
    if (!mounted) return;

    if (res.isOk) {
      showAppMessage(context, 
        SnackBar(content: Text(res.message ?? 'استلمنا تذكرتك'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSending = false;
        _error = res.error ?? 'تعذر إرسال التذكرة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'تذكرة جديدة', isInnerPage: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // From an order the problem is about that order, so there is nothing to choose
            if (widget.order == null) ...[
              const Text('نوع المشكلة', style: supportTitleStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in SupportTicket.categories.entries)
                    AppChoiceChip(
                      label: entry.value,
                      selected: _category == entry.key,
                      onSelected: (_) => setState(() => _category = entry.key),
                    ),
                ],
              ),
            ],
            if (widget.order != null || _category == 'ORDER' || _category == 'MONEY') ...[
              const SizedBox(height: 16),
              const Text('الطلب', style: supportTitleStyle),
              AppFieldError(_errors['order']),
              const SizedBox(height: 8),
              if (widget.order != null)
                Text('طلب ${widget.order!.orderNumber}', style: supportTextStyle)
              else
                DropdownButtonFormField<String>(
                  value: _order?.id,
                  isExpanded: true,
                  hint: Text(_category == 'MONEY' ? 'اختياري: اختار الطلب' : 'اختار الطلب', style: supportMutedStyle),
                  items: [
                    for (final order in _orders)
                      DropdownMenuItem(
                        value: order.id,
                        child: Text('${order.orderNumber} • ${order.serviceTitle}',
                            style: supportTextStyle, overflow: TextOverflow.ellipsis,),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    _order = _orders.where((order) => order.id == id).firstOrNull;
                    _errors.remove('order');
                  }),
                ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 120,
              style: supportTextStyle,
              decoration: const InputDecoration(hintText: 'عنوان المشكلة', counterText: ''),
            ),
            AppFieldError(_errors['title']),
            const SizedBox(height: 10),
            TextField(
              controller: _body,
              maxLines: 6,
              maxLength: 4000,
              style: supportTextStyle,
              decoration: const InputDecoration(hintText: 'اكتب المشكلة بالتفصيل', counterText: ''),
            ),
            AppFieldError(_errors['body']),
            const SizedBox(height: 12),
            const Text('صور (اختياري، لحد 5)', style: supportMutedStyle),
            const SizedBox(height: 8),
            TicketImagePicker(paths: _images, onChanged: (paths) => setState(() => _images = paths)),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(_error!,
                    textAlign: TextAlign.center, style: supportTextStyle.copyWith(color: AppColors.danger),),
              ),
            AppButton.primary(text: 'إرسال التذكرة', isLoading: _isSending, onPressed: _isSending ? null : _send),
          ],
        ),
      ),
    );
  }
}
