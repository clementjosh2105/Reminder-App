import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/focus_group.dart';
import '../services/group_service.dart';

final groupServiceProvider = Provider<GroupService>((ref) => GroupService());

final myGroupsProvider = StreamProvider<List<FocusGroup>>((ref) {
  return ref.watch(groupServiceProvider).watchMyGroups();
});
