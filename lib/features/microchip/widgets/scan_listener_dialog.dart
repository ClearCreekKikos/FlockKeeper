import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../animals/screens/add_edit_animal_screen.dart';
import '../../../shared/providers/providers.dart';

class ScanListenerDialog extends ConsumerStatefulWidget {
  const ScanListenerDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const ScanListenerDialog(),
    );
  }

  @override
  ConsumerState<ScanListenerDialog> createState() => _ScanListenerDialogState();
}

class _ScanListenerDialogState extends ConsumerState<ScanListenerDialog> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _animController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Autofocus text field immediately on next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitted(String value) async {
    final scanned = value.trim();
    if (scanned.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    final repo = ref.read(animalRepositoryProvider);
    final animal = await repo.getAnimalByRfidTag(scanned);

    if (!mounted) return;

    if (animal != null) {
      // Found the animal! Close this scan dialog and open animal edit screen.
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddEditAnimalScreen(animal: animal),
        ),
      );
    } else {
      // Animal not found. Ask to create.
      setState(() {
        _isProcessing = false;
        _controller.clear();
      });

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Goat Not Found'),
          content: Text('EID Tag "$scanned" is not registered in your herd.\n\nWould you like to register a new goat with this tag?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx); // close confirmation
                _focusNode.requestFocus(); // refocus scanner
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx); // close confirmation
                Navigator.pop(context); // close scanner dialog
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddEditAnimalScreen(initialRfidTag: scanned),
                  ),
                );
              },
              child: const Text('Register Goat'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Hidden text field off-screen to capture scanner input
          Opacity(
            opacity: 0.0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                onSubmitted: _handleSubmitted,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    Text(
                      'Ready to Scan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withValues(alpha: 0.1 + (_animController.value * 0.1)),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3 + (_animController.value * 0.7)),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.sensors,
                        size: 64,
                        color: Colors.blue,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Text(
                  'Scan the animal\'s microchip now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Bluetooth/USB reader will automatically enter the EID number.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
                const SizedBox(height: 16),
                // Fallback direct text input if scan failed
                TextButton(
                  onPressed: () {
                    // Refocus keyboard input if user clicks
                    _focusNode.requestFocus();
                  },
                  child: const Text('Ensure Scanner Focused'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
