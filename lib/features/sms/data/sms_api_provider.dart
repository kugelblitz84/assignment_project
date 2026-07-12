import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'fake_sms_api.dart';
import 'real_sms_api.dart';
import 'sms_api.dart';

final smsApiProvider = Provider<SmsApi>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.useFakeBackend) {
    final mode = ref.watch(fakeNetworkModeProvider);
    return FakeSmsApi(mode: mode);
  }

  return RealSmsApi(client: ref.watch(apiClientProvider));
});
