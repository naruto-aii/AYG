import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/subscription_event_reporter.dart';

class SupabaseSubscriptionEventReporter
    extends InsertingSubscriptionEventReporter {
  SupabaseSubscriptionEventReporter({SupabaseClient? client})
    : super(
        insert: (row) async {
          final supabase = client ?? Supabase.instance.client;
          await supabase.from('subscription_events').insert(row);
        },
      );
}
