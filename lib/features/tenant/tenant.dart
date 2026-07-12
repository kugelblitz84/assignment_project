class Tenant {
  const Tenant({required this.id, required this.name});

  final String id;
  final String name;

  static const demoTenants = [
    Tenant(
      id: '11111111-1111-1111-1111-111111111111',
      name: 'Acme Retail',
    ),
    Tenant(
      id: '22222222-2222-2222-2222-222222222222',
      name: 'Butterfly Health',
    ),
  ];
}
