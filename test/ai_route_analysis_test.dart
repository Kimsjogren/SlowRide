import 'package:flutter_test/flutter_test.dart';
import 'package:slowride/services/ai_route_analysis_service.dart';

void main() {
  test('parses a structured AI route analysis response', () {
    final analysis = AiRouteAnalysis.fromJson({
      'response_id': 'resp_test',
      'headline': 'Suitable with caution',
      'summary': 'The supplied route facts show one roadwork warning.',
      'suitability': 'caution',
      'highlights': ['Short travel time'],
      'cautions': ['Community alerts are unverified'],
      'recommendation': 'Check signs before departure.',
    });

    expect(analysis.responseId, 'resp_test');
    expect(analysis.suitability, 'caution');
    expect(analysis.highlights, ['Short travel time']);
    expect(analysis.cautions, ['Community alerts are unverified']);
  });

  test('limits structured lists to four items', () {
    final analysis = AiRouteAnalysis.fromJson({
      'highlights': ['1', '2', '3', '4', '5'],
      'cautions': const <String>[],
    });

    expect(analysis.highlights, hasLength(4));
  });

  test('normalizes AI whitespace and exposes separate account quotas', () {
    final analysis = AiRouteAnalysis.fromJson({
      'headline': 'Kort\n  och tydlig rutt',
      'summary': 'Rad ett.\nRad två.',
      'recommendation': '  Kör   försiktigt. ',
    });

    expect(analysis.headline, 'Kort och tydlig rutt');
    expect(analysis.summary, 'Rad ett. Rad två.');
    expect(analysis.recommendation, 'Kör försiktigt.');
    expect(AiRouteAnalysisService.freeDailyLimit, 4);
    expect(AiRouteAnalysisService.proDailyLimit, 15);
  });
}
