import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vibekla/main.dart';
import 'package:vibekla/providers/auth_provider.dart';
import 'package:vibekla/providers/data_provider.dart';
import 'package:vibekla/providers/bookmarks_provider.dart';

void main() {
  testWidgets('VibeKLA app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => DataProvider()),
          ChangeNotifierProvider(create: (_) => BookmarksProvider()),
        ],
        child: const VibeKLAApp(),
      ),
    );

    expect(find.text('VibeKLA'), findsWidgets);
  });
}
