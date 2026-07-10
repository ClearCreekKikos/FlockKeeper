import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../microchip/widgets/scan_listener_dialog.dart';
import '../../settings/screens/subscription_paywall_screen.dart';
import '../../animals/screens/animal_list_screen.dart';
import '../../breeding/screens/breeding_dashboard_screen.dart';
import '../../finances/screens/finances_dashboard_screen.dart';
import '../../health/screens/herd_reminders_screen.dart';
import '../../health/screens/fec_calculator_screen.dart';
import '../../inventory/screens/inventory_dashboard_screen.dart';
import '../../pasture/screens/pasture_dashboard_screen.dart';
import '../../batch_entry/screens/batch_config_screen.dart';
import '../../microchip/screens/microchip_hub_screen.dart';
import '../../settings/screens/settings_screen.dart';
import '../../../shared/providers/providers.dart';
import '../../production/screens/milking_dashboard_screen.dart';
import '../../production/screens/meat_dashboard_screen.dart';
import '../../../data/models/animal_model.dart';
import '../../../shared/providers/animal_providers.dart';
import '../../weights/screens/weight_analytics_screen.dart';
import '../../weights/screens/weight_history_screen.dart';
import '../../health/screens/health_dashboard_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Golden/Orange color scheme inspired by the FlockKeeper shield logo
    const primaryGold = Color(0xFFF39C12);
    const accentOrange = Color(0xFFD35400);

    final settings = ref.watch(settingsStateProvider);
    final showMilking = settings['module_milking_enabled'] == 'true';
    final showMeat = settings['module_meat_enabled'] == 'true';

    final navigationItems = [
      _HomeNavTile(
        title: 'Animals Herd',
        subtitle: 'Manage active stock',
        icon: Icons.pets,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnimalListScreen())),
      ),
      if (showMilking)
        _HomeNavTile(
          title: 'Milking Records',
          subtitle: 'Dairy milk production',
          icon: Icons.opacity,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MilkingDashboardScreen())),
        ),
      if (showMeat)
        _HomeNavTile(
          title: 'Meat Production',
          subtitle: 'Carcass weight & yields',
          icon: Icons.restaurant,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeatDashboardScreen())),
        ),
      _HomeNavTile(
        title: 'Breeding Manager',
        subtitle: 'Track kidding & cycles',
        icon: Icons.favorite,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BreedingDashboardScreen())),
      ),
      _HomeNavTile(
        title: 'Pastures & Grazing',
        subtitle: 'Map & pasture records',
        icon: Icons.landscape,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PastureDashboardScreen())),
      ),
      _HomeNavTile(
        title: 'Ranch Supplies',
        subtitle: 'Inventory & stock levels',
        icon: Icons.inventory_2,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryDashboardScreen())),
      ),
      _HomeNavTile(
        title: 'Cash Flow',
        subtitle: 'Financial ledger & reports',
        icon: Icons.monetization_on,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancesDashboardScreen())),
      ),
      _HomeNavTile(
        title: 'Weight Analytics',
        subtitle: 'ADG & growth trends',
        icon: Icons.analytics,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeightAnalyticsScreen())),
      ),
      _HomeNavTile(
        title: 'Health Records',
        subtitle: 'Medical logs & history',
        icon: Icons.medical_services_outlined,
        onTap: () => _selectAnimalAndNavigate(
          context,
          ref,
          'Select Animal for Health Records',
          (animal) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HealthDashboardScreen(animal: animal)),
          ),
        ),
      ),
      _HomeNavTile(
        title: 'Weight History',
        subtitle: 'Individual weight logs',
        icon: Icons.scale,
        onTap: () => _selectAnimalAndNavigate(
          context,
          ref,
          'Select Animal for Weight History',
          (animal) => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => WeightDashboardScreen(animal: animal)),
          ),
        ),
      ),
      _HomeNavTile(
        title: 'Herd Schedule',
        subtitle: 'Reminders & medical log',
        icon: Icons.calendar_month,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HerdRemindersScreen())),
      ),
      _HomeNavTile(
        title: 'FEC Calculator',
        subtitle: 'Parasite dosage tools',
        icon: Icons.calculate_outlined,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FecCalculatorScreen())),
      ),
      _HomeNavTile(
        title: 'Batch Entry',
        subtitle: 'Bulk record updates',
        icon: Icons.table_chart,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchConfigScreen())),
      ),
      _HomeNavTile(
        title: 'Microchip Hub',
        subtitle: 'EID scanner workflows',
        icon: Icons.sensors,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MicrochipHubScreen())),
      ),
      _HomeNavTile(
        title: 'Settings',
        subtitle: 'Farm & sync controls',
        icon: Icons.settings,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
    ];

    return Scaffold(
      drawer: const AppDrawer(currentRoute: 'home'),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final isPremium = ref.read(settingsStateProvider)['is_premium'] == 'true';
          if (!isPremium) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionPaywallScreen()),
            );
          } else {
            ScanListenerDialog.show(context);
          }
        },
        backgroundColor: primaryGold,
        tooltip: 'Scan EID Microchip',
        child: const Icon(Icons.sensors, color: Colors.white),
      ),
      body: Stack(
        children: [
          // ─── Wallpaper background ─────────────────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/home_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          // Dark gradient overlay to ensure legibility of foreground text/cards
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // ─── Foreground Contents ──────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Top Header Banner with FlockKeeper logo
                _buildHeaderBanner(context),

                // Grid list of navigation options
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 180,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: navigationItems.length,
                    itemBuilder: (context, index) {
                      final tile = navigationItems[index];
                      return _buildNavCard(context, tile, primaryGold, accentOrange);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                  child: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '1.2.3';
                      final build = snapshot.data?.buildNumber ?? '47';
                      return Text(
                        'v$version+$build',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Drawer toggle button (since we use a custom wallpaper body without a standard AppBar)
          Positioned(
            top: 10,
            left: 10,
            child: SafeArea(
              child: Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final logoHeight = (screenHeight * 0.15).clamp(80.0, 160.0);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 2),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 24),
      child: Column(
        children: [
          Image.asset(
            'assets/images/home_logo.png',
            height: logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.pets,
              size: 50,
              color: Color(0xFFF39C12),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'HERD MANAGEMENT SYSTEM',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
              color: Color(0xFFF39C12),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAnimalAndNavigate(
    BuildContext context,
    WidgetRef ref,
    String title,
    void Function(Animal) onSelected,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final animalsAsync = ref.watch(activeAnimalsProvider);
            return AlertDialog(
              title: Text(title),
              content: animalsAsync.when(
                loading: () => const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Text('Error loading herd list: $err'),
                data: (animals) {
                  if (animals.isEmpty) {
                    return const Text('No active animals found in the herd registry.');
                  }
                  return _SearchableAnimalList(
                    animals: animals,
                    onSelected: (animal) {
                      Navigator.pop(context);
                      onSelected(animal);
                    },
                  );
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildNavCard(
    BuildContext context,
    _HomeNavTile tile,
    Color primaryGold,
    Color accentOrange,
  ) {
    return Card(
      elevation: 4,
      color: Colors.black.withValues(alpha: 0.65), // Glassmorphism container
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: primaryGold.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: tile.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon wrapped in gold/orange gradient container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [primaryGold, accentOrange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentOrange.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  tile.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tile.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                tile.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeNavTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _HomeNavTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _SearchableAnimalList extends StatefulWidget {
  final List<Animal> animals;
  final void Function(Animal) onSelected;

  const _SearchableAnimalList({
    required this.animals,
    required this.onSelected,
  });

  @override
  State<_SearchableAnimalList> createState() => _SearchableAnimalListState();
}

class _SearchableAnimalListState extends State<_SearchableAnimalList> {
  late List<Animal> _filtered;
  final _controller = TextEditingController();
  String _selectedStatus = 'Active';

  @override
  void initState() {
    super.initState();
    _applyFilter();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final query = _controller.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.animals.where((a) {
        if (_selectedStatus != 'All') {
          final targetStatus = _selectedStatus == 'Active'
              ? AnimalStatus.active
              : (_selectedStatus == 'Sold'
                  ? AnimalStatus.sold
                  : AnimalStatus.deceased);
          if (a.status != targetStatus) {
            return false;
          }
        }
        if (query.isNotEmpty) {
          final name = a.name.toLowerCase();
          final tag = a.earTag?.toLowerCase() ?? '';
          return name.contains(query) || tag.contains(query);
        }
        return true;
      }).toList();
    });
  }

  void _filter(String query) {
    _applyFilter();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: const InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: _filter,
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _selectedStatus,
                dropdownColor: isDark ? Colors.grey.shade900 : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                items: ['Active', 'Sold', 'Deceased', 'All'].map((s) {
                  return DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatus = val;
                      _applyFilter();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SizedBox(
              height: 250,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final animal = _filtered[index];
                  final statusSuffix = animal.status != AnimalStatus.active 
                      ? ' (${animal.status.name.toUpperCase()})' 
                      : '';
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        animal.name.isNotEmpty ? animal.name[0].toUpperCase() : '🐐',
                        style: TextStyle(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    title: Text(
                      '${animal.name}$statusSuffix',
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                    subtitle: Text(
                      animal.earTag ?? 'No Ear Tag',
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                    ),
                    onTap: () => widget.onSelected(animal),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
