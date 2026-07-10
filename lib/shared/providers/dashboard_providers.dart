import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/providers.dart';

final dashboardProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(herdServiceProvider);
  return service.getDashboardStats();
});
