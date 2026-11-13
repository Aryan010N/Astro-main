import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expert_app/main.dart';

void main() {
  testWidgets('Astro expert app launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: AstroExpertApp(),
      ),
    );
    expect(find.byType(AstroExpertApp), findsOneWidget);
  });
}
