import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import 'selected_tenant_provider.dart';
import 'tenant.dart';

class TenantSelector extends ConsumerWidget {
  const TenantSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTenantId = ref.watch(selectedTenantIdProvider);

    return Semantics(
      label: 'Tenant selector',
      child: DropdownButtonFormField<String>(
        value: selectedTenantId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tenant',
          helperText: 'Every request is scoped to this tenant.',
        ),
        items: Tenant.demoTenants
            .map(
              (tenant) => DropdownMenuItem<String>(
                value: tenant.id,
                child: Text(tenant.name),
              ),
            )
            .toList(),
        onChanged: (tenantId) {
          if (tenantId == null) return;
          ref.read(selectedTenantIdProvider.notifier).state = tenantId;
        },
      ),
    );
  }
}
