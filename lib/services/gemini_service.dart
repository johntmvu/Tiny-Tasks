import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiServiceException implements Exception {
  final String message;
  GeminiServiceException(this.message);

  @override
  String toString() => 'GeminiServiceException: $message';
}

class GeminiService {
  static final GeminiService instance = GeminiService._init();
  GeminiService._init();

  GenerativeModel? _model;

  GenerativeModel get _generativeModel {
    _model ??= GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: dotenv.env['GEMINI_API_KEY']!,
    );
    return _model!;
  }

  Future<List<Map<String, String>>> decomposeBigTask({
    required String title,
    String? description,
    required String priority,
    required String startDate,
    required String dueDate,
  }) async {
    final descriptionLine =
        description != null && description.isNotEmpty
            ? '\nDescription: $description'
            : '';

    final prompt = '''
You are a productivity assistant. Break down the following big task into 3 to 7
concrete, actionable subtasks that can each be completed in a single day.
Distribute them reasonably across the available time frame.

Big Task Title: $title$descriptionLine
Priority: $priority
Start Date: $startDate
Due Date: $dueDate

Respond ONLY with a valid JSON array of objects, each with "title" and "date" (yyyy-MM-dd) keys.
No markdown, no explanation.
Example: [{"title": "Research topic", "date": "2026-04-07"}, ...]''';

    try {
      final response = await _generativeModel.generateContent(
        [Content.text(prompt)],
      );

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw GeminiServiceException('Empty response from Gemini');
      }

      // Strip markdown fences if present
      final cleaned = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '')
          .trim();

      final decoded = jsonDecode(cleaned);
      if (decoded is! List) {
        throw GeminiServiceException('Expected JSON array but got: $decoded');
      }

      return decoded
          .map<Map<String, String>>(
            (item) => {
              'title': (item['title'] ?? '').toString(),
              'date': (item['date'] ?? startDate).toString(),
            },
          )
          .toList();
    } catch (e) {
      if (e is GeminiServiceException) rethrow;
      throw GeminiServiceException('Failed to decompose task: $e');
    }
  }
}
