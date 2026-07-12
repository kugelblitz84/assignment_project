import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.accessToken,
    required this.useFakeBackend,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      apiBaseUrl: String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.example.invalid',
      ),
      accessToken: String.fromEnvironment(
        'ACCESS_TOKEN',
        defaultValue: 'demo-access-token',
      ),
      useFakeBackend: bool.fromEnvironment(
        'USE_FAKE_BACKEND',
        defaultValue: true,
      ),
    );
  }

  final String apiBaseUrl;
  final String accessToken;
  final bool useFakeBackend;
}
