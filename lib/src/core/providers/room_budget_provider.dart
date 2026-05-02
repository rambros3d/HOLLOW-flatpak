import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomBudget {
  final int joined;
  final int limit;

  const RoomBudget({this.joined = 0, this.limit = 2000});

  double get usage => limit > 0 ? joined / limit : 0.0;
  int get remaining => (limit - joined).clamp(0, limit);
  bool get isNearLimit => usage >= 0.9;
  bool get isAtLimit => joined >= limit;
}

final roomBudgetProvider = StateProvider<RoomBudget>(
  (ref) => const RoomBudget(),
);
