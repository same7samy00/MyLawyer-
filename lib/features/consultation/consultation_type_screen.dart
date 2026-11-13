import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/line_illustration.dart';
import '../../data/models/consultation.dart';
import 'consultation_style.dart';
import 'mahamiho_request_screen.dart';

/// «استشارة سريعة»، الخطوة 1: نوع الاستشارة.
/// بعدها: محاميحو (كلام أو كتابة) والورق ← تقييم السعر ← الملخص والشروط ← صفحات الدفع المشتركة مع «محاميك حالاً»
class QuickConsultationScreen extends StatelessWidget {
  const QuickConsultationScreen({super.key});

  void _choose(BuildContext context, ConsultationKind kind) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MahamihoRequestScreen(kind: kind, serviceTitle: kind.serviceName)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'استشارة سريعة', isInnerPage: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: LineIllustration(icon: Icons.support_agent_rounded, height: 90)),
              const SizedBox(height: 10),
              Text('اختار نوع الاستشارة', textAlign: TextAlign.center, style: consultationText(18, FontWeight.w900, AppColors.dark)),
              const SizedBox(height: 6),
              Text(
                'فريقنا القانوني هيكلمك على تليفونك\nخلال دقايق من الدفع',
                textAlign: TextAlign.center,
                style: consultationText(13, FontWeight.w600, AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 22),
              _TypeCard(
                icon: Icons.call_rounded,
                title: ConsultationKind.call.label,
                subtitle: 'تحكي مشكلتك والمستشار يرد عليك\nفي مكالمة تليفون',
                onTap: () => _choose(context, ConsultationKind.call),
              ),
              const SizedBox(height: 12),
              _TypeCard(
                icon: Icons.description_rounded,
                title: ConsultationKind.papers.label,
                subtitle: 'ترفع صور الورق ونراجعها\nوبعدها نكلمك بالرأي القانوني',
                onTap: () => _choose(context, ConsultationKind.papers),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TypeCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(7.0)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: consultationText(15, FontWeight.w800, AppColors.dark)),
                const SizedBox(height: 4),
                Text(subtitle, style: consultationText(12, FontWeight.w600, AppColors.textMuted, height: 1.5)),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_left_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
