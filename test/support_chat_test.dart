import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/features/support/support_chat_screen.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/support_message.dart';
import 'package:slowride/services/support_faq_service.dart';

void main() {
  test('reply-time promise is localized for every supported language', () {
    const expected = <String, String>{
      'sv': 'Svarar inom 24 h',
      'en': 'Replies within 24 hours',
      'da': 'Svarer inden for 24 timer',
      'nb': 'Svarer innen 24 timer',
      'fi': 'Vastaamme 24 tunnin kuluessa',
      'fr': 'Réponse sous 24 heures',
      'es': 'Respondemos en un plazo de 24 horas',
      'it': 'Rispondiamo entro 24 ore',
    };

    expect(AppLocalizations.supportedLocales, hasLength(expected.length));
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        lookupAppLocalizations(locale).supportChatReplyTime,
        expected[locale.languageCode],
      );
    }
  });

  test('support message parses sender, timestamps and read state', () {
    final message = SupportMessage.fromMap({
      'id': 'message-id',
      'user_id': 'user-id',
      'sender': 'support',
      'body': 'How can we help?',
      'created_at': '2026-08-01T12:30:00Z',
      'read_at': '2026-08-01T12:31:00Z',
    });

    expect(message.id, 'message-id');
    expect(message.userId, 'user-id');
    expect(message.isFromSupport, isTrue);
    expect(message.body, 'How can we help?');
    expect(message.createdAt, isA<DateTime>());
    expect(message.readAt, isNotNull);
  });

  testWidgets('bundled FAQ answers common questions without a server', (
    tester,
  ) async {
    final catalog = await SupportFaqService.instance.load();

    expect(catalog.entries, hasLength(7));
    final aiAnswer = SupportFaqService.instance.match(
      'AI kolla rutten fungerar inte',
      'sv',
      catalog,
    );
    final gpsAnswer = SupportFaqService.instance.match(
      'Min GPS fungerar inte',
      'sv',
      catalog,
    );

    expect(aiAnswer?.id, 'ai_route');
    expect(aiAnswer?.answer('sv'), contains('4 analyser per dag'));
    expect(gpsAnswer?.id, 'gps');
    expect(
      SupportFaqService.instance.match(
        'Jag vill prata om något annat',
        'sv',
        catalog,
      ),
      isNull,
    );
  });

  testWidgets('FAQ assistant fits a phone screen and opens a prepared answer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final catalog = await SupportFaqService.instance.load();
    SupportFaqEntry? selected;

    Widget buildAssistant() => MaterialApp(
      locale: const Locale('sv'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF06154A),
          body: SupportFaqAssistantPanel(
            catalog: catalog,
            languageCode: 'sv',
            question: selected?.question('sv'),
            answer: selected,
            showContact: selected != null,
            forwarding: false,
            humanSupportAvailable: true,
            onQuestionSelected: (entry) => selected = entry,
            onContactSupport: () {},
            l10n: AppLocalizations.of(context)!,
          ),
        ),
      ),
    );

    await tester.pumpWidget(buildAssistant());
    expect(find.text('Hur byter jag fordonstyp?'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Hur byter jag fordonstyp?'));
    await tester.pumpWidget(buildAssistant());
    await tester.pump();
    expect(find.textContaining('Öppna Inställningar'), findsOneWidget);
    expect(find.text('Skicka till support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
