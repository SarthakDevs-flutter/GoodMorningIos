import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:means_of_grace/l10n/app_localizations.dart';
import 'package:means_of_grace/screens/home_screen.dart';
import 'package:means_of_grace/services/locale_service.dart';

void main() {
  testWidgets('홈 화면 렌더링 확인', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: LocaleService.supportedLocales,
        home: HomeScreen(enableStartupSideEffects: false),
      ),
    );
    await tester.pump();

    expect(find.text('God Morning'), findsOneWidget);
    expect(find.text('Morning alarm'), findsOneWidget);
  });
}
