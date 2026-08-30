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
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  int _currentPage = 0;
  String? _nameError;

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
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    final name = _nameController.text.trim();

    // Name is mandatory — cannot skip or proceed without it
    if (name.isEmpty) {
      setState(() => _nameError = 'YOU MUST ENTER A CALLSIGN TO CONTINUE');
      // Jump to the callsign form page if not already there
      if (_currentPage < _pages.length) {
        _pageController.animateToPage(
          _pages.length,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
      _nameFocusNode.requestFocus();
      return;
    }

    setState(() => _nameError = null);
    widget.controller.completeOnboarding(userName: name);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _pages.length + 1; // 3 info pages + 1 callsign form page

    return Scaffold(
      backgroundColor: BitMechanicalTheme.hardwareBody,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Top Bar: Brand Logo & Skip Button
              _buildTopBar(totalPages),

              const SizedBox(height: 12),

              // Middle: PageView with Illustrations and Username Form
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: totalPages,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                    if (index == _pages.length) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        if (mounted) _nameFocusNode.requestFocus();
                      });
                    }
                  },
                  itemBuilder: (context, index) {
                    if (index < _pages.length) {
                      return _buildPageContent(_pages[index]);
                    } else {
                      return _buildUsernameFormPage();
                    }
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Bottom Section: Progress Indicators + Action Button
              _buildBottomControls(totalPages),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Title with Bit-Mechanical styling
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/icons/KlickIcon.jpg',
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

        // No skip — name is required
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

  Widget _buildUsernameFormPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Hardware Terminal Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: BitMechanicalTheme.hardwareBody,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: BitMechanicalTheme.primaryAmber,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BitMechanicalTheme.primaryAmber.withValues(alpha: 0.3),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'assets/icons/KlickIcon.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person_pin,
                          color: BitMechanicalTheme.primaryAmber,
                          size: 40,
                        ),
                      ),
                    ),
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
                      '// 04 // CALLSIGN',
                      style: BitMechanicalTheme.statusPixel(
                        color: BitMechanicalTheme.primaryAmber,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'CHOOSE YOUR CALLSIGN',
                    textAlign: TextAlign.center,
                    style: BitMechanicalTheme.headlineMono(
                      color: const Color(0xFFF5F5F5),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Enter your radio name. Nearby devices will see this name during Bluetooth discovery.',
                      textAlign: TextAlign.center,
                      style: BitMechanicalTheme.bodyMono(
                        color: const Color(0xFFAAAAAA),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Callsign input field
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _nameError != null
                                  ? const Color(0xFFFF4444)
                                  : BitMechanicalTheme.primaryAmber,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_nameError != null
                                        ? const Color(0xFFFF4444)
                                        : BitMechanicalTheme.primaryAmber)
                                    .withValues(alpha: 0.18),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '> ',
                                style: BitMechanicalTheme.headlineMono(
                                  color: _nameError != null
                                      ? const Color(0xFFFF4444)
                                      : BitMechanicalTheme.primaryAmber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  autofocus: true,
                                  style: BitMechanicalTheme.headlineMono(
                                    color: const Color(0xFFF5F5F5),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(
                                    hintText: 'E.G. MAVERICK, NOVA',
                                    hintStyle: BitMechanicalTheme.headlineMono(
                                      color: BitMechanicalTheme.outlineVariant,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  onChanged: (_) {
                                    if (_nameError != null) {
                                      setState(() => _nameError = null);
                                    }
                                  },
                                  onSubmitted: (_) => _finishOnboarding(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Error message shown when name is empty on submit
                        if (_nameError != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.error_outline, size: 12, color: Color(0xFFFF4444)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _nameError!,
                                  style: BitMechanicalTheme.statusPixel(
                                    color: const Color(0xFFFF4444),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
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

  Widget _buildBottomControls(int totalPages) {
    final isLastPage = _currentPage == totalPages - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Segmented Page Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(totalPages, (index) {
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

        // Action Button (Next / Launch Klick)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _nameController,
          builder: (context, value, _) {
            final nameEntered = value.text.trim().isNotEmpty;
            final isEnabled = !isLastPage || nameEntered;
            return GestureDetector(
              onTap: isLastPage ? _finishOnboarding : _onNext,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: isEnabled
                      ? BitMechanicalTheme.primaryAmber
                      : BitMechanicalTheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: isEnabled
                      ? null
                      : Border.all(
                          color: BitMechanicalTheme.outlineVariant,
                          width: 1,
                        ),
                  boxShadow: isEnabled
                      ? const [
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
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastPage ? 'LAUNCH KLICK' : 'CONTINUE',
                        style: BitMechanicalTheme.headlineMono(
                          color: isEnabled
                              ? const Color(0xFF111111)
                              : BitMechanicalTheme.outlineVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastPage ? Icons.power_settings_new : Icons.arrow_forward,
                        color: isEnabled
                            ? const Color(0xFF111111)
                            : BitMechanicalTheme.outlineVariant,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
