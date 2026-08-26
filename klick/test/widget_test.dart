import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:klick/controllers/klick_controller.dart';
import 'package:klick/main.dart';

void main() {
  testWidgets('Streamlined Klick Bluetooth messaging app test', (WidgetTester tester) async {
    // 1. Launch App directly to Messages
    await tester.pumpWidget(const KlickApp());
    await tester.pumpAndSettle();

    // Verify Messages Header and Contacts
    expect(find.text('MESSAGES'), findsOneWidget);
    expect(find.text('Alex (Phone)'), findsOneWidget);
    expect(find.text('Maya (Laptop)'), findsOneWidget);

    // 2. Tap to open chat with Alex
    await tester.tap(find.text('Alex (Phone)'));
    await tester.pumpAndSettle();

    // Verify Chat Screen
    expect(find.text('Alex (Phone)'), findsWidgets);
    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('Type message...'), findsOneWidget);
    expect(find.text('SEND'), findsOneWidget);

    // 3. Send a message using on-screen input
    await tester.enterText(find.byType(TextField), 'Hello from Klick!');
    await tester.tap(find.text('SEND'));
    await tester.pump();

    // Verify sent message appears
    expect(find.text('Hello from Klick!'), findsOneWidget);

    // Fast-forward to receive simulated Bluetooth reply
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pumpAndSettle();

    // 4. Navigate back to Messages List
    await tester.tap(find.text('◄'));
    await tester.pumpAndSettle();
    expect(find.text('MESSAGES'), findsOneWidget);

    // 5. Open Bluetooth Scanner
    await tester.tap(find.text('SCAN').first);
    await tester.pumpAndSettle();
    expect(find.text('NEARBY DEVICES'), findsOneWidget);

    // Fast forward scan
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    expect(find.text('Sarah (Pixel 8)'), findsOneWidget);

    // Connect to discovered device
    await tester.tap(find.text('CONNECT').first);
    await tester.pumpAndSettle();

    // Verify newly paired chat is open
    expect(find.text('Sarah (Pixel 8)'), findsWidgets);
  });

  test('KlickController direct messaging unit test', () {
    final controller = KlickController();

    expect(controller.currentScreen, KlickScreen.chats);
    expect(controller.devices.isNotEmpty, isTrue);

    final device = controller.devices.first;
    controller.sendDirectMessage(device, 'Bluetooth packet test');
    final msgs = controller.conversationMessages[device.id]!;
    expect(msgs.any((m) => m.text == 'Bluetooth packet test'), isTrue);

    controller.dispose();
  });
}
