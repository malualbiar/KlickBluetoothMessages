import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/klick_controller.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/bit_mechanical_theme.dart';
import 'widgets/hardware_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KlickApp());
}

class KlickApp extends StatelessWidget {
  final KlickController? controller;
  final bool showSplash;

  const KlickApp({super.key, this.controller, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KLICK // Bluetooth Communicator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BitMechanicalTheme.surfaceContainerLowest,
        colorScheme: const ColorScheme.dark(
          primary: BitMechanicalTheme.primaryAmber,
          surface: BitMechanicalTheme.hardwareBody,
        ),
      ),
      home: KlickMainScreen(controller: controller, showSplash: showSplash),
    );
  }
}

class KlickMainScreen extends StatefulWidget {
  final KlickController? controller;
  final bool showSplash;

  const KlickMainScreen({super.key, this.controller, this.showSplash = true});

  @override
  State<KlickMainScreen> createState() => _KlickMainScreenState();
}

class _KlickMainScreenState extends State<KlickMainScreen>
    with WidgetsBindingObserver {
  late final KlickController _controller;
  bool _isExternalController = false;
  late bool _isSplashLoaded;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isSplashLoaded = !widget.showSplash;
    _isExternalController = widget.controller != null;
    _controller = widget.controller ?? KlickController();
    _controller.addListener(_onControllerUpdate);

    // Register physical hardware keyboard listener
    HardwareKeyboard.instance.addHandler(_handlePhysicalKeyEvent);

    // Register for app lifecycle events (background/foreground)
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called by Android/iOS when the app lifecycle state changes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _controller.handleAppLifecycleState(state);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _handlePhysicalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      final focusNode = FocusManager.instance.primaryFocus;
      final isTextInputFocused = focusNode != null &&
          focusNode is! FocusScopeNode &&
          (focusNode.context?.findAncestorWidgetOfExactType<EditableText>() != null ||
              focusNode.context?.widget is EditableText);

      // If user is currently focused in a text field, let the text field handle all typing
      if (isTextInputFocused) {
        if (key == LogicalKeyboardKey.escape) {
          focusNode.unfocus();
          return true;
        }
        return false;
      }

      // Hardware navigation when not typing in a text field
      if (key == LogicalKeyboardKey.arrowUp) {
        _controller.handleKeyPress('UP');
        return true;
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _controller.handleKeyPress('DOWN');
        return true;
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _controller.handleKeyPress('LEFT');
        return true;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _controller.handleKeyPress('RIGHT');
        return true;
      } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
        _controller.handleKeyPress('ENTER');
        return true;
      } else if (key == LogicalKeyboardKey.escape) {
        _controller.handleKeyPress('ESC');
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HardwareKeyboard.instance.removeHandler(_handlePhysicalKeyEvent);
    _controller.removeListener(_onControllerUpdate);
    if (!_isExternalController) {
      _controller.dispose();
    }
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSplashLoaded) {
      return Scaffold(
        backgroundColor: BitMechanicalTheme.surfaceContainerLowest,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SplashScreen(
                controller: _controller,
                onLoaded: () {
                  if (mounted) {
                    setState(() => _isSplashLoaded = true);
                  }
                },
              ),
            ),
          ),
        ),
      );
    }

    if (!_controller.isOnboardingComplete) {
      return Scaffold(
        backgroundColor: BitMechanicalTheme.hardwareBody,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: OnboardingScreen(controller: _controller),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: BitMechanicalTheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: HardwareShell(controller: _controller),
          ),
        ),
      ),
    );
  }
}
