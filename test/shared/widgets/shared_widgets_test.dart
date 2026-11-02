// test/shared/widgets/shared_widgets_test.dart
// Behaviour of the shared component library, including reduced motion.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streakin/app/theme/app_theme.dart';
import 'package:streakin/shared/widgets/widgets.dart';

Widget _host(Widget child, {bool reduced = false}) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  ),
);

double _opacityOf(WidgetTester tester, Finder f) {
  final opacity = tester.widget<Opacity>(
    find.ancestor(of: f, matching: find.byType(Opacity)).first,
  );
  return opacity.opacity;
}

void main() {
  testWidgets('PressableScale fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(PressableScale(onTap: () => taps++, child: const Text('Press'))),
    );
    await tester.tap(find.text('Press'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('AppCard onTap fires', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppCard(onTap: () => taps++, child: const Text('Card'))),
    );
    await tester.tap(find.text('Card'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('StaggeredEntrance ends fully visible', (tester) async {
    await tester.pumpWidget(
      _host(const StaggeredEntrance(index: 3, child: Text('Item'))),
    );
    expect(_opacityOf(tester, find.text('Item')), lessThan(1));
    await tester.pumpAndSettle();
    expect(_opacityOf(tester, find.text('Item')), 1);
  });

  testWidgets('StaggeredEntrance is instant under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const StaggeredEntrance(index: 3, child: Text('Item')),
        reduced: true,
      ),
    );
    await tester.pump();
    expect(_opacityOf(tester, find.text('Item')), 1);
  });

  testWidgets('Shake returns to rest offset', (tester) async {
    final ctrl = ShakeController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      _host(Shake(controller: ctrl, child: const Text('Field'))),
    );
    ctrl.shake();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    final t = tester.widget<Transform>(
      find
          .ancestor(of: find.text('Field'), matching: find.byType(Transform))
          .first,
    );
    expect(t.transform.getTranslation().x, closeTo(0, 0.001));
  });

  testWidgets('AnimatedCounter shows the final value', (tester) async {
    await tester.pumpWidget(_host(const AnimatedCounter(value: 3)));
    await tester.pumpWidget(_host(const AnimatedCounter(value: 4)));
    await tester.pumpAndSettle();
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('ErrorState retry fires', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(ErrorState(error: 'boom', onRetry: () => retries++)),
    );
    await tester.pumpAndSettle();
    expect(find.text('boom'), findsNothing, reason: 'raw error is not shown');
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('SettingsTile.toggle toggles from the whole row', (tester) async {
    bool? value;
    await tester.pumpWidget(
      _host(
        SettingsTile.toggle(
          title: 'Haptics',
          value: false,
          onChanged: (v) => value = v,
        ),
      ),
    );
    await tester.tap(find.text('Haptics'));
    expect(value, isTrue);
  });

  testWidgets('Skeleton shimmer settles under reduced motion', (tester) async {
    await tester.pumpWidget(_host(const SkeletonCard(), reduced: true));
    // Would time out if the shimmer kept repeating.
    await tester.pumpAndSettle();
    expect(find.byType(Skeleton), findsOneWidget);
  });
}
