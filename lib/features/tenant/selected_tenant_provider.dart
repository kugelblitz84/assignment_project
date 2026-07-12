import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tenant.dart';

class SelectedTenantIdNotifier extends Notifier<String> {
  @override
  String build() => Tenant.demoTenants.first.id;
}

final selectedTenantIdProvider =
    NotifierProvider<SelectedTenantIdNotifier, String>(
      SelectedTenantIdNotifier.new,
    );
