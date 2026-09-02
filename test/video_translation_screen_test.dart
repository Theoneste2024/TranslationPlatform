import 'package:flutter_test/flutter_test.dart';
import 'package:translation_platform/screens/translation/video_translation_screen.dart';

void main() {
  group('normalizeVideoTranslationPayload', () {
    test('parses segment payloads into transcript and translated text', () {
      final payload = {
        'segments': [
          {'original': 'Hello world', 'translated': 'Bonjour le monde', 'start': 0.0, 'end': 3.0},
          {'original': 'How are you', 'translated': 'Comment ça va', 'start': 3.0, 'end': 6.0},
        ],
      };

      final normalized = normalizeVideoTranslationPayload(payload);

      expect(normalized['originalTranscript'], 'Hello world How are you');
      expect(normalized['translatedText'], 'Bonjour le monde Comment ça va');
      expect((normalized['subtitles'] as List).length, 2);
    });

    test('falls back to top-level fields when segments are missing', () {
      final payload = {
        'original_text': 'Sample transcript',
        'translated_text': 'Traduction exemple',
      };

      final normalized = normalizeVideoTranslationPayload(payload);

      expect(normalized['originalTranscript'], 'Sample transcript');
      expect(normalized['translatedText'], 'Traduction exemple');
      expect((normalized['subtitles'] as List).isEmpty, isTrue);
    });
  });
}
