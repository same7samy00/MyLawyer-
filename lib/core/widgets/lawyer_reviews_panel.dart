import 'package:flutter/material.dart';
import '../../data/models/lifecycle_models.dart';
import '../../data/repositories/lawyer_repository.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';
import 'app_state_message.dart';
import 'order_action_sheets.dart';
import 'review_card.dart';

/// تقييمات وتعليقات المحامي داخل البوتن شيت الموسّع
class LawyerReviewsPanel extends StatefulWidget {
  final String lawyerId;
  final VoidCallback onClose;

  /// المحامي بيشوف تقييماته ويقدر يبلغ عن أي تعليق
  final bool canReport;

  const LawyerReviewsPanel({super.key, required this.lawyerId, required this.onClose, this.canReport = false});

  @override
  State<LawyerReviewsPanel> createState() => _LawyerReviewsPanelState();
}

class _LawyerReviewsPanelState extends State<LawyerReviewsPanel> {
  bool _isLoading = true;
  String? _error;
  List<LawyerReview> _reviews = const [];
  final Set<String> _reported = {};

  Future<void> _report(LawyerReview review) async {
    final sent = await OrderActionSheets.reportReview(
      context,
      onSubmit: (reason) => LawyerRepository.reportReview(review.id, reason),
    );
    if (sent && mounted) setState(() => _reported.add(review.id));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await LawyerRepository.getReviews(widget.lawyerId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _reviews = res.data ?? const [];
      _error = res.isOk ? null : res.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildBody()),
        const SizedBox(height: 10),
        AppButton.outlined(text: 'رجوع لملف المحامي', height: 46, onPressed: widget.onClose),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_error != null) {
      return AppStateMessage(icon: Icons.wifi_off_rounded, title: 'تعذر تحميل التقييمات', message: _error);
    }

    if (_reviews.isEmpty) {
      return const AppStateMessage(icon: Icons.star_border_rounded, title: 'لسه مفيش تقييمات');
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return ReviewCard(
          review: review,
          isReported: _reported.contains(review.id),
          onReport: widget.canReport ? () => _report(review) : null,
        );
      },
    );
  }
}
