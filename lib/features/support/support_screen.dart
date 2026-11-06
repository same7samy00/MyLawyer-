import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_state_message.dart';
import '../../data/models/support_ticket.dart';
import '../../data/repositories/support_repository.dart';
import 'new_ticket_screen.dart';
import 'support_widgets.dart';
import 'ticket_details_screen.dart';

/// صفحة الدعم الفني: تذكرة جديدة، وتحتها كل تذاكري بالعنوان والرقم والحالة
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<SupportTicket>? _tickets = SupportRepository.savedTickets();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await SupportRepository.getTickets();
    if (!mounted) return;
    setState(() {
      if (res.isOk) {
        _tickets = res.data;
        _error = null;
      } else {
        _error = res.error;
      }
    });
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tickets = _tickets;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'الدعم الفني', isInnerPage: true),
      body: SafeArea(
        child: tickets == null
            ? (_error == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : AppStateMessage(icon: Icons.wifi_off_rounded, title: 'تعذر تحميل التذاكر', message: _error, onRetry: _load))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // A ticket under review waits for the admin before anything new goes out
                    if (tickets.any((ticket) => ticket.isUnderReview))
                      const Text('عندك تذكرة تحت المراجعة، تقدر تفتح تذكرة جديدة بعد رد الإدارة',
                          textAlign: TextAlign.center, style: supportMutedStyle)
                    else
                      AppButton.primary(
                        text: 'تذكرة جديدة',
                        icon: Icons.add_rounded,
                        onPressed: () => _open(const NewTicketScreen()),
                      ),
                    const SizedBox(height: 16),
                    if (tickets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Text('مفيش تذاكر لسه، ولو عندك أي مشكلة افتح تذكرة والإدارة هترد عليك',
                            textAlign: TextAlign.center, style: supportMutedStyle),
                      ),
                    for (final ticket in tickets) _TicketCard(ticket: ticket, onTap: () => _open(TicketDetailsScreen(ticketId: ticket.id))),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(ticket.title, style: supportTitleStyle, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                TicketStatusBadge(ticket),
              ],
            ),
            const SizedBox(height: 6),
            Text(ticket.reference, style: supportMutedStyle),
            if (ticket.orderNumber != null) Text('طلب ${ticket.orderNumber}', style: supportMutedStyle),
            Text('${ticket.categoryLabel} • ${formatTicketDate(ticket.updatedAt)}', style: supportMutedStyle),
          ],
        ),
      ),
    );
  }
}
