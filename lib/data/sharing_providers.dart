import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_providers.dart';
import 'sharing_service.dart';

final Provider<SharingService> sharingServiceProvider = Provider<SharingService>(
  (Ref ref) => SharingService(ref.watch(contentRepositoryProvider)),
);
