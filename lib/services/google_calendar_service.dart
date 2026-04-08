import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleCalendarService {
  Future<void> createEvent({
    required String accessToken,
    required String title,
    required String date,
  }) async {
    final url = Uri.parse(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events',
    );

    final event = {
      "summary": title,
      "start": {
        "date": date, // yyyy-MM-dd
      },
      "end": {
        "date": date,
      },
    };

    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode(event),
    );

    print("STATUS: ${response.statusCode}");
    print("BODY: ${response.body}");

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception("Failed to create calendar event: ${response.body}");
    }
  }
}