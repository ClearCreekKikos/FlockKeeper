// lib/features/pasture/screens/pasture_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/pasture_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../breeding/screens/voice_command_overlay.dart';
import 'add_edit_pasture_screen.dart';
import 'pasture_detail_screen.dart';
import 'pasture_map_screen.dart';

class PastureDashboardScreen extends ConsumerStatefulWidget {
  const PastureDashboardScreen({super.key});

  @override
  ConsumerState<PastureDashboardScreen> createState() => _PastureDashboardScreenState();
}

class _PastureDashboardScreenState extends ConsumerState<PastureDashboardScreen> {
  String _selectedStatusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final pasturesAsync = ref.watch(pasturesListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Pasture Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'Interactive Map View',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PastureMapScreen()),
              ).then((_) => ref.refresh(pasturesListProvider));
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Pasture',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditPastureScreen()),
              ).then((_) => ref.refresh(pasturesListProvider));
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'pastures'),
      body: pasturesAsync.when(
        data: (pastures) {
          // Calculate stats
          double totalAcreage = 0;
          int occupiedCount = 0;
          int restingCount = 0;
          int availableCount = 0;

          for (final p in pastures) {
            totalAcreage += p.acreage ?? 0;
            switch (p.status) {
              case PastureStatus.occupied:
                occupiedCount++;
                break;
              case PastureStatus.resting:
                restingCount++;
                break;
              case PastureStatus.available:
                availableCount++;
                break;
              case PastureStatus.maintenance:
                break;
            }
          }

          // Apply filters
          final filteredPastures = pastures.where((p) {
            if (_selectedStatusFilter == 'all') return true;
            return p.status.name.toLowerCase() == _selectedStatusFilter.toLowerCase();
          }).toList();

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pasturesListProvider);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ─── Stats Grid ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _buildStatCard(
                          context,
                          'Total Acreage',
                          '${totalAcreage.toStringAsFixed(1)} ac',
                          Icons.landscape_outlined,
                          Colors.green,
                        ),
                        _buildStatCard(
                          context,
                          'Occupied Fields',
                          '$occupiedCount',
                          Icons.grid_view,
                          Colors.teal,
                        ),
                        _buildStatCard(
                          context,
                          'Resting & Recovering',
                          '$restingCount',
                          Icons.restore,
                          Colors.purple,
                        ),
                        _buildStatCard(
                          context,
                          'Available Grazing',
                          '$availableCount',
                          Icons.check_circle_outline,
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ),

                // ─── Filters Chips ─────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Row(
                      children: [
                        _buildFilterChip('all', 'All Pastures'),
                        const SizedBox(width: 8),
                        _buildFilterChip('available', 'Available'),
                        const SizedBox(width: 8),
                        _buildFilterChip('occupied', 'Occupied'),
                        const SizedBox(width: 8),
                        _buildFilterChip('resting', 'Resting'),
                        const SizedBox(width: 8),
                        _buildFilterChip('maintenance', 'Maintenance'),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: Divider(height: 1)),

                // ─── Pastures List ─────────────────────────────────────────────
                if (filteredPastures.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No pastures match the selected filter.'),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final pasture = filteredPastures[index];
                        return _buildPastureCard(context, pasture, isDark);
                      },
                      childCount: filteredPastures.length,
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading pastures: $err')),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 2,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditPastureScreen()),
              ).then((_) => ref.refresh(pasturesListProvider));
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Pasture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterVal, String label) {
    final isSelected = _selectedStatusFilter == filterVal;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedStatusFilter = filterVal;
          });
        }
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 1,
      color: isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPastureCard(BuildContext context, Pasture pasture, bool isDark) {
    final hasCarryingCapacity = pasture.carryingCapacity != null;
    final density = hasCarryingCapacity && pasture.carryingCapacity! > 0
        ? pasture.currentAnimalCount / pasture.carryingCapacity!
        : 0.0;

    Color progressColor = Colors.green;
    if (density > 1.0) {
      progressColor = Colors.red;
    } else if (density > 0.8) {
      progressColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PastureDetailScreen(pastureId: pasture.id!),
            ),
          ).then((_) => ref.refresh(pasturesListProvider));
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      pasture.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(context, pasture),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddEditPastureScreen(pasture: pasture),
                          ),
                        ).then((_) => ref.refresh(pasturesListProvider));
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Pasture'),
                            content: const Text(
                              'Are you sure you want to delete this pasture? Historical grazing logs for this pasture will be removed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(pastureRepositoryProvider).deletePasture(pasture.id!);
                          ref.invalidate(pasturesListProvider);
                        }
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.blue, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Pasture'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Delete Pasture'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Sub-info
              Text(
                '${pasture.acreage ?? 0.0} Acres • Current: ${pasture.currentAnimalCount} Grazers',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 10),

              // Stock Density Gauge (Carrying Capacity Progress Bar)
              if (hasCarryingCapacity) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stocking Rate: ${(density * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: density > 1.0 ? Colors.red : Colors.grey,
                        fontWeight: density > 1.0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      'Cap: ${pasture.carryingCapacity} Head',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: density.clamp(0.0, 1.0),
                    color: progressColor,
                    backgroundColor: isDark ? Colors.white12 : Colors.grey.shade300,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Info parameters row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailTag(context, Icons.grass, pasture.forageType ?? 'Grass'),
                  _buildDetailTag(context, Icons.water_drop, pasture.waterSource ?? 'Water'),
                  _buildDetailTag(context, Icons.fence, pasture.fencingType ?? 'Fence'),
                ],
              ),

              // Recovery progress if resting
              if (pasture.status == PastureStatus.resting && pasture.availableDate != null) ...[
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 16, color: Colors.purple),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        pasture.isReadyToGraze
                            ? 'Rest target completed! Field recovered.'
                            : 'Recovering. Ready in: ${_getRestingDaysRemaining(pasture.availableDate!)} days',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTag(BuildContext context, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            label.length > 12 ? '${label.substring(0, 10)}...' : label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, Pasture pasture) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String text = 'Available';
    MaterialColor color = Colors.green;

    switch (pasture.status) {
      case PastureStatus.available:
        text = 'Available';
        color = Colors.green;
        break;
      case PastureStatus.occupied:
        text = 'Occupied';
        color = Colors.teal;
        break;
      case PastureStatus.resting:
        text = 'Resting';
        color = Colors.purple;
        break;
      case PastureStatus.maintenance:
        text = 'Maintenance';
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.5 : 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? color.shade200 : color.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  int _getRestingDaysRemaining(DateTime date) {
    final diff = date.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff + 1;
  }
}
