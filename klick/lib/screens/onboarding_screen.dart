import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../controllers/klick_controller.dart';
import '../theme/bit_mechanical_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final KlickController controller;

  const OnboardingScreen({super.key, required this.controller});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      badge: 'OFFLINE P2P',
      title: 'OFFLINE MESSAGING',
      description: 'Send messages to nearby devices without cellular data, internet access, or Wi-Fi routers. Direct radio connection.',
      svgAsset: 'lib/assets/svgIllustrations/undraw_messaging-app_wfqi.svg',
    ),
    _OnboardingItem(
      badge: 'DISCOVERY',
      title: 'FAST ZERO-CONFIG PAIRING',
      description: 'Scan nearby Bluetooth radios in seconds. Pair with one tap and start real-time two-way chat immediately.',
      svgAsset: 'lib/assets/svgIllustrations/undraw_chatting_5u5z.svg',
    ),
    _OnboardingItem(
      badge: 'PRIVACY',
      title: 'DIRECT & DECENTRALIZED',
      description: 'Zero cloud servers, zero tracking. Your conversations stay strictly between your hardware and your peer.',
      svgAsset: 'lib/assets/svgIllustrations/undraw_work-chat_kw8x.svg',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      widget.controller.completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BitMechanicalTheme.hardwareBody,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Top Bar: Brand Logo & Skip Button
              _buildTopBar(),

              const SizedBox(height: 12),

              // Middle: PageView with Illustrations and Content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildPageContent(_pages[index]);
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Section: Progress Indicators + Next / Get Started Button
              _buildBottomControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Title with Bit-Mechanical styling
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'lib/assets/icons/KlickICON.jpg',
                width: 22,
                height: 22,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: BitMechanicalTheme.primaryAmber,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'K',
                    style: BitMechanicalTheme.headlineMono(
                      color: const Color(0xFF111111),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'KLICK // COMMUNICATOR',
              style: BitMechanicalTheme.statusPixel(
                color: BitMechanicalTheme.outline,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),

        // Skip Button
        if (_currentPage < _pages.length - 1)
          GestureDetector(
            onTap: widget.controller.completeOnboarding,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: BitMechanicalTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: BitMechanicalTheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Text(
                'SKIP',
                style: BitMechanicalTheme.statusPixel(
                  color: BitMechanicalTheme.outline,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildPageContent(_OnboardingItem item) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // SVG Illustration inside dark retro container
                  Container(
                    width: double.infinity,
                    height: (constraints.maxHeight * 0.48).clamp(180.0, 260.0),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181818),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: BitMechanicalTheme.surfaceContainerHigh,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          offset: Offset(0, 4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(item.svgAsset, fit: BoxFit.contain),
                  ),

                  const SizedBox(height: 24),

                  // Step Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: BitMechanicalTheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: BitMechanicalTheme.primaryAmber.withValues(
                          alpha: 0.4,
                        ),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      item.badge,
                      style: BitMechanicalTheme.statusPixel(
                        color: BitMechanicalTheme.primaryAmber,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Title
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.headlineMono(
                      color: const Color(0xFFF5F5F5),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      item.description,
                      textAlign: TextAlign.center,
                      style: BitMechanicalTheme.bodyMono(
                        color: const Color(0xFFAAAAAA),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomControls() {
    final isLastPage = _currentPage == _pages.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Segmented Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_pages.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 24 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: isActive
                    ? BitMechanicalTheme.primaryAmber
                    : BitMechanicalTheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isActive
                      ? BitMechanicalTheme.primaryAmber
                      : BitMechanicalTheme.outlineVariant,
                  width: 0.8,
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 18),

        // Action Button (Next / Get Started)
        GestureDetector(
          onTap: _onNext,
          child: Container(
            width: double.infinity,
            height: 48,
            decoration: BoxDecoration(
              color: BitMechanicalTheme.primaryAmber,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x99000000),
                  offset: Offset(0, 3),
                  blurRadius: 4,
                ),
                BoxShadow(
                  color: Color(0x40FFFFFF),
                  offset: Offset(0, -1),
                  blurRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'LAUNCH KLICK' : 'CONTINUE',
                    style: BitMechanicalTheme.headlineMono(
                      color: const Color(0xFF111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLastPage
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                    color: const Color(0xFF111111),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingItem {
  final String badge;
  final String title;
  final String description;
  final String svgAsset;

  const _OnboardingItem({
    required this.badge,
    required this.title,
    required this.description,
    required this.svgAsset,
  });
}
