import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../../shared/providers/providers.dart';
import '../../settings/screens/subscription_paywall_screen.dart';
import '../widgets/scan_listener_dialog.dart';
import 'microchip_batch_add_screen.dart';
import 'microchip_chute_screen.dart';
import 'microchip_loading_screen.dart';
import 'microchip_audit_screen.dart';

class MicrochipHubScreen extends ConsumerWidget {
  const MicrochipHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStateProvider);
    final isPremium = settings['is_premium'] == 'true';
    if (!isPremium) {
      return SubscriptionPaywallScreen(
        onDismiss: () => Navigator.pop(context),
      );
    }

    final workflowCards = [
      _HubCardData(
        title: 'Quick-Scan Batch Add',
        description: 'Set default presets, scan EID, and enter or speak the ear tag. Instantly saves and loops hands-free.',
        icon: Icons.add_moderator,
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MicrochipBatchAddScreen()),
        ),
      ),
      _HubCardData(
        title: 'Scan & View Profile',
        description: 'Scan any microchip to instantly open the animal\'s profile or register them if they aren\'t in the database.',
        icon: Icons.search_off,
        color: Colors.blue,
        onTap: () => ScanListenerDialog.show(context),
      ),
      _HubCardData(
        title: 'Chute Weight & Meds',
        description: 'Run animals through the chute. Scan tag, log weight (via voice/keyboard), and record preset meds/treatments.',
        icon: Icons.health_and_safety,
        color: Colors.teal,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MicrochipChuteScreen()),
        ),
      ),
      _HubCardData(
        title: 'Trailer Loading (Bulk Sale)',
        description: 'Scan EIDs as animals are loaded onto the trailer. Tap to mark all scanned goats as Sold/Removed in one click.',
        icon: Icons.local_shipping,
        color: Colors.amber[800]!,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MicrochipLoadingScreen()),
        ),
      ),
      _HubCardData(
        title: 'Pasture Audit Check',
        description: 'Scan goats in a pasture. Verifies matching locations and shows a checklist of any missing animals.',
        icon: Icons.fact_check,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MicrochipAuditScreen()),
        ),
      ),
    ];

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'microchip_hub'),
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Microchip & EID Hub'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withValues(alpha: 0.05),
              Colors.black.withValues(alpha: 0.15),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: workflowCards.length,
          itemBuilder: (context, index) {
            final card = workflowCards[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: card.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: card.color.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          card.icon,
                          size: 32,
                          color: card.color,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              card.description,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HubCardData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _HubCardData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
