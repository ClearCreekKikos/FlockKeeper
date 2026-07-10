import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/breeding_event_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../providers/breeding_providers.dart';
import 'add_edit_breeding_screen.dart';
import 'record_kidding_screen.dart';
import 'edit_kidding_record_screen.dart';
import 'voice_command_overlay.dart';

class BreedingDashboardScreen extends ConsumerStatefulWidget {
  const BreedingDashboardScreen({super.key});

  @override
  ConsumerState<BreedingDashboardScreen> createState() => _BreedingDashboardScreenState();
}

class _BreedingDashboardScreenState extends ConsumerState<BreedingDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(breedingStatsProvider);
    final breedingListAsync = ref.watch(breedingListProvider);
    final kiddingListAsync = ref.watch(kiddingRecordsListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Breeding Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice Commands',
            onPressed: () => VoiceCommandOverlay.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: _tabController.index == 0 ? 'Add Breeding Event' : 'Record Kidding Record',
            onPressed: () {
              if (_tabController.index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditBreedingScreen()),
                ).then((_) {
                  ref.invalidate(breedingListProvider);
                  ref.invalidate(breedingStatsProvider);
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordKiddingScreen(breedingEvent: null)),
                ).then((_) {
                  ref.invalidate(kiddingRecordsListProvider);
                  ref.invalidate(breedingListProvider);
                  ref.invalidate(breedingStatsProvider);
                });
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.favorite), text: 'Breeding Events'),
            Tab(icon: Icon(Icons.child_care), text: 'Kidding Records'),
          ],
        ),
      ),
      drawer: const AppDrawer(currentRoute: 'breeding'),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ─── TAB 1: Breeding Events & Stats ──────────────────────────────
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(breedingListProvider);
              ref.invalidate(breedingStatsProvider);
            },
            child: CustomScrollView(
              slivers: [
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
                          'Total Breedings',
                          '${stats.totalBreedings}',
                          Icons.pets,
                          Colors.green,
                        ),
                        _buildStatCard(
                          context,
                          'Active Pregnancies',
                          '${stats.activePregnancies}',
                          Icons.favorite,
                          Colors.pink,
                        ),
                        _buildStatCard(
                          context,
                          'Conception Rate',
                          '${stats.conceptionRate.toStringAsFixed(1)}%',
                          Icons.check_circle,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          context,
                          'Upcoming Kidding',
                          '${stats.upcomingKiddings30Days}',
                          Icons.alarm,
                          Colors.orange,
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Divider(height: 1),
                ),
                // Breeding Events List
                breedingListAsync.when(
                  data: (events) {
                    if (events.isEmpty) {
                      return const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No breeding events logged.'),
                          ),
                        ),
                      );
                    }
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final event = events[index];
                          return _buildBreedingEventCard(context, ref, event, isDark);
                        },
                        childCount: events.length,
                      ),
                    );
                  },
                  loading: () => const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('Error: $err')),
                  ),
                ),
              ],
            ),
          ),

          // ─── TAB 2: Kidding Records History ──────────────────────────────
          kiddingListAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return const Center(child: Text('No kidding records logged.'));
              }
              return RefreshIndicator(
                onRefresh: () async => ref.refresh(kiddingRecordsListProvider),
                child: ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return _buildKiddingRecordCard(context, ref, record);
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ],
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
              if (_tabController.index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddEditBreedingScreen()),
                ).then((_) {
                  ref.invalidate(breedingListProvider);
                  ref.invalidate(breedingStatsProvider);
                });
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RecordKiddingScreen(breedingEvent: null)),
                ).then((_) {
                  ref.invalidate(kiddingRecordsListProvider);
                  ref.invalidate(breedingListProvider);
                  ref.invalidate(breedingStatsProvider);
                });
              }
            },
            icon: Icon(_tabController.index == 0 ? Icons.add : Icons.child_care),
            label: Text(
              _tabController.index == 0 ? 'Add Breeding' : 'Record Kidding',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Summary Stat Card Builder ───────────────────────────────────────────
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

  // ─── Breeding Event List Tile Builder ──────────────────────────────────────
  Widget _buildBreedingEventCard(
    BuildContext context,
    WidgetRef ref,
    BreedingEvent event,
    bool isDark,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          'Dam: ${event.doeName ?? "Unknown Doe (#${event.doeId})"}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Sire: ${event.buckName ?? "Unknown Sire (#${event.buckId})"}'),
            const SizedBox(height: 2),
            Text('Bred: ${DateFormat.yMMMd().format(event.breedingDate)} • ${event.methodDisplay}'),
            if (event.expectedKidDate != null && event.actualKidDate == null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Due: ${DateFormat.yMMMd().format(event.expectedKidDate!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: event.isOverdue
                            ? Colors.red
                            : event.isKiddingSoon
                                ? Colors.orange
                                : Colors.grey.shade600,
                        fontWeight: event.isOverdue || event.isKiddingSoon
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            if (event.actualKidDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  'Kidded on: ${DateFormat.yMMMd().format(event.actualKidDate!)}',
                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                ),
              ),
            if (event.notes != null && event.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final notesText = event.notes!;
                  final cidrInsertRegex = RegExp(r'CIDR Inserted:\s*([0-9\-]+)');
                  final cidrRemoveRegex = RegExp(r'CIDR Removed:\s*([0-9\-]+)');
                  final hormonesRegex = RegExp(r'Prep Hormones:\s*([^\n]+)');

                  final cidrInsert = cidrInsertRegex.firstMatch(notesText)?.group(1);
                  final cidrRemove = cidrRemoveRegex.firstMatch(notesText)?.group(1);
                  final hormones = hormonesRegex.firstMatch(notesText)?.group(1);

                  final prepBlockRegex = RegExp(r'=== BREEDING PREP ===[\s\S]*?=====================\n\n?');
                  final displayNotes = notesText.replaceAll(prepBlockRegex, '').trim();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cidrInsert != null || cidrRemove != null || hormones != null) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (cidrInsert != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueGrey.shade100),
                                ),
                                child: Text('CIDR In: $cidrInsert', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                              ),
                            if (cidrRemove != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueGrey.shade100),
                                ),
                                child: Text('CIDR Out: $cidrRemove', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                              ),
                            if (hormones != null && hormones.trim().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.purple.shade100),
                                ),
                                child: Text('Prep: $hormones', style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        if (displayNotes.isNotEmpty) const SizedBox(height: 6),
                      ],
                      if (displayNotes.isNotEmpty)
                        Text(
                          'Notes: $displayNotes',
                          style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBadge(context, event),
            const SizedBox(width: 6),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'kidding') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecordKiddingScreen(breedingEvent: event),
                    ),
                  );
                } else if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddEditBreedingScreen(breedingEvent: event),
                    ),
                  );
                } else if (value == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Breeding Record'),
                      content: const Text('Are you sure you want to delete this breeding event?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref.read(breedingRepositoryProvider).deleteBreedingEvent(event.id!);
                    ref.invalidate(breedingListProvider);
                  }
                }
              },
              itemBuilder: (ctx) => [
                if (event.isActivePregnancy)
                  const PopupMenuItem(
                    value: 'kidding',
                    child: Row(
                      children: [
                        Icon(Icons.child_care, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Record Kidding'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Text('Edit Breeding'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete Record'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Status Badge Builder ────────────────────────────────────────────────
  Widget _buildStatusBadge(BuildContext context, BreedingEvent event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String text = 'Logged';
    MaterialColor color = Colors.grey;

    if (event.actualKidDate != null || event.outcome == BreedingOutcome.kidded) {
      text = 'Kidded';
      color = Colors.green;
    } else if (event.isOverdue) {
      text = 'Overdue';
      color = Colors.red;
    } else if (event.isKiddingSoon) {
      text = 'Due Soon';
      color = Colors.orange;
    } else if (event.confirmedPregnant) {
      text = 'Pregnant';
      color = Colors.pink;
    } else if (event.outcome == BreedingOutcome.open) {
      text = 'Open';
      color = Colors.blueGrey;
    } else if (event.outcome == BreedingOutcome.aborted) {
      text = 'Aborted';
      color = Colors.deepOrange;
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

  // ─── Kidding Record Card Builder ─────────────────────────────────────────
  Widget _buildKiddingRecordCard(
    BuildContext context,
    WidgetRef ref,
    KiddingRecord record,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FutureBuilder(
                    future: ref.read(animalRepositoryProvider).getAnimalById(record.doeId),
                    builder: (context, snapshot) {
                      final doeName = snapshot.data?.name ?? 'Doe #${record.doeId}';
                      return Text(
                        'Dam: $doeName',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Text(
                  DateFormat.yMMMd().format(record.kiddingDate),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditKiddingRecordScreen(record: record),
                        ),
                      ).then((_) {
                        ref.invalidate(kiddingRecordsListProvider);
                        ref.invalidate(breedingStatsProvider);
                      });
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Kidding Record'),
                          content: const Text('Are you sure you want to delete this kidding record? This will not delete the kid animal record from the herd list.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(kiddingRepositoryProvider).deleteKiddingRecord(record.id!);
                        ref.invalidate(kiddingRecordsListProvider);
                        ref.invalidate(breedingStatsProvider);
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
                          Text('Edit Record'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Delete Record'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              children: [
                _buildInfoChip(context, 'Litter Size: ${record.litterSize ?? 1}', Icons.grid_view, Colors.blue),
                const SizedBox(width: 8),
                _buildInfoChip(
                  context,
                  record.survivalDisplay,
                  record.isAlive ? Icons.check_circle : Icons.warning,
                  record.isAlive ? Colors.green : Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (record.kidName != null && record.kidName!.isNotEmpty)
              Text(
                'Kid Registered: ${record.kidName} (${record.sex == KidSex.doe ? "Doe" : "Buck"}${record.birthWeightLbs != null ? " • ${record.birthWeightLbs} lbs" : ""})',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            if (record.complications != null && record.complications!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Complications: ${record.complications}',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            if (record.notes != null && record.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Notes: ${record.notes}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, IconData icon, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? color.shade200 : color.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
