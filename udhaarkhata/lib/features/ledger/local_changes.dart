import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalRevision extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final cacheRevisionProvider = NotifierProvider<LocalRevision, int>(
  LocalRevision.new,
);
final syncWakeRevisionProvider = NotifierProvider<LocalRevision, int>(
  LocalRevision.new,
);
