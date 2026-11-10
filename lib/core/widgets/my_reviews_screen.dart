import 'package:flutter/material.dart';

import '../../data/repositories/profile_repository.dart';
import '../constants/app_colors.dart';
import 'app_header.dart';
import 'lawyer_reviews_panel.dart';

/// «تقييماتي»: تقييمات المحامي وتعليقاتها، من الحساب ومن إشعار «تقييم جديد»
class MyReviewsScreen extends StatelessWidget {
  final String lawyerId;

  const MyReviewsScreen({super.key, required this.lawyerId});

  /// بيفتح تقييمات المحامي اللي داخل دلوقتي
  static Future<bool> openForMe(BuildContext context) async {
    final navigator = Navigator.of(context);
    final userId = (ProfileRepository.saved ?? (await ProfileRepository.me()).data as Map<String, dynamic>?)?['id']?.toString();
    if (userId == null) return false;
    await navigator.push(MaterialPageRoute<void>(builder: (_) => MyReviewsScreen(lawyerId: userId)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AppHeader(title: 'تقييماتي', isInnerPage: true, showNotifications: false),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: LawyerReviewsPanel(lawyerId: lawyerId, canReport: true, onClose: () => Navigator.of(context).pop()),
      ),
    );
  }
}
