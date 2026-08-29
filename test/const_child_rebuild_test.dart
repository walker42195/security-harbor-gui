import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Dokumenterar VARFÖR skärmarna i main_screen.dart inte får skapas som const.
///
/// En const-widget är kanoniserad: vid varje omritning är det exakt samma
/// instans, och Flutters Element.updateChild kortsluter då på
/// `child.widget == newWidget` och bygger ALDRIG om subträdet. En vy som läser
/// global state i sin build() (som temaväljaren läser AppTheme.mode) fryser
/// därmed fast på det värde som gällde när den monterades.
///
/// Det var orsaken till att temaväljaren i Inställningar bytte tema men inte
/// flyttade sin markering (rapporterat 2026-08-29).

String globalValue = 'A';

class _Child extends StatelessWidget {
  const _Child();
  @override
  Widget build(BuildContext context) =>
      Directionality(textDirection: TextDirection.ltr, child: Text(globalValue));
}

class _Parent extends StatefulWidget {
  const _Parent({required this.useConst});
  final bool useConst;
  @override
  State<_Parent> createState() => _ParentState();
}

class _ParentState extends State<_Parent> {
  void rebuild() => setState(() {});
  @override
  // ignore: prefer_const_constructors
  Widget build(BuildContext context) => widget.useConst ? const _Child() : _Child();
}

void main() {
  testWidgets('const-barn byggs INTE om när föräldern ritas om', (tester) async {
    globalValue = 'A';
    await tester.pumpWidget(const _Parent(useConst: true));
    expect(find.text('A'), findsOneWidget);

    globalValue = 'B';
    tester.state<_ParentState>(find.byType(_Parent)).rebuild();
    await tester.pump();

    // Fortfarande 'A': subträdet kortslöts. Det här är buggen.
    expect(find.text('A'), findsOneWidget,
        reason: 'const-barnet ska demonstrera den frysta gamla vyn');
    expect(find.text('B'), findsNothing);
  });

  testWidgets('utan const byggs barnet om och ser det nya värdet', (tester) async {
    globalValue = 'A';
    await tester.pumpWidget(const _Parent(useConst: false));
    expect(find.text('A'), findsOneWidget);

    globalValue = 'B';
    tester.state<_ParentState>(find.byType(_Parent)).rebuild();
    await tester.pump();

    expect(find.text('B'), findsOneWidget);
  });
}
