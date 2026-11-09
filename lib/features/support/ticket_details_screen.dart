import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_state_message.dart';
import '../../core/widgets/top_message.dart';
import '../../data/models/support_ticket.dart';
import '../../data/repositories/support_repository.dart';
import 'support_widgets.dart';

/// التذكرة: رسايلي وردود الإدارة بالترتيب، وخانة رد لحد ما الإدارة تقفلها
class TicketDetailsScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailsScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailsScreen> createState() => _TicketDetailsScreenState();
}

class _TicketDetailsScreenState extends State<TicketDetailsScreen> {
  final _reply = TextEditingController();
  SupportTicket? _ticket;
  Map<String, String> _imageHeaders = const {};
  List<String> _images = const [];
  String? _error;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([SupportRepository.getTicket(widget.ticketId), ApiService.imageHeaders()]);
    if (!mounted) return;
    final res = results[0] as ApiResponse<SupportTicket>;
    setState(() {
      _imageHeaders = results[1] as Map<String, String>;
      if (res.isOk) {
        _ticket = res.data;
        _error = null;
      } else {
        _error = res.error;
      }
    });
  }

  Future<void> _send() async {
    if (_reply.text.trim().isEmpty && _images.isEmpty) return;
    setState(() => _isSending = true);
    final res = await SupportRepository.reply(widget.ticketId, _reply.text.trim(), imagePaths: _images);
    if (!mounted) return;

    setState(() => _isSending = false);
    if (res.isOk) {
      _reply.clear();
      setState(() => _images = const []);
      await _load();
    } else {
      showTopMessage(context, 
        SnackBar(content: Text(res.error ?? 'تعذر إرسال ردك'), backgroundColor: AppColors.danger),
      );
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHeader(title: ticket?.reference ?? 'التذكرة', isInnerPage: true),
      body: SafeArea(
        child: ticket == null
            ? (_error == null
                ? const Center(child: AppLoader())
                : AppStateMessage(icon: Icons.wifi_off_rounded, title: 'تعذر تحميل التذكرة', message: _error, onRetry: _load))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(ticket.title, style: supportTitleStyle)),
                              TicketStatusBadge(ticket),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(ticket.categoryLabel, style: supportMutedStyle),
                          if (ticket.orderNumber != null) Text('طلب ${ticket.orderNumber}', style: supportMutedStyle),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final message in ticket.messages) _MessageCard(message: message, imageHeaders: _imageHeaders),
                    const SizedBox(height: 8),
                    if (ticket.isClosed)
                      const AppCard(
                        padding: EdgeInsets.all(14),
                        child: Text('التذكرة دي اتقفلت، لو عندك مشكلة جديدة افتح تذكرة جديدة',
                            textAlign: TextAlign.center, style: supportMutedStyle,),
                      )
                    // After each message the sender waits for the admin before writing again
                    else if (ticket.awaitingReply)
                      const AppCard(
                        padding: EdgeInsets.all(14),
                        child: Text('رسالتك وصلت، استنى رد الإدارة وبعدها تقدر ترد',
                            textAlign: TextAlign.center, style: supportMutedStyle,),
                      )
                    else ...[
                      TextField(
                        controller: _reply,
                        maxLines: 4,
                        maxLength: 4000,
                        style: supportTextStyle,
                        decoration: const InputDecoration(hintText: 'اكتب ردك', counterText: ''),
                      ),
                      const SizedBox(height: 8),
                      TicketImagePicker(paths: _images, onChanged: (paths) => setState(() => _images = paths)),
                      const SizedBox(height: 12),
                      AppButton.primary(text: 'إرسال الرد', isLoading: _isSending, onPressed: _isSending ? null : _send),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final TicketMessage message;
  final Map<String, String> imageHeaders;

  const _MessageCard({required this.message, required this.imageHeaders});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        backgroundColor: message.fromSupport ? AppColors.primaryLight : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(message.fromSupport ? 'الدعم الفني' : 'انت',
                    style: supportTitleStyle.copyWith(fontSize: 13, color: message.fromSupport ? AppColors.primary : AppColors.dark),),
                const Spacer(),
                Text(formatTicketDate(message.createdAt), style: supportMutedStyle),
              ],
            ),
            if (message.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message.body, style: supportTextStyle),
            ],
            if (message.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final url in message.imageUrls)
                    GestureDetector(
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7.0)),
                          child: InteractiveViewer(child: Image.network(url, headers: imageHeaders)),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7.0),
                        child: Image.network(url, headers: imageHeaders, width: 80, height: 80, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80, child: Icon(Icons.broken_image_outlined)),),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
