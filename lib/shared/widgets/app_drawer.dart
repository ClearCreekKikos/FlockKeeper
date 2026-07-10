import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/providers.dart';
import '../utils/path_resolver.dart';
import '../../features/animals/screens/animal_list_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/breeding/screens/breeding_dashboard_screen.dart';
import '../../features/finances/screens/finances_dashboard_screen.dart';
import '../../features/health/screens/herd_reminders_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/pasture/screens/pasture_dashboard_screen.dart';
import '../../features/batch_entry/screens/batch_config_screen.dart';
import '../../features/microchip/screens/microchip_hub_screen.dart';
import '../../features/weights/screens/weight_analytics_screen.dart';
import '../../features/inventory/screens/inventory_dashboard_screen.dart';
import '../../features/health/screens/fec_calculator_screen.dart';
import '../../features/production/screens/milking_dashboard_screen.dart';
import '../../features/production/screens/meat_dashboard_screen.dart';

class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsStateProvider);
    final farmName = settings['farm_name'] ?? 'FlockKeeper';
    final logoPath = PathResolver.resolvePath(settings['farm_logo_path']);

    return Drawer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ─── Header ────────────────────────────────────────────────────────
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                      ),
                      accountName: Text(
                        farmName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      accountEmail: Text(
                        settings['owner_name']?.isNotEmpty == true
                            ? 'Owner: ${settings['owner_name']}'
                            : 'Kiko Herd Manager',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                      currentAccountPicture: CircleAvatar(
                        backgroundImage: (logoPath != null && File(logoPath).existsSync())
                            ? FileImage(File(logoPath)) as ImageProvider
                            : const AssetImage('assets/images/home_logo.png'),
                        backgroundColor: Colors.transparent,
                      ),
                    ),

                    // ─── Navigation Options ─────────────────────────────────────────────
                    ListTile(
                      leading: const Icon(Icons.home),
                      title: const Text('Home Dashboard'),
                      selected: currentRoute == 'home',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'home') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HomeScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.pets),
                      title: const Text('Animals Herd'),
                      selected: currentRoute == 'animals',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'animals') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const AnimalListScreen()),
                          );
                        }
                      },
                    ),
                    if (settings['module_milking_enabled'] == 'true')
                      ListTile(
                        leading: const Icon(Icons.opacity),
                        title: const Text('Milking Records'),
                        selected: currentRoute == 'milking',
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          if (currentRoute != 'milking') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MilkingDashboardScreen()),
                            );
                          }
                        },
                      ),
                    if (settings['module_meat_enabled'] == 'true')
                      ListTile(
                        leading: const Icon(Icons.restaurant),
                        title: const Text('Meat Production'),
                        selected: currentRoute == 'meat',
                        onTap: () {
                          Navigator.pop(context); // close drawer
                          if (currentRoute != 'meat') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => const MeatDashboardScreen()),
                            );
                          }
                        },
                      ),
                    ListTile(
                      leading: const Icon(Icons.table_chart),
                      title: const Text('Batch Entry'),
                      selected: currentRoute == 'batch_entry',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'batch_entry') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const BatchConfigScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.sensors),
                      title: const Text('Microchip Hub'),
                      selected: currentRoute == 'microchip_hub',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'microchip_hub') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const MicrochipHubScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.analytics),
                      title: const Text('Weight Analytics'),
                      selected: currentRoute == 'weight_analytics',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'weight_analytics') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const WeightAnalyticsScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.favorite),
                      title: const Text('Breeding Manager'),
                      selected: currentRoute == 'breeding',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'breeding') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const BreedingDashboardScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.monetization_on),
                      title: const Text('Cash Flow'),
                      selected: currentRoute == 'finances',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'finances') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const FinancesDashboardScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.calendar_month),
                      title: const Text('Herd Schedule'),
                      selected: currentRoute == 'reminders',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'reminders') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const HerdRemindersScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.landscape),
                      title: const Text('Pastures & Grazing'),
                      selected: currentRoute == 'pastures',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'pastures') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const PastureDashboardScreen()),
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: const Text('Ranch Supplies'),
                      selected: currentRoute == 'inventory',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        if (currentRoute != 'inventory') {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const InventoryDashboardScreen()),
                          );
                        }
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.calculate_outlined),
                      title: const Text('FEC & FERC Calculators'),
                      selected: currentRoute == 'fec_calculator',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FecCalculatorScreen()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      selected: currentRoute == 'settings',
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.help_outline),
                      title: const Text('Support & Help'),
                      onTap: () async {
                        Navigator.pop(context); // close drawer
                        final url = Uri.parse('https://sites.google.com/clearcreekforge.com/clearcreekforge/support');
                        try {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          debugPrint('Could not launch support URL: $e');
                        }
                      },
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final version = snapshot.data?.version ?? '1.1.0';
                          final build = snapshot.data?.buildNumber ?? '10';
                          return Text(
                            'FlockKeeper v$version+$build',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
