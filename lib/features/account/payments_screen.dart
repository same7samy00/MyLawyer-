import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/invoice_pdf_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_message.dart';
import '../../core/widgets/app_skeleton.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/line_illustration.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/payment_record.dart';
import '../../data/repositories/order_repository.dart';

const _titleStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 14,
  fontWeight: FontWeight.w800,
  color: AppColors.dark,
);
const _mutedStyle = TextStyle(
  fontFamily: 'AppFont',
  fontFamilyFallback: appFontFallback,
  fontSize: 11.5,
  fontWeight: FontWeight.w600,
  color: AppColors.textMuted,
);

String _formatDate(DateTime? date) {
  if (date == null) return '';
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.day}/${date.month}/${date.year} - ${two(date.hour)}:${two(date.minute)}';
}

String _formatMoney(double value) => '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} ج.م';

/// صفحة المدفوعات في الحساب: كل دفعة بحالتها، وفاتورة PDF للدفعات اللي اتدفعت
class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<PaymentRecord>? _payments = OrderRepository.savedPayments();
  String? _error;
  String? _downloadingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await OrderRepository.getPayments();
    if (!mounted) return;
    setState(() {
      if (res.isOk) {
        _payments = res.data;
        _error = null;
      } else {
        _error = res.error;
      }
    });
  }

  Future<void> _downloadInvoice(PaymentRecord payment) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = payment.id);
    try {
      await InvoicePdfService.share(payment);
    } catch (_) {
      if (mounted) {
        showAppMessage(context, 
          const SnackBar(content: Text('تعذر تجهيز الفاتورة، جرب تاني'), backgroundColor: AppColors.dark),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = _payments;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'المدفوعات', isInnerPage: true),
      body: SafeArea(
        child: payments == null
            ? (_error == null
                ? const AppSkeletonList()
                : AppStateMessage(icon: Icons.wifi_off_rounded, title: 'تعذر تحميل المدفوعات', message: _error, onRetry: _load))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: payments.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 40),
                          LineIllustration(icon: Icons.receipt_long_rounded, height: 96),
                          SizedBox(height: 14),
                          Text('مفيش مدفوعات لسه', textAlign: TextAlign.center, style: _titleStyle),
                          SizedBox(height: 4),
                          Text('أول ما تدفع لطلب هتلاقي الدفعة وفاتورتها هنا', textAlign: TextAlign.center, style: _mutedStyle),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: payments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final payment = payments[index];
                          return _PaymentCard(
                            payment: payment,
                            isDownloading: _downloadingId == payment.id,
                            onInvoice: payment.hasInvoice ? () => _downloadInvoice(payment) : null,
                          );
                        },
                      ),
              ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentRecord payment;
  final bool isDownloading;
  final VoidCallback? onInvoice;

  const _PaymentCard({required this.payment, required this.isDownloading, required this.onInvoice});

  StatusBadgeType get _badgeType => switch (payment.status) {
        'FAILED' => StatusBadgeType.danger,
        'REFUNDED' || 'PARTLY_REFUNDED' => StatusBadgeType.warning,
        _ => StatusBadgeType.success,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(payment.service, style: _titleStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              StatusBadge(text: payment.statusLabel, type: _badgeType),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (payment.orderNumber != null) Text('طلب ${payment.orderNumber}', style: _mutedStyle),
                    Text('${payment.methodLabel} • ${_formatDate(payment.at)}', style: _mutedStyle),
                    if (payment.isFailed && payment.reason != null)
                      Text(payment.reason!, style: _mutedStyle.copyWith(color: AppColors.danger)),
                    if (payment.refunded > 0 && !payment.isFailed)
                      Text('رجعلك ${_formatMoney(payment.refunded)}', style: _mutedStyle.copyWith(color: AppColors.success)),
                  ],
                ),
              ),
              Text(
                _formatMoney(payment.amount),
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: payment.isFailed ? AppColors.textMuted : AppColors.dark,
                  decoration: payment.isFailed ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          if (onInvoice != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.cardBorder),
            InkWell(
              onTap: isDownloading ? null : onInvoice,
              borderRadius: BorderRadius.circular(7),
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDownloading)
                      const AppLoader.inline(size: 16)
                    else
                      const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'تحميل الفاتورة PDF',
                      style: _mutedStyle.copyWith(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
