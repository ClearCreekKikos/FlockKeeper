// lib/shared/services/gemini_voice_service.dart

import 'dart:convert';
import '../../data/models/kidding_record_model.dart';
import 'voice_parser.dart';

/// Provides JSON parsing utilities for Gemini AI voice command responses.
class GeminiVoiceService {
  /// Parses a structured JSON response from Gemini into a [VoiceCommandResult].
  ///
  /// [jsonResponse] is the raw JSON string returned by the Gemini API.
  /// [rawText] is the original transcribed text from the user.
  static VoiceCommandResult parseJsonResponse(
    String jsonResponse,
    String rawText,
  ) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(jsonResponse) as Map<String, dynamic>;

      final intentStr = data['intent'] as String? ?? 'unknown';
      final intent = _parseIntent(intentStr);
      final animalName = data['animalName'] as String?;

      // Weight result
      VoiceWeightResult? weightResult;
      if (data['weightResult'] != null) {
        final wr = data['weightResult'] as Map<String, dynamic>;
        weightResult = VoiceWeightResult(
          weight: (wr['weight'] as num).toDouble(),
          animalName: wr['animalName'] as String?,
          rawText: rawText,
        );
      }

      // Health result
      VoiceHealthResult? healthResult;
      if (data['healthResult'] != null) {
        final hr = data['healthResult'] as Map<String, dynamic>;
        healthResult = VoiceHealthResult(
          treatment: hr['treatment'] as String,
          dosage: hr['dosage'] as String?,
          animalName: hr['animalName'] as String?,
          rawText: rawText,
        );
      }

      // Note result
      VoiceNoteResult? noteResult;
      if (data['noteResult'] != null) {
        final nr = data['noteResult'] as Map<String, dynamic>;
        noteResult = VoiceNoteResult(
          noteText: nr['noteText'] as String,
          animalName: nr['animalName'] as String?,
          rawText: rawText,
        );
      }

      // Kidding result
      VoiceKiddingResult? kiddingResult;
      if (data['kiddingResult'] != null) {
        final kr = data['kiddingResult'] as Map<String, dynamic>;
        final kids = (kr['kids'] as List<dynamic>? ?? []).map((k) {
          final kid = k as Map<String, dynamic>;
          return VoiceKidDetail(
            earTag: kid['earTag'] as String?,
            sex: _parseSex(kid['sex'] as String?),
            color: kid['color'] as String?,
            weight: kid['weight'] != null
                ? (kid['weight'] as num).toDouble()
                : null,
          );
        }).toList();

        kiddingResult = VoiceKiddingResult(
          damName: kr['damName'] as String?,
          litterSize: kr['litterSize'] as int,
          kids: kids,
          rawText: rawText,
        );
      }

      return VoiceCommandResult(
        intent: intent,
        rawText: rawText,
        animalName: animalName,
        weightResult: weightResult,
        healthResult: healthResult,
        noteResult: noteResult,
        kiddingResult: kiddingResult,
      );
    } catch (_) {
      return VoiceCommandResult(intent: VoiceIntent.unknown, rawText: rawText);
    }
  }

  static VoiceIntent _parseIntent(String intentStr) {
    switch (intentStr.toLowerCase()) {
      case 'weight':
        return VoiceIntent.weight;
      case 'health':
        return VoiceIntent.health;
      case 'kidding':
        return VoiceIntent.kidding;
      case 'note':
        return VoiceIntent.note;
      default:
        return VoiceIntent.unknown;
    }
  }

  static KidSex _parseSex(String? sexStr) {
    switch (sexStr?.toLowerCase()) {
      case 'doe':
      case 'female':
      case 'girl':
        return KidSex.doe;
      case 'buck':
      case 'male':
      case 'boy':
        return KidSex.buck;
      default:
        return KidSex.unknown;
    }
  }
}
