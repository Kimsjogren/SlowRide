import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/l10n/app_localizations.dart';
import 'package:slowride/models/support_message.dart';

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
}
