import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/chat/data/supabase_chat_repository.dart';
import '../../features/chat/domain/chat_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(ref.watch(supabaseClientProvider)),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => SupabaseChatRepository(ref.watch(supabaseClientProvider)),
);
