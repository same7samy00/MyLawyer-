import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'app_pressable.dart';

class AppBottomBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final ValueListenable<int>? ordersBadge;

  const AppBottomBar({
    super.key,
    required this.activeIndex,
    required this.onTabSelected,
    this.ordersBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 1. الرئيسية
            Expanded(
              child: _buildBottomTab(
                index: 0,
                label: 'الرئيسية',
                icon: Icons.home_rounded,
                isActive: activeIndex == 0,
              ),
            ),

            // 2. الطلبات
            Expanded(
              child: _buildBottomTab(
                index: 1,
                label: 'الطلبات',
                icon: Icons.receipt_long_rounded,
                isActive: activeIndex == 1,
                badge: ordersBadge,
              ),
            ),

            // 3. المحفظة
            Expanded(
              child: _buildBottomTab(
                index: 2,
                label: 'المحفظة',
                icon: Icons.account_balance_wallet_rounded,
                isActive: activeIndex == 2,
              ),
            ),

            // 4. الحساب
            Expanded(
              child: _buildBottomTab(
                index: 3,
                label: 'الحساب',
                icon: Icons.person_rounded,
                isActive: activeIndex == 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomTab({
    required int index,
    required String label,
    required IconData icon,
    required bool isActive,
    ValueListenable<int>? badge,
  }) {
    final color = isActive ? AppColors.primary : AppColors.textMuted;

    return AppPressable(
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: BorderRadius.circular(12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 23, color: color),
                  if (badge != null)
                    Positioned(
                      top: -6,
                      left: -10,
                      child: ValueListenableBuilder<int>(
                        valueListenable: badge,
                        builder: (context, count, child) => count > 0 ? _CountBadge(count: count) : const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'AppFont',
                  fontFamilyFallback: appFontFallback,
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(9.0),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'AppFont',
          fontFamilyFallback: appFontFallback,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
