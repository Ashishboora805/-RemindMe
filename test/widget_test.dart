import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_notes/core/widgets/glass_button.dart';
import 'package:glass_notes/core/widgets/glass_card.dart';
import 'package:glass_notes/core/widgets/glass_text_field.dart';

/// Widget tests for the shared glass components. The feature screens all read
/// from AppDatabase (which needs a real sqlite3 native library), so they are
/// covered by the service/database unit tests instead; these cover the design
/// system pieces that every screen is built from.
void main() {
  Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
    return CupertinoApp(
      theme: CupertinoThemeData(brightness: brightness),
      home: CupertinoPageScaffold(child: Center(child: child)),
    );
  }

  testWidgets('GlassCard renders its child and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(wrap(
      GlassCard(onTap: () => taps++, child: const Text('Card body')),
    ));

    expect(find.text('Card body'), findsOneWidget);
    await tester.tap(find.text('Card body'));
    expect(taps, 1);
  });

  testWidgets('GlassCard renders in dark mode without throwing',
      (tester) async {
    await tester.pumpWidget(wrap(
      const GlassCard(child: Text('Dark')),
      brightness: Brightness.dark,
    ));
    expect(tester.takeException(), isNull);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('GlassButton invokes onPressed', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(wrap(
      GlassButton(label: 'Save', onPressed: () => pressed++),
    ));

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });

  testWidgets('GlassButton with a null onPressed ignores taps', (tester) async {
    await tester.pumpWidget(wrap(
      const GlassButton(label: 'Disabled', onPressed: null),
    ));

    await tester.tap(find.text('Disabled'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GlassTextField reports changes through its controller',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    String? lastChange;

    await tester.pumpWidget(wrap(
      GlassTextField(
        controller: controller,
        placeholder: 'Title',
        onChanged: (v) => lastChange = v,
      ),
    ));

    expect(find.text('Title'), findsOneWidget);
    await tester.enterText(find.byType(CupertinoTextField), 'Groceries');
    expect(controller.text, 'Groceries');
    expect(lastChange, 'Groceries');
  });
}
