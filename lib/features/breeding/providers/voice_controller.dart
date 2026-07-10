import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:intl/intl.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../data/models/breeding_event_model.dart';
import '../../../data/models/weight_record_model.dart';
import '../../../data/models/health_record_model.dart';
import '../../../data/models/reminder_model.dart';
import '../../../data/models/pasture_model.dart';
import '../../../data/models/inventory_usage_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../../shared/services/voice_parser.dart';
import '../../weights/providers/weight_providers.dart';
import '../../health/screens/health_dashboard_screen.dart';
import '../../inventory/providers/inventory_providers.dart';
import 'breeding_providers.dart';

enum VoiceState {
  inactive,
  initializing,
  readyToListen,
  listening,
  processing,
  confirming,
  saving,
  success,
  error,
}

class VoiceCommandState {
  final VoiceState status;
  final String transcription;
  final VoiceCommandResult? result;
  final String? errorMessage;

  VoiceCommandState({
    required this.status,
    this.transcription = '',
    this.result,
    this.errorMessage,
  });

  VoiceCommandState copyWith({
    VoiceState? status,
    String? transcription,
    VoiceCommandResult? result,
    String? errorMessage,
  }) {
    return VoiceCommandState(
      status: status ?? this.status,
      transcription: transcription ?? this.transcription,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final voiceCommandProvider =
    StateNotifierProvider.autoDispose<VoiceCommandNotifier, VoiceCommandState>((
      ref,
    ) {
      final notifier = VoiceCommandNotifier(ref);
      ref.onDispose(() => notifier.cleanup());
      return notifier;
    });

class VoiceCommandNotifier extends StateNotifier<VoiceCommandState> {
  final Ref _ref;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _speechInitialized = false;
  Timer? _silenceTimer;

  VoiceCommandNotifier(this._ref)
    : super(VoiceCommandState(status: VoiceState.inactive));

  Future<void> startVoiceSession() async {
    state = state.copyWith(status: VoiceState.initializing, errorMessage: null);

    try {
      if (!_speechInitialized) {
        debugPrint('🎤 Initializing speech recognition...');
        final available = await _speech.initialize(
          onError: (val) => _handleSpeechError(val.errorMsg),
          onStatus: (val) => _handleSpeechStatus(val),
        );

        if (!available) {
          debugPrint(
            '🎤 ERROR: Speech recognition not available on this device',
          );
          throw Exception(
            'Speech recognition is not available.\n\n'
            'Common causes:\n'
            '• Running on emulator (use physical device)\n'
            '• Microphone permission not granted\n'
            '• Device does not support speech recognition\n\n'
            'Please check Settings → Permissions → Microphone',
          );
        }

        debugPrint('🎤 Speech recognition initialized successfully');
        _speechInitialized = true;
      }

      await _configureTts();

      _tts.setCompletionHandler(() {
        if (state.status == VoiceState.initializing) {
          _startListeningForDetails();
        } else if (state.status == VoiceState.confirming) {
          _startListeningForConfirmation();
        }
      });

      state = state.copyWith(status: VoiceState.initializing);
      await _tts.speak("Keeko Keeper here, how can I help?");
    } catch (e) {
      state = state.copyWith(
        status: VoiceState.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> _startListeningForDetails() async {
    state = state.copyWith(status: VoiceState.listening);

    await _speech.listen(
      onResult: (val) {
        state = state.copyWith(transcription: val.recognizedWords);
        _resetSilenceTimer(() => stopListeningAndProcess());
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        cancelOnError: true,
      ),
    );
  }

  void _resetSilenceTimer(VoidCallback onTimeout) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 5), onTimeout);
  }

  Future<void> stopListeningAndProcess() async {
    // Guard against being called twice (the silence timer AND the engine's
    // "done" status can both fire) — that caused the assistant to process and
    // speak its response twice.
    if (state.status != VoiceState.listening) return;
    _silenceTimer?.cancel();
    // Claim the processing state immediately so a second caller bails above.
    state = state.copyWith(status: VoiceState.processing);

    if (_speech.isListening) {
      await _speech.stop();
    }

    if (state.transcription.trim().isEmpty) {
      state = state.copyWith(status: VoiceState.inactive);
      return;
    }

    await _processRecognizedText(state.transcription);
  }

  Future<void> processTextQuery(String queryText) async {
    state = state.copyWith(
      status: VoiceState.processing,
      transcription: queryText,
      errorMessage: null,
    );

    // Initialize TTS settings (needed for speaking back the confirmation)
    try {
      await _configureTts();

      _tts.setCompletionHandler(() {
        if (state.status == VoiceState.confirming) {
          _startListeningForConfirmation();
        }
      });
    } catch (e) {
      debugPrint('TTS Init error: $e');
    }

    await _processRecognizedText(queryText);
  }

  Future<void> _processRecognizedText(String text) async {
    try {
      final animalRepo = _ref.read(animalRepositoryProvider);
      final allAnimals = await animalRepo.getAllAnimals();
      final activeAnimals = allAnimals
          .where((a) => a.status == AnimalStatus.active)
          .toList();
      final animalNames = activeAnimals.map((a) => a.name).toList();

      final Map<String, String> tagToNameMap = {};
      for (final a in activeAnimals) {
        if (a.earTag != null && a.earTag!.isNotEmpty) {
          tagToNameMap[a.earTag!] = a.name;
        }
      }

      final pastures = await _ref.read(pastureRepositoryProvider).getAllPastures();
      final pastureNames = pastures.map((p) => p.name).toList();

      // Fetch inventory item names for voice matching
      final inventoryItems = await _ref.read(inventoryRepositoryProvider).getAllItems();
      final inventoryItemNames = inventoryItems.map((i) => i.name).toList();

      final result = VoiceParser.parseCommand(
        text,
        animalNames,
        tagToNameMap: tagToNameMap,
        pastureNames: pastureNames,
        inventoryItemNames: inventoryItemNames,
      );

      // Validate based on intent
      if (result.intent == VoiceIntent.kidding) {
        if (result.animalName == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify the mother goat in your statement: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the mother goat. Please try again.",
          );
          return;
        }
        state = state.copyWith(status: VoiceState.confirming, result: result);
        final kidsLabel = result.kiddingResult!.litterSize == 1
            ? "1 kid"
            : "${result.kiddingResult!.litterSize} kids";
        await _tts.speak(
          "Found ${result.animalName}. Added $kidsLabel. Say confirm to save, or cancel.",
        );
      } else if (result.intent == VoiceIntent.weight) {
        if (result.animalName == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify the goat for the weight record in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the goat name. Please try again.",
          );
          return;
        }
        if (result.weightResult == null || result.weightResult!.weight <= 0) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage: "I couldn't parse a valid weight value in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the weight value. Please try again.",
          );
          return;
        }
        state = state.copyWith(status: VoiceState.confirming, result: result);
        await _tts.speak(
          "Log weight of ${result.weightResult!.weight} pounds for ${result.animalName}. Say confirm to save, or cancel.",
        );
      } else if (result.intent == VoiceIntent.health) {
        final h = result.healthResult!;
        if (!h.appliesToHerd && result.animalName == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify the goat for the health log in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the goat name. Please try again.",
          );
          return;
        }
        if (h.type == HealthRecordType.famacha && h.famachaScore == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage: "I couldn't identify a FAMACHA score (1 to 5) in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the FAMACHA score. Please say a number from 1 to 5.",
          );
          return;
        }
        if (h.type == HealthRecordType.bcs && h.bcsScore == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify a body condition score (1 to 5) in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the body condition score. Please say a number from 1 to 5.",
          );
          return;
        }
        state = state.copyWith(status: VoiceState.confirming, result: result);
        final healthTarget =
            h.appliesToHerd ? "the whole herd" : result.animalName;
        await _tts.speak(
          "Log ${_healthSummary(h)} for $healthTarget. Say confirm to save, or cancel.",
        );
      } else if (result.intent == VoiceIntent.note) {
        if (result.animalName == null) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify the goat for adding a note in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the goat name. Please try again.",
          );
          return;
        }
        if (result.noteResult == null || result.noteResult!.noteText.isEmpty) {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage: "I couldn't parse any note text in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the note content. Please try again.",
          );
          return;
        }
        state = state.copyWith(status: VoiceState.confirming, result: result);
        await _tts.speak(
          "Add note for ${result.animalName}. Say confirm to save, or cancel.",
        );
      } else if (result.intent == VoiceIntent.reminder) {
        final r = result.reminderResult!;
        state = state.copyWith(status: VoiceState.confirming, result: result);
        final target = r.animalName != null ? "for ${r.animalName}" : "for the herd";
        await _tts.speak(
          "Set a reminder to ${r.title} on ${_spokenDate(r.date)} $target. Say confirm to save, or cancel.",
        );
      } else if (result.intent == VoiceIntent.pasture) {
        final p = result.pastureResult!;

        if (p.action == PastureVoiceAction.setStatus) {
          if (p.pastureName == null || p.status == null) {
            state = state.copyWith(
              status: VoiceState.error,
              errorMessage:
                  "I couldn't identify the pasture or status in: \"$text\"",
            );
            await _tts.speak(
              "I couldn't identify which pasture or status. Please try again.",
            );
            return;
          }
          state = state.copyWith(status: VoiceState.confirming, result: result);
          await _tts.speak(
            "Mark ${p.pastureName} as ${p.status!.name}. Say confirm to save, or cancel.",
          );
        } else {
          if (p.pastureName == null) {
            state = state.copyWith(
              status: VoiceState.error,
              errorMessage: "I couldn't identify the pasture in: \"$text\"",
            );
            await _tts.speak(
              "I couldn't identify the pasture. Please try again.",
            );
            return;
          }
          if (p.action == PastureVoiceAction.moveAnimal &&
              p.animalName == null) {
            state = state.copyWith(
              status: VoiceState.error,
              errorMessage:
                  "I couldn't identify which goat to move in: \"$text\"",
            );
            await _tts.speak(
              "I couldn't identify which goat to move. Please try again.",
            );
            return;
          }
          state = state.copyWith(status: VoiceState.confirming, result: result);
          final String phrase;
          switch (p.action) {
            case PastureVoiceAction.moveAnimal:
              phrase = "Move ${p.animalName} to ${p.pastureName}";
              break;
            case PastureVoiceAction.rotate:
              phrase = "Rotate the herd to ${p.pastureName}";
              break;
            case PastureVoiceAction.moveHerd:
            default:
              phrase = "Move the whole herd to ${p.pastureName}";
              break;
          }
          await _tts.speak("$phrase. Say confirm to save, or cancel.");
        }
      } else if (result.intent == VoiceIntent.inventory) {
        final inv = result.inventoryResult!;
        if (inv.itemName == 'unknown item') {
          state = state.copyWith(
            status: VoiceState.error,
            errorMessage:
                "I couldn't identify the supply item in: \"$text\"",
          );
          await _tts.speak(
            "I couldn't identify the supply item. Please try again.",
          );
          return;
        }
        state = state.copyWith(status: VoiceState.confirming, result: result);
        final qty = inv.quantity % 1 == 0 ? inv.quantity.toInt().toString() : inv.quantity.toString();
        switch (inv.action) {
          case InventoryVoiceAction.addStock:
            await _tts.speak(
              "Add $qty of ${inv.itemName} to inventory. Say confirm to save, or cancel.",
            );
            break;
          case InventoryVoiceAction.useStock:
            await _tts.speak(
              "Log usage of $qty ${inv.itemName}. Say confirm to save, or cancel.",
            );
            break;
          case InventoryVoiceAction.checkStock:
            // For check, just answer immediately — no confirmation needed
            final repo = _ref.read(inventoryRepositoryProvider);
            final items = await repo.searchItems(inv.itemName);
            if (items.isNotEmpty) {
              final item = items.first;
              final qty = item.currentQuantity % 1 == 0 ? item.currentQuantity.toInt() : item.currentQuantity;
              state = state.copyWith(status: VoiceState.success, result: result);
              await _tts.speak(
                "You have $qty ${item.unit} of ${item.name} in stock.",
              );
            } else {
              state = state.copyWith(status: VoiceState.success, result: result);
              await _tts.speak(
                "I couldn't find ${inv.itemName} in your inventory.",
              );
            }
            return;
        }
      } else {
        state = state.copyWith(
          status: VoiceState.error,
          errorMessage: "I couldn't identify your request: \"$text\"",
        );
        await _tts.speak("I couldn't identify your request. Please try again.");
      }
    } catch (e) {
      state = state.copyWith(
        status: VoiceState.error,
        errorMessage: e.toString(),
      );
      await _tts.speak("An error occurred while processing.");
    }
  }

  Future<void> _startListeningForConfirmation() async {
    await _speech.listen(
      onResult: (val) {
        final command = val.recognizedWords.toLowerCase();
        if (command.contains("confirm") ||
            command.contains("save") ||
            command.contains("yes")) {
          _speech.stop();
          saveVoiceRecord();
        } else if (command.contains("cancel") || command.contains("no")) {
          _speech.stop();
          cancelSession();
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> saveVoiceRecord() async {
    final result = state.result;
    if (result == null) return;
    // Save only once, from the confirming state — the spoken "confirm" and the
    // on-screen button can otherwise both trigger a duplicate save.
    if (state.status != VoiceState.confirming) return;

    state = state.copyWith(status: VoiceState.saving);

    try {
      final now = DateTime.now();

      // ── REMINDER (animal optional) ──
      if (result.intent == VoiceIntent.reminder) {
        final r = result.reminderResult!;
        int? animalId;
        if (r.animalName != null) {
          final all = await _ref.read(animalRepositoryProvider).getAllAnimals();
          animalId = all
              .where((a) => a.name.toLowerCase() == r.animalName!.toLowerCase())
              .firstOrNull
              ?.id;
        }
        await _ref.read(reminderRepositoryProvider).insertReminder(
              Reminder(
                animalId: animalId,
                title: r.title,
                description: 'Created via voice command',
                reminderDate: r.date,
                reminderType: r.type,
              ),
            );
        _ref.invalidate(reminderRepositoryProvider);
        state = state.copyWith(status: VoiceState.success);
        await _tts.speak("Reminder saved successfully.");
        return;
      }

      // ── PASTURE (animal optional, depends on action) ──
      if (result.intent == VoiceIntent.pasture) {
        await _savePastureAction(result.pastureResult!, now);
        return;
      }

      // ── INVENTORY ──
      if (result.intent == VoiceIntent.inventory) {
        final inv = result.inventoryResult!;
        final repo = _ref.read(inventoryRepositoryProvider);
        final items = await repo.searchItems(inv.itemName);

        if (items.isEmpty) {
          throw Exception("Could not find '${inv.itemName}' in your inventory.");
        }

        final item = items.first;
        final qty = inv.quantity;

        if (inv.action == InventoryVoiceAction.addStock) {
          await repo.adjustQuantity(item.id!, qty);
          _ref.invalidate(inventoryItemsProvider);
          _ref.invalidate(lowStockItemsProvider);
          state = state.copyWith(status: VoiceState.success);
          final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
          await _tts.speak("Added $qtyStr ${item.unit} of ${item.name} to inventory.");
        } else if (inv.action == InventoryVoiceAction.useStock) {
          await repo.logUsage(
            InventoryUsage(
              inventoryItemId: item.id!,
              quantityUsed: qty,
              usageDate: now,
              notes: 'Logged via voice command',
            ),
          );
          _ref.invalidate(inventoryItemsProvider);
          _ref.invalidate(lowStockItemsProvider);
          state = state.copyWith(status: VoiceState.success);
          final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
          await _tts.speak("Logged usage of $qtyStr ${item.unit} of ${item.name}.");
        }
        return;
      }

      // ── HERD-WIDE HEALTH (one command → a record for every active goat) ──
      if (result.intent == VoiceIntent.health &&
          result.healthResult!.appliesToHerd) {
        final h = result.healthResult!;
        final active = (await _ref.read(animalRepositoryProvider).getAllAnimals())
            .where((a) => a.status == AnimalStatus.active)
            .toList();
        if (active.isEmpty) {
          throw Exception("There are no active goats to record.");
        }
        final healthRepo = _ref.read(healthRepositoryProvider);
        final isScore = h.type == HealthRecordType.famacha ||
            h.type == HealthRecordType.bcs;
        for (final a in active) {
          await healthRepo.insertHealthRecord(
            HealthRecord(
              animalId: a.id!,
              recordDate: now,
              recordType: h.type,
              treatment: isScore ? null : h.treatment,
              dosage: h.dosage,
              famachaScore: h.famachaScore,
              bcsScore: h.bcsScore,
              notes: "Recorded via voice command (herd-wide)",
            ),
          );
          _ref.invalidate(healthHistoryProvider(a.id!));
        }
        state = state.copyWith(status: VoiceState.success);
        await _tts.speak(
          "Health record saved for the whole herd. ${active.length} goats updated.",
        );
        return;
      }

      // ── ANIMAL-REQUIRED INTENTS (kidding / weight / health / note) ──
      if (result.animalName == null) {
        throw Exception("No goat was identified for this record.");
      }
      final animalRepo = _ref.read(animalRepositoryProvider);
      final allAnimals = await animalRepo.getAllAnimals();
      final activeAnimals = allAnimals
          .where((a) => a.status == AnimalStatus.active)
          .toList();
      final targetAnimal = activeAnimals.firstWhere(
        (a) => a.name.toLowerCase() == result.animalName!.toLowerCase(),
        orElse: () => throw Exception(
          "Goat '${result.animalName}' was not found in active herd.",
        ),
      );

      if (result.intent == VoiceIntent.kidding) {
        final kiddingResult = result.kiddingResult!;
        final kiddingRepo = _ref.read(kiddingRepositoryProvider);
        final breedingRepo = _ref.read(breedingRepositoryProvider);

        // Query pending breeding event
        final breedingEvents = await breedingRepo.getBreedingEventsForDoe(
          targetAnimal.id!,
        );
        final pendingEvent = breedingEvents
            .where((e) => e.actualKidDate == null)
            .firstOrNull;
        final int? sireId = pendingEvent?.buckId;
        final int? breedingEventId = pendingEvent?.id;

        for (int i = 0; i < kiddingResult.kids.length; i++) {
          final kidDetail = kiddingResult.kids[i];
          final birthOrder = i + 1;
          final kidTag = kidDetail.earTag;

          final String kidName = kidTag != null
              ? "${targetAnimal.name}'s Kid $kidTag"
              : "${targetAnimal.name}'s Kid $birthOrder";

          final kidAnimal = Animal(
            name: kidName,
            earTag: kidTag,
            sex: kidDetail.sex == KidSex.doe
                ? Sex.doe
                : (kidDetail.sex == KidSex.buck ? Sex.buck : Sex.unknown),
            dob: now,
            color: kidDetail.color,
            birthWeightLbs: kidDetail.weight,
            damId: targetAnimal.id,
            damName: targetAnimal.name,
            sireId: sireId,
            sireName: pendingEvent?.buckName,
            status: AnimalStatus.active,
            createdAt: now,
            updatedAt: now,
          );

          final kidId = await animalRepo.insertAnimal(kidAnimal);

          final kiddingRecord = KiddingRecord(
            breedingEventId: breedingEventId,
            doeId: targetAnimal.id!,
            buckId: sireId,
            kidId: kidId,
            kidName: kidName,
            kiddingDate: now,
            birthOrder: birthOrder,
            litterSize: kiddingResult.litterSize,
            birthWeightLbs: kidDetail.weight,
            sex: kidDetail.sex,
            birthType: _getBirthType(kiddingResult.litterSize),
            survivalStatus: SurvivalStatus.alive,
            createdAt: now,
          );

          await kiddingRepo.insertKiddingRecord(kiddingRecord);
        }

        if (pendingEvent != null) {
          final updatedEvent = pendingEvent.copyWith(
            actualKidDate: now,
            outcome: BreedingOutcome.kidded,
            updatedAt: now,
          );
          await breedingRepo.updateBreedingEvent(updatedEvent);
        }

        _ref.invalidate(kiddingRecordsListProvider);
        _ref.invalidate(breedingListProvider);
        _ref.invalidate(breedingStatsProvider);

        state = state.copyWith(status: VoiceState.success);
        await _tts.speak("Kidding record saved successfully.");
      } else if (result.intent == VoiceIntent.weight) {
        final weightResult = result.weightResult!;
        final weightRepo = _ref.read(weightRepositoryProvider);

        await weightRepo.insertWeightRecord(
          WeightRecord(
            animalId: targetAnimal.id!,
            weightLbs: weightResult.weight,
            weighDate: now,
            notes: "Recorded via voice command",
          ),
        );

        _ref.invalidate(latestWeightProvider(targetAnimal.id!));
        _ref.invalidate(weightHistoryProvider(targetAnimal.id!));
        _ref.invalidate(lifetimeADGProvider(targetAnimal.id!));
        _ref.invalidate(recentADGProvider(targetAnimal.id!));
        _ref.invalidate(milestoneWeightsProvider(targetAnimal.id!));

        state = state.copyWith(status: VoiceState.success);
        await _tts.speak("Weight record saved successfully.");
      } else if (result.intent == VoiceIntent.health) {
        final h = result.healthResult!;
        final healthRepo = _ref.read(healthRepositoryProvider);
        final isScore = h.type == HealthRecordType.famacha ||
            h.type == HealthRecordType.bcs;

        await healthRepo.insertHealthRecord(
          HealthRecord(
            animalId: targetAnimal.id!,
            recordDate: now,
            recordType: h.type,
            treatment: isScore ? null : h.treatment,
            dosage: h.dosage,
            famachaScore: h.famachaScore,
            bcsScore: h.bcsScore,
            notes: "Recorded via voice command",
          ),
        );

        _ref.invalidate(healthHistoryProvider(targetAnimal.id!));

        state = state.copyWith(status: VoiceState.success);
        await _tts.speak("Health record saved successfully.");
      } else if (result.intent == VoiceIntent.note) {
        final noteResult = result.noteResult!;
        final newNotes =
            targetAnimal.notes != null && targetAnimal.notes!.isNotEmpty
            ? "${targetAnimal.notes}\n${noteResult.noteText}"
            : noteResult.noteText;

        final updatedAnimal = targetAnimal.copyWith(
          notes: newNotes,
          updatedAt: now,
        );

        await animalRepo.updateAnimal(updatedAnimal);

        state = state.copyWith(status: VoiceState.success);
        await _tts.speak("Note saved successfully.");
      }

      // Globally refresh animal data
      _ref.invalidate(animalsProvider);
      _ref.invalidate(activeAnimalsProvider);
      _ref.invalidate(searchedAnimalsProvider);
    } catch (e) {
      state = state.copyWith(
        status: VoiceState.error,
        errorMessage: e.toString(),
      );
      await _tts.speak("Save failed.");
    }
  }

  Future<void> _savePastureAction(VoicePastureResult p, DateTime now) async {
    final pastureRepo = _ref.read(pastureRepositoryProvider);
    final pastures = await pastureRepo.getAllPastures();
    final target = p.pastureName == null
        ? null
        : pastures
            .where((x) => x.name.toLowerCase() == p.pastureName!.toLowerCase())
            .firstOrNull;

    // Set status — no animal movement.
    if (p.action == PastureVoiceAction.setStatus) {
      if (target == null || p.status == null) {
        throw Exception("Pasture or status not found.");
      }
      var updated = target.copyWith(status: p.status, updatedAt: now);
      if (p.status == PastureStatus.resting) {
        updated = updated.copyWith(
          lastGrazedDate: now,
          availableDate: now.add(Duration(days: target.restDaysTarget)),
        );
      }
      await pastureRepo.updatePasture(updated);
      _ref.invalidate(pasturesListProvider);
      state = state.copyWith(status: VoiceState.success);
      await _tts.speak("${target.name} marked as ${p.status!.name}.");
      return;
    }

    if (target == null) {
      throw Exception("Pasture '${p.pastureName ?? ''}' was not found.");
    }

    final active = (await _ref.read(animalRepositoryProvider).getAllAnimals())
        .where((a) => a.status == AnimalStatus.active)
        .toList();

    // Move a single animal.
    if (p.action == PastureVoiceAction.moveAnimal) {
      final animal = active
          .where((a) => a.name.toLowerCase() == p.animalName?.toLowerCase())
          .firstOrNull;
      if (animal == null) {
        throw Exception("Goat '${p.animalName}' was not found in active herd.");
      }
      await pastureRepo.moveAnimalIntoPasture(
        animalId: animal.id!,
        pastureId: target.id!,
        moveInDate: now,
        notes: 'Moved via voice command',
      );
      _ref.invalidate(pasturesListProvider);
      _ref.invalidate(animalPastureProvider(animal.id!));
      state = state.copyWith(status: VoiceState.success);
      await _tts.speak("${animal.name} moved to ${target.name}.");
      return;
    }

    // Move the whole herd / rotate — move every active animal in.
    if (active.isEmpty) {
      throw Exception("There are no active goats to move.");
    }
    for (final a in active) {
      await pastureRepo.moveAnimalIntoPasture(
        animalId: a.id!,
        pastureId: target.id!,
        moveInDate: now,
        notes: 'Moved via voice command',
      );
    }
    _ref.invalidate(pasturesListProvider);
    for (final a in active) {
      _ref.invalidate(animalPastureProvider(a.id!));
    }
    final verb = p.action == PastureVoiceAction.rotate ? "rotated" : "moved";
    state = state.copyWith(status: VoiceState.success);
    await _tts.speak(
      "The herd has been $verb to ${target.name}. ${active.length} goats updated.",
    );
  }

  String _spokenDate(DateTime d) => DateFormat('EEEE, MMMM d').format(d);

  String _healthSummary(VoiceHealthResult h) {
    switch (h.type) {
      case HealthRecordType.famacha:
        return "a FAMACHA score of ${h.famachaScore}";
      case HealthRecordType.bcs:
        return "a body condition score of ${h.bcsScore}";
      default:
        final d = h.dosage != null ? " with dosage ${h.dosage}" : "";
        return "${h.treatment}$d";
    }
  }

  void cancelSession() {
    _speech.stop();
    _silenceTimer?.cancel();
    state = VoiceCommandState(status: VoiceState.inactive);
    _tts.speak("Cancelled.");
  }

  void cleanup() {
    _speech.stop();
    _tts.stop();
    _silenceTimer?.cancel();
  }

  void _handleSpeechError(String errorMsg) {
    if (!mounted) return;
    debugPrint('🎤 Speech Error: $errorMsg');
    if (state.status == VoiceState.listening ||
        state.status == VoiceState.confirming) {
      String userFriendlyMessage = errorMsg;

      // Provide more helpful error messages
      if (errorMsg.contains('network') || errorMsg.contains('timeout')) {
        userFriendlyMessage =
            'No internet connection. Speech recognition requires an active internet connection.';
      } else if (errorMsg.contains('audio') ||
          errorMsg.contains('microphone')) {
        userFriendlyMessage =
            'Microphone error. Please check microphone permissions in your device settings.';
      } else if (errorMsg.contains('busy')) {
        userFriendlyMessage =
            'Microphone is in use by another app. Please close other apps and try again.';
      } else if (errorMsg.contains('no_match') ||
          errorMsg.contains('nomatch')) {
        userFriendlyMessage =
            'Could not understand speech. Please speak clearly and try again.';
      }

      state = state.copyWith(
        status: VoiceState.error,
        errorMessage: userFriendlyMessage,
      );
      _tts.speak("Sorry, there was an error with speech recognition.");
    }
  }

  void _handleSpeechStatus(String status) {
    if (!mounted) return;
    debugPrint('🎤 Speech Status: $status');
    if (status == 'done' && state.status == VoiceState.listening) {
      stopListeningAndProcess();
    } else if (status == 'notListening' &&
        state.status == VoiceState.listening) {
      debugPrint('🎤 Warning: Speech recognition stopped unexpectedly');
    }
  }

  BirthType _getBirthType(int size) {
    if (size == 1) return BirthType.single;
    if (size == 2) return BirthType.twin;
    if (size == 3) return BirthType.triplet;
    if (size == 4) return BirthType.quad;
    return BirthType.other;
  }

  Future<void> _configureTts() async {
    final settings = _ref.read(settingsStateProvider);
    final double speed =
        double.tryParse(settings['voice_rate'] ?? '0.52') ?? 0.52;
    final double pitch =
        double.tryParse(settings['voice_pitch'] ?? '1.0') ?? 1.0;
    final String? voiceName = settings['voice_name'];

    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
    }
    // Ensure each speak() fully completes before the completion handler fires,
    // preventing overlapping/duplicate utterances.
    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(speed);
    await _tts.setPitch(pitch);
    await _tts.setVolume(1.0);

    if (voiceName != null && voiceName.isNotEmpty) {
      try {
        final List<dynamic>? voices = await _tts.getVoices;
        if (voices != null) {
          final targetVoice = voices.firstWhere(
            (v) => v is Map && v['name']?.toString() == voiceName,
            orElse: () => null,
          );
          if (targetVoice != null && targetVoice is Map) {
            // Create a safe map with non-null string values
            final Map<String, String> safeVoiceMap = {};
            targetVoice.forEach((key, value) {
              if (key != null && value != null) {
                safeVoiceMap[key.toString()] = value.toString();
              }
            });
            if (safeVoiceMap.isNotEmpty) {
              await _tts.setVoice(safeVoiceMap);
            }
          }
        }
      } catch (e) {
        debugPrint('Error setting custom voice: $e');
      }
    }
  }
}
