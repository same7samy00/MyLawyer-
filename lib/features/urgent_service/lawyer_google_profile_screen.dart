import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_header.dart';
import '../../core/widgets/app_loader.dart';
import '../../core/widgets/app_pressable.dart';
import '../../data/models/map_lawyer.dart';

/// شاشة عرض بروفايل ملف جوجل المعتمد للمحامي عبر WebView
class LawyerGoogleProfileScreen extends StatefulWidget {
  final MapLawyer lawyer;

  const LawyerGoogleProfileScreen({
    super.key,
    required this.lawyer,
  });

  @override
  State<LawyerGoogleProfileScreen> createState() => _LawyerGoogleProfileScreenState();
}

class _LawyerGoogleProfileScreenState extends State<LawyerGoogleProfileScreen> {
  late final WebViewController _controller;
  int _loadingProgress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    _hasError = false;
    _loadingProgress = 0;

    final targetUrl = widget.lawyer.effectiveGoogleProfileUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            // تجاهل أخطاء الروابط الفرعية أو الإعلانات غير المؤثرة
            if (error.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                });
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(targetUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _controller.canGoBack()) {
          await _controller.goBack();
        } else {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AppHeader(
          title: 'ملف Google والتقييمات',
          isInnerPage: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // شريط معلومات المحامي المعتمد بأعلى الصفحة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: AppColors.cardBorder, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    // شارة التوثيق
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(7.0),
                      ),
                      child: const Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // تفاصيل المحامي
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.lawyer.name,
                            style: const TextStyle(
                              fontFamily: 'AppFont',
                              fontFamilyFallback: appFontFallback,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.dark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 15),
                              const SizedBox(width: 3),
                              Text(
                                '${widget.lawyer.rating}',
                                style: const TextStyle(
                                  fontFamily: 'AppFont',
                                  fontFamilyFallback: appFontFallback,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dark,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '(${widget.lawyer.reviewsCount} تقييم على Google)',
                                style: const TextStyle(
                                  fontFamily: 'AppFont',
                                  fontFamilyFallback: appFontFallback,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // زر إعادة التحميل
                    AppPressable(
                      child: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 22),
                      tooltip: 'إعادة تحميل الصفحة',
                      onPressed: () {
                        _controller.reload();
                      },
                    ),
                    ),
                  ],
                ),
              ),

              // مؤشر التقدم الأفقي أثناء التحميل
              if (_loadingProgress < 100 && !_hasError)
                LinearProgressIndicator(
                  value: _loadingProgress / 100.0,
                  backgroundColor: AppColors.cardBorder,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 2.5,
                ),

              // محتوى WebView أو شاشة الخطأ
              Expanded(
                child: _hasError
                    ? _buildErrorView()
                    : Stack(
                        children: [
                          WebViewWidget(controller: _controller),
                          if (_loadingProgress < 60)
                            const Center(child: AppLoader()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'تعذر تحميل صفحة Google حالياً',
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'يرجى التأكد من اتصال الإنترنت ثم المحاولة مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'AppFont',
                fontFamilyFallback: appFontFallback,
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            AppPressable(
              child: ElevatedButton.icon(
              onPressed: _initWebViewController,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
