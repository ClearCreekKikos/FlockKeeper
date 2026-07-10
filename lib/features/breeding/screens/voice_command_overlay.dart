import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/voice_controller.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../data/models/health_record_model.dart';
import '../../../shared/services/voice_parser.dart';
import '../../../shared/providers/providers.dart';
import '../../settings/screens/subscription_paywall_screen.dart';

class VoiceCommandOverlay extends ConsumerStatefulWidget {
  final String? initialQuery;
  const VoiceCommandOverlay({super.key, this.initialQuery});

  static void show(BuildContext context, {String? initialQuery}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceCommandOverlay(initialQuery: initialQuery),
    );
  }

  @override
  ConsumerState<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends ConsumerState<VoiceCommandOverlay> {
  bool _isStarted = false;

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceCommandProvider);
    final voiceNotifier = ref.read(voiceCommandProvider.notifier);
    final settings = ref.watch(settingsStateProvider);
    final isPremium = settings['is_premium'] == 'true';

    // Initialize session automatically when modal starts
    if (isPremium) {
      ref.listen<VoiceCommandState>(voiceCommandProvider, (previous, next) {
        if (next.status == VoiceState.success) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) Navigator.pop(context);
          });
        }
      });
    }

    // Start voice on first build
    if (isPremium) {
      ref.read(voiceCommandProvider); // ensures autoDispose is active
      if (!_isStarted) {
        _isStarted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
            voiceNotifier.processTextQuery(widget.initialQuery!.trim());
          } else {
            voiceNotifier.startVoiceSession();
          }
        });
      }
    }

    if (!isPremium) {
      final primaryColor = Color(int.parse(settings['primary_color'] ?? '0xFF4CAF50'));
      return Container(
        height: MediaQuery.of(context).size.height * 0.45,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: primaryColor, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Siri Hands-Free Controls',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log records and inspect your herd hands-free in the pasture. Voice assistant is a FlockKeeper Premium feature.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context); // Dismiss sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
                );
              },
              child: const Text('Start 30-Day Free Trial', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D).withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          // Top pill indicator
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),

          // Header title
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.keyboard_voice, color: Colors.greenAccent, size: 24),
              SizedBox(width: 8),
              Text(
                'FlockKeeper Voice Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Waveform and state visualization
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _VoiceVisualizer(status: voiceState.status),
                const SizedBox(height: 28),
                Text(
                  _getStatusText(voiceState.status),
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    fontStyle: voiceState.status == VoiceState.listening
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Transcription box
                if (voiceState.transcription.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '"${voiceState.transcription}"',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                const SizedBox(height: 20),

                // Parsed Details Card
                if (voiceState.status == VoiceState.confirming &&
                    voiceState.result != null)
                  _buildParsedDetailsCard(voiceState.result!),

                if (voiceState.status == VoiceState.error &&
                    voiceState.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      voiceState.errorMessage!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Buttons
          _buildActionButtons(context, voiceState.status, voiceNotifier),
        ],
      ),
    );
  }

  String _getStatusText(VoiceState status) {
    switch (status) {
      case VoiceState.inactive:
        return 'Ready to start...';
      case VoiceState.initializing:
        return 'Initializing voice prompt...';
      case VoiceState.readyToListen:
        return 'Preparing microphone...';
      case VoiceState.listening:
        return 'Listening for details... (Speak now)';
      case VoiceState.processing:
        return 'Analyzing details...';
      case VoiceState.confirming:
        return 'Please confirm details. Say "confirm" or tap button.';
      case VoiceState.saving:
        return 'Saving record...';
      case VoiceState.success:
        return 'Saved successfully!';
      case VoiceState.error:
        return 'Could not process.';
    }
  }

  String _healthCategoryLabel(HealthRecordType type) {
    switch (type) {
      case HealthRecordType.famacha:
        return 'FAMACHA';
      case HealthRecordType.bcs:
        return 'Body Condition';
      case HealthRecordType.vaccination:
        return 'Vaccination';
      case HealthRecordType.deworming:
        return 'Deworming';
      case HealthRecordType.antibiotic:
        return 'Antibiotic';
      case HealthRecordType.supplement:
        return 'Supplement';
      case HealthRecordType.grooming:
        return 'Hoof / Grooming';
      case HealthRecordType.labTest:
        return 'Lab Test';
      case HealthRecordType.pregnancyCheck:
        return 'Pregnancy Check';
      case HealthRecordType.illness:
        return 'Illness';
      case HealthRecordType.injury:
        return 'Injury';
      case HealthRecordType.surgery:
        return 'Surgery';
      case HealthRecordType.vetVisit:
        return 'Vet Visit';
      case HealthRecordType.other:
        return 'Treatment';
    }
  }

  Widget _buildParsedDetailsCard(VoiceCommandResult result) {
    String titleText = 'PARSED RECORD DETAILS';
    Widget contentWidget = const SizedBox.shrink();

    if (result.intent == VoiceIntent.weight) {
      final weightRes = result.weightResult!;
      titleText = 'PARSED WEIGHT RECORD';
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goat Name: ${weightRes.animalName ?? "Not Identified"}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Weight: ${weightRes.weight > 0 ? "${weightRes.weight} lbs" : "Not Identified"}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    } else if (result.intent == VoiceIntent.health) {
      final healthRes = result.healthResult!;
      titleText = 'PARSED HEALTH RECORD';
      final String detailLine;
      if (healthRes.type == HealthRecordType.famacha) {
        detailLine = 'FAMACHA Score: ${healthRes.famachaScore ?? "?"}';
      } else if (healthRes.type == HealthRecordType.bcs) {
        detailLine = 'Body Condition Score: ${healthRes.bcsScore ?? "?"}';
      } else {
        detailLine = 'Treatment: ${healthRes.treatment}';
      }
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            healthRes.appliesToHerd
                ? 'Applies to: Whole herd'
                : 'Goat Name: ${healthRes.animalName ?? "Not Identified"}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${_healthCategoryLabel(healthRes.type)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            detailLine,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          if (healthRes.dosage != null) ...[
            const SizedBox(height: 4),
            Text(
              'Dosage: ${healthRes.dosage}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      );
    } else if (result.intent == VoiceIntent.note) {
      final noteRes = result.noteResult!;
      titleText = 'PARSED PROFILE NOTE';
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goat Name: ${noteRes.animalName ?? "Not Identified"}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Note Content:\n"${noteRes.noteText}"',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    } else if (result.intent == VoiceIntent.reminder) {
      final r = result.reminderResult!;
      titleText = 'PARSED REMINDER';
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Task: ${r.title}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Date: ${DateFormat('EEEE, MMMM d, y').format(r.date)}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Type: ${r.type.displayName}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'For: ${r.animalName ?? "Entire herd"}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      );
    } else if (result.intent == VoiceIntent.pasture) {
      final p = result.pastureResult!;
      titleText = 'PARSED PASTURE ACTION';
      String actionLabel;
      switch (p.action) {
        case PastureVoiceAction.moveAnimal:
          actionLabel = 'Move ${p.animalName ?? "goat"} → ${p.pastureName ?? "?"}';
          break;
        case PastureVoiceAction.moveHerd:
          actionLabel = 'Move whole herd → ${p.pastureName ?? "?"}';
          break;
        case PastureVoiceAction.rotate:
          actionLabel = 'Rotate herd → ${p.pastureName ?? "?"}';
          break;
        case PastureVoiceAction.setStatus:
          actionLabel =
              'Mark ${p.pastureName ?? "?"} as ${p.status?.name ?? "?"}';
          break;
      }
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            actionLabel,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (p.pastureName == null) ...[
            const SizedBox(height: 8),
            const Text(
              'Pasture not identified — please retry',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 13),
            ),
          ],
        ],
      );
    } else if (result.intent == VoiceIntent.kidding) {
      final kiddingRes = result.kiddingResult!;
      titleText = 'PARSED KIDDING RECORD';
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mother (Dam): ${kiddingRes.damName ?? "Not Identified"}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Litter Size: ${kiddingRes.litterSize}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ...List.generate(kiddingRes.kids.length, (idx) {
            final kid = kiddingRes.kids[idx];
            return Padding(
              padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    color: Colors.greenAccent.withValues(alpha: 0.6),
                    size: 10,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kid ${idx + 1}: ${kid.sex == KidSex.doe ? "Doe" : (kid.sex == KidSex.buck ? "Buck" : "Unknown")}'
                      '${kid.earTag != null ? " • Tag ${kid.earTag}" : ""}'
                      '${kid.color != null ? " • ${kid.color}" : ""}'
                      '${kid.weight != null ? " • ${kid.weight} lbs" : ""}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titleText,
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          contentWidget,
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    VoiceState status,
    VoiceCommandNotifier notifier,
  ) {
    if (status == VoiceState.success) return const SizedBox(height: 60);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              notifier.cancelSession();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        if (status == VoiceState.confirming)
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => notifier.saveVoiceRecord(),
              child: const Text('Confirm & Save'),
            ),
          )
        else
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: status == VoiceState.listening
                  ? () => notifier.stopListeningAndProcess()
                  : () => notifier.startVoiceSession(),
              child: Text(
                status == VoiceState.listening
                    ? 'Stop & Process'
                    : 'Retry Voice',
              ),
            ),
          ),
      ],
    );
  }
}

/// A modern voice-activity indicator: pulsing rings around a mic while
/// listening, a spinner while processing/saving, and a check/cross on
/// success/error.
class _VoiceVisualizer extends StatefulWidget {
  final VoiceState status;
  const _VoiceVisualizer({required this.status});

  @override
  State<_VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<_VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;

    if (status == VoiceState.success) {
      return const CircleAvatar(
        radius: 44,
        backgroundColor: Colors.green,
        child: Icon(Icons.check_rounded, size: 48, color: Colors.white),
      );
    }
    if (status == VoiceState.error) {
      return CircleAvatar(
        radius: 44,
        backgroundColor: Colors.red.shade400,
        child: const Icon(Icons.close_rounded, size: 48, color: Colors.white),
      );
    }

    final bool processing =
        status == VoiceState.processing || status == VoiceState.saving;
    if (processing) {
      return const SizedBox(
        width: 84,
        height: 84,
        child: CircularProgressIndicator(
          strokeWidth: 4,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
        ),
      );
    }

    final bool listening =
        status == VoiceState.listening || status == VoiceState.confirming;
    final Color accent = listening ? Colors.greenAccent : Colors.white54;

    return SizedBox(
      width: 130,
      height: 130,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (int i = 0; i < 3; i++)
                _ring(accent, (_controller.value + i / 3) % 1.0),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.mic_rounded, color: accent, size: 34),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _ring(Color color, double t) {
    final double size = 66 + t * 60;
    return Opacity(
      opacity: (1 - t) * 0.5,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
        ),
      ),
    );
  }
}
