import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/models/animal_model.dart';
import '../../../data/models/kidding_record_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/animal_providers.dart';
import '../providers/breeding_providers.dart';

class EditKiddingRecordScreen extends ConsumerStatefulWidget {
  final KiddingRecord record;

  const EditKiddingRecordScreen({super.key, required this.record});

  @override
  ConsumerState<EditKiddingRecordScreen> createState() => _EditKiddingRecordScreenState();
}

class _EditKiddingRecordScreenState extends ConsumerState<EditKiddingRecordScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _kiddingDate;
  late int _litterSize;
  late int _birthOrder;
  late KidSex _sex;
  late Presentation _presentation;
  late SurvivalStatus _survivalStatus;
  late bool _receivedColostrum;
  late bool _bottleFed;
  int? _damConditionScore;

  late TextEditingController _kidNameController;
  late TextEditingController _weightController;
  late TextEditingController _complicationsController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    _kiddingDate = r.kiddingDate;
    _litterSize = r.litterSize ?? 1;
    _birthOrder = r.birthOrder ?? 1;
    _sex = r.sex;
    _presentation = r.presentation ?? Presentation.normal;
    _survivalStatus = r.survivalStatus;
    _receivedColostrum = r.receivedColostrum;
    _bottleFed = r.bottleFed;
    _damConditionScore = r.damConditionScore;

    _kidNameController = TextEditingController(text: r.kidName ?? '');
    _weightController = TextEditingController(text: r.birthWeightLbs != null ? r.birthWeightLbs.toString() : '');
    _complicationsController = TextEditingController(text: r.complications ?? '');
    _notesController = TextEditingController(text: r.notes ?? '');
  }

  @override
  void dispose() {
    _kidNameController.dispose();
    _weightController.dispose();
    _complicationsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectKiddingDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kiddingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _kiddingDate = picked;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final kiddingRepo = ref.read(kiddingRepositoryProvider);
    final animalRepo = ref.read(animalRepositoryProvider);

    final kidName = _kidNameController.text.trim();
    final weight = double.tryParse(_weightController.text.trim());

    final updatedRecord = widget.record.copyWith(
      kiddingDate: _kiddingDate,
      litterSize: _litterSize,
      birthOrder: _birthOrder,
      sex: _sex,
      presentation: _presentation,
      survivalStatus: _survivalStatus,
      receivedColostrum: _receivedColostrum,
      bottleFed: _bottleFed,
      damConditionScore: _damConditionScore,
      kidName: kidName.isNotEmpty ? kidName : null,
      birthWeightLbs: weight,
      complications: _complicationsController.text.trim(),
      notes: _notesController.text.trim(),
    );

    try {
      // 1. Update the kidding record
      await kiddingRepo.updateKiddingRecord(updatedRecord);

      // 2. If this kidding record is linked to a kid animal, update the kid's animal profile to match!
      if (widget.record.kidId != null) {
        final kidAnimal = await animalRepo.getAnimalById(widget.record.kidId!);
        if (kidAnimal != null) {
          final updatedKid = kidAnimal.copyWith(
            name: kidName.isNotEmpty ? kidName : kidAnimal.name,
            dob: _kiddingDate,
            sex: _sex == KidSex.doe ? Sex.doe : (_sex == KidSex.buck ? Sex.buck : Sex.unknown),
            birthWeightLbs: weight,
          );
          await animalRepo.updateAnimal(updatedKid);
        }
      }

      // Invalidate providers
      ref.invalidate(kiddingRecordsListProvider);
      ref.invalidate(breedingStatsProvider);
      ref.invalidate(animalsProvider);
      ref.invalidate(activeAnimalsProvider);
      ref.invalidate(searchedAnimalsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kidding record updated successfully.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating kidding record: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Kidding Record'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kid Name
            TextFormField(
              controller: _kidNameController,
              decoration: const InputDecoration(labelText: 'Kid Name'),
            ),
            const SizedBox(height: 12),

            // Kidding Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Kidding Date *'),
              subtitle: Text(DateFormat.yMMMd().format(_kiddingDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectKiddingDate(context),
            ),
            const SizedBox(height: 12),

            // Litter Size
            DropdownButtonFormField<int>(
              initialValue: _litterSize,
              decoration: const InputDecoration(labelText: 'Litter Size (Number of Kids) *'),
              items: [1, 2, 3, 4, 5].map((s) {
                return DropdownMenuItem(value: s, child: Text('$s'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _litterSize = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Birth Order
            DropdownButtonFormField<int>(
              initialValue: _birthOrder,
              decoration: const InputDecoration(labelText: 'Birth Order *'),
              items: [1, 2, 3, 4, 5].map((s) {
                return DropdownMenuItem(value: s, child: Text('$s'));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _birthOrder = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Sex
            DropdownButtonFormField<KidSex>(
              initialValue: _sex,
              decoration: const InputDecoration(labelText: 'Sex *'),
              items: KidSex.values.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _sex = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Weight
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Birth Weight (lbs)', suffixText: 'lbs'),
            ),
            const SizedBox(height: 12),

            // Presentation
            DropdownButtonFormField<Presentation>(
              initialValue: _presentation,
              decoration: const InputDecoration(labelText: 'Presentation'),
              items: Presentation.values.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p.name[0].toUpperCase() + p.name.substring(1)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _presentation = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Survival Status
            DropdownButtonFormField<SurvivalStatus>(
              initialValue: _survivalStatus,
              decoration: const InputDecoration(labelText: 'Survival Status *'),
              items: SurvivalStatus.values.map((s) {
                String label;
                switch (s) {
                  case SurvivalStatus.alive: label = 'Alive'; break;
                  case SurvivalStatus.diedAtBirth: label = 'Died at Birth'; break;
                  case SurvivalStatus.diedWithin24h: label = 'Died within 24h'; break;
                  case SurvivalStatus.diedWithinWeek: label = 'Died within a Week'; break;
                  case SurvivalStatus.diedLater: label = 'Died Later'; break;
                  case SurvivalStatus.sold: label = 'Sold'; break;
                }
                return DropdownMenuItem(value: s, child: Text(label));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _survivalStatus = val;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            // Dam BCS
            DropdownButtonFormField<int>(
              initialValue: _damConditionScore,
              decoration: const InputDecoration(labelText: 'Dam Condition Score at Kidding'),
              items: [null, 1, 2, 3, 4, 5].map((s) {
                return DropdownMenuItem(value: s, child: Text(s != null ? '$s' : 'Not Recorded'));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _damConditionScore = val;
                });
              },
            ),
            const SizedBox(height: 12),

            // Checkboxes
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Received Colostrum', style: TextStyle(fontSize: 12)),
                    contentPadding: EdgeInsets.zero,
                    value: _receivedColostrum,
                    onChanged: (val) => setState(() => _receivedColostrum = val ?? true),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Bottle Fed', style: TextStyle(fontSize: 12)),
                    contentPadding: EdgeInsets.zero,
                    value: _bottleFed,
                    onChanged: (val) => setState(() => _bottleFed = val ?? false),
                  ),
                ),
              ],
            ),
            const Divider(),

            // Complications
            TextFormField(
              controller: _complicationsController,
              decoration: const InputDecoration(labelText: 'Birth Complications (If Any)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'General Notes'),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _save,
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
