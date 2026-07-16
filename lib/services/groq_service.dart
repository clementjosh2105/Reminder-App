import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../services/notification_service.dart';

class GroqService {
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.1-8b-instant';

  static bool get isConfigured => _apiKey.trim().isNotEmpty;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  static Future<String> generateMotivation(
    String habitTitle,
    String category, {
    String description = '',
  }) async {
    if (!isConfigured) return _fallbackQuoteFor(habitTitle, category);

    try {
      final context = description.isNotEmpty
          ? '"$habitTitle" - $description (category: $category)'
          : '"$habitTitle" (category: $category)';
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are an energetic, no-nonsense life coach. Give a short, punchy reminder.',
                },
                {
                  'role': 'user',
                  'content':
                      'Give one short (maximum 15 words) motivational message for someone doing their habit $context. Do not use quotation marks, do not use complex punctuation, just write the message.',
                },
              ],
              'temperature': 0.7,
              'max_tokens': 50,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _cleanMessage(
          data['choices'][0]['message']['content'].toString(),
        );
      }
    } catch (e) {
      NotificationService.log('Groq motivation request failed: $e');
    }

    return _fallbackQuoteFor(habitTitle, category);
  }

  static Future<String> generateDashboardQuote() async {
    if (!isConfigured) {
      const list = AppConstants.defaultQuotes;
      return list[DateTime.now().day % list.length];
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are an inspirational life coach. Provide a short, powerful motivational quote.',
                },
                {
                  'role': 'user',
                  'content':
                      'Provide one short, powerful, inspiring motivational quote (maximum 15 words) suitable for a daily habit tracker dashboard. Do not include author names or quotes, just the statement itself.',
                },
              ],
              'temperature': 0.8,
              'max_tokens': 50,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _cleanMessage(
          data['choices'][0]['message']['content'].toString(),
        );
      }
    } catch (e) {
      NotificationService.log('Groq dashboard quote request failed: $e');
    }

    const list = AppConstants.defaultQuotes;
    return list[DateTime.now().day % list.length];
  }

  static Future<String> generateInsight({
    required String habitTitle,
    required String category,
    required String completionRate,
    required int currentStreak,
  }) async {
    if (!isConfigured) {
      return 'Every small step forward builds the momentum to go the distance.';
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a smart habit coach who gives concise, data-driven improvement tips.',
                },
                {
                  'role': 'user',
                  'content':
                      'My habit is "$habitTitle" ($category). My completion rate is $completionRate% and current streak is $currentStreak days. Give one short actionable tip or encouragement in under 20 words. No hashtags or bullet points.',
                },
              ],
              'temperature': 0.75,
              'max_tokens': 60,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _cleanMessage(
          data['choices'][0]['message']['content'].toString(),
        );
      }
    } catch (e) {
      debugPrint('[GROQ] Insight request failed: $e');
    }

    return 'Every small step forward builds the momentum to go the distance.';
  }

  static Future<String> generateCelebrationMeme({
    required String habitTitle,
    required String category,
    required int currentStreak,
  }) async {
    if (!isConfigured) {
      return 'Commit successful! Code compiles and your streak survives. Keep pushing!';
    }

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a witty, slightly sarcastic AI Life Coach helping a developer build habits.',
                },
                {
                  'role': 'user',
                  'content':
                      'The user just logged a session for "$habitTitle" ($category) extending their streak combo to $currentStreak. Generate a short, punchy, single-sentence celebration dialogue bubble. Mix in tech culture humor, developer inside jokes (like Git, stack overflows, missing semicolons, coffee addiction, or compiler optimization), or casual gaming level-up references. Keep it under 22 words. Do not use quotes around the output.',
                },
              ],
              'temperature': 0.85,
              'max_tokens': 60,
            }),
          )
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _cleanMessage(
          data['choices'][0]['message']['content'].toString(),
        );
      }
    } catch (e) {
      NotificationService.log('Groq celebration request failed: $e');
    }

    return 'Commit successful! Code compiles and your streak survives. Keep pushing!';
  }

  static String _cleanMessage(String raw) {
    var message = raw.trim();
    if (message.startsWith('"') && message.endsWith('"')) {
      message = message.substring(1, message.length - 1);
    }
    return message;
  }

  static String _fallbackQuoteFor(String habitTitle, String category) {
    const list = AppConstants.defaultQuotes;
    final index = (habitTitle.length + category.length) % list.length;
    return list[index];
  }
}
