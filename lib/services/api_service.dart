import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000";
  // change if real phone

  // =========================
  // TEXT TRANSLATION
  // =========================
  static Future<String> translateText(String text, String targetLang) async {
    final response = await http.post(
      Uri.parse("$baseUrl/translate-text"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "text": text,
        "target_lang": targetLang,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["translated_text"];
    } else {
      throw Exception("Failed to translate");
    }
  }
}
