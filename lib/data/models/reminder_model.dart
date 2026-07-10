import '../../shared/utils/date_helper.dart';

enum ReminderType {
  vaccination,
  deworming,
  breeding,
  kidding,
  weigh,
  vet,
  pasture,
  testing,
  custom;

  String get displayName {
    switch (this) {
      case ReminderType.vaccination:
        return 'Vaccination';
      case ReminderType.deworming:
        return 'Deworming';
      case ReminderType.breeding:
        return 'Breeding';
      case ReminderType.kidding:
        return 'Kidding';
      case ReminderType.weigh:
        return 'Weigh-in';
      case ReminderType.vet:
        return 'Vet Visit';
      case ReminderType.pasture:
        return 'Pasture Rotation';
      case ReminderType.testing:
        return 'Testing (FAMACHA, BCS, FEC, etc.)';
      case ReminderType.custom:
        return 'Custom Event';
    }
  }
}

class Reminder {
  final int? id;
  final int? animalId;
  final String title;
  final String? description;
  final DateTime reminderDate;
  final ReminderType reminderType;
  final bool isCompleted;
  final DateTime? completedDate;
  final bool isRecurring;
  final int? recurrenceDays;
  final int notifyDaysBefore;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? animalName; // Populated via join query

  const Reminder({
    this.id,
    this.animalId,
    required this.title,
    this.description,
    required this.reminderDate,
    required this.reminderType,
    this.isCompleted = false,
    this.completedDate,
    this.isRecurring = false,
    this.recurrenceDays,
    this.notifyDaysBefore = 3,
    this.createdAt,
    this.updatedAt,
    this.animalName,
  });

  factory Reminder.fromMap(Map<String, dynamic> map) {
    ReminderType type;
    try {
      type = ReminderType.values.firstWhere(
        (e) => e.name == map['reminder_type'],
        orElse: () => ReminderType.custom,
      );
    } catch (_) {
      type = ReminderType.custom;
    }

    return Reminder(
      id: map['id'] as int?,
      animalId: map['animal_id'] as int?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      reminderDate: parseDateTimeSafe(map['reminder_date']),
      reminderType: type,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      completedDate: map['completed_date'] != null
          ? parseDateTimeSafe(map['completed_date'])
          : null,
      isRecurring: (map['is_recurring'] as int? ?? 0) == 1,
      recurrenceDays: map['recurrence_days'] as int?,
      notifyDaysBefore: map['notify_days_before'] as int? ?? 3,
      createdAt: map['created_at'] != null
          ? parseDateTimeSafe(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? parseDateTimeSafe(map['updated_at'])
          : null,
      animalName: map['animal_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'animal_id': animalId,
      'title': title,
      'description': description,
      'reminder_date': reminderDate.toIso8601String(),
      'reminder_type': reminderType.name,
      'is_completed': isCompleted ? 1 : 0,
      'completed_date': completedDate?.toIso8601String(),
      'is_recurring': isRecurring ? 1 : 0,
      'recurrence_days': recurrenceDays,
      'notify_days_before': notifyDaysBefore,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  Reminder copyWith({
    int? id,
    int? animalId,
    String? title,
    String? description,
    DateTime? reminderDate,
    ReminderType? reminderType,
    bool? isCompleted,
    DateTime? completedDate,
    bool? isRecurring,
    int? recurrenceDays,
    int? notifyDaysBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? animalName,
  }) {
    return Reminder(
      id: id ?? this.id,
      animalId: animalId ?? this.animalId,
      title: title ?? this.title,
      description: description ?? this.description,
      reminderDate: reminderDate ?? this.reminderDate,
      reminderType: reminderType ?? this.reminderType,
      isCompleted: isCompleted ?? this.isCompleted,
      completedDate: completedDate ?? this.completedDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      notifyDaysBefore: notifyDaysBefore ?? this.notifyDaysBefore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      animalName: animalName ?? this.animalName,
    );
  }
}
