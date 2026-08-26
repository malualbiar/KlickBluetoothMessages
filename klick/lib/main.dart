import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/klick_controller.dart';
import 'theme/bit_mechanical_theme.dart';
import 'widgets/hardware_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KlickApp());
}

class KlickApp extends StatelessWidget {
  const KlickApp({super.key});

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
      home: const KlickMainScreen(),
    );
  }
}

class KlickMainScreen extends StatefulWidget {
  const KlickMainScreen({super.key});

  @override
  State<KlickMainScreen> createState() => _KlickMainScreenState();
}

class _KlickMainScreenState extends State<KlickMainScreen> {
  late final KlickController _controller;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = KlickController();
    _controller.addListener(_onControllerUpdate);

    // Register physical hardware keyboard listener
    HardwareKeyboard.instance.addHandler(_handlePhysicalKeyEvent);
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _handlePhysicalKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;

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
      } else if (key == LogicalKeyboardKey.backspace) {
        _controller.handleKeyPress('<-');
        return true;
      } else if (key == LogicalKeyboardKey.space) {
        _controller.handleKeyPress(' ');
        return true;
      } else if (event.character != null && event.character!.isNotEmpty) {
        final char = event.character!;
        if (RegExp(r'^[a-zA-Z0-9.,!?:;@#\-_/]$').hasMatch(char)) {
          _controller.handleKeyPress(char.toUpperCase());
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handlePhysicalKeyEvent);
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BitMechanicalTheme.hardwareBody,
      body: SafeArea(
        child: HardwareShell(controller: _controller),
      ),
    );
  }
}
