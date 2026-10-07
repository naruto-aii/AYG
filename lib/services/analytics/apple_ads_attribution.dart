import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

const appleAdsAttributionUrl = 'https://api-adservices.apple.com/api/v1/';
const _doneKey = 'analytics_ads_attribution_done';
const _tokenAtKey = 'analytics_ads_token_at_ms';

/// インストールごとに 1 回。同意した人だけ。token は 24 時間で切れる。
class AppleAdsAttribution {
  AppleAdsAttribution({
    required AnalyticsService service,
    required SharedPreferences preferences,
    http.Client? client,
    DateTime Function()? clock,
    Duration retryDelay = const Duration(seconds: 5),
  }) : _service = service,
       _preferences = preferences,
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now,
       _retryDelay = retryDelay;

  final AnalyticsService _service;
  final SharedPreferences _preferences;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration _retryDelay;

  Future<void> captureOnce() async {
    if (!_service.consented) {
      return;
    }
    if (_preferences.getBool(_doneKey) ?? false) {
      return;
    }
    final token = await _service.bridge.adServicesToken();
    if (token == null || token.isEmpty) {
      final asked = _preferences.getInt(_tokenAtKey);
      if (asked != null &&
          _clock().difference(
                DateTime.fromMillisecondsSinceEpoch(asked, isUtc: true),
              ) <
              const Duration(hours: 24)) {
        return;
      }
      await _preferences.setInt(_tokenAtKey, _clock().toUtc().millisecondsSinceEpoch);
      return;
    }
    final payload = await _post(token);
    if (payload == null) {
      return;
    }
    await _service.track('apple_ads_attribution', {
      'attribution': payload['attribution'] == true,
      'campaign_id': payload['campaignId'],
      'ad_group_id': payload['adGroupId'],
      'keyword_id': payload['keywordId'],
      'ad_id': payload['adId'],
      'claim_type': payload['claimType'],
      'conversion_type': payload['conversionType'],
      'click_date': payload['clickDate'],
      'country_or_region': payload['countryOrRegion'],
      'supply_placement': payload['supplyPlacement'],
      'org_id': payload['orgId'],
    });
    await _preferences.setBool(_doneKey, true);
  }

  Future<Map<String, Object?>?> _post(String token) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await _client.post(
          Uri.parse(appleAdsAttributionUrl),
          headers: {'Content-Type': 'text/plain'},
          body: token,
        );
        if (response.statusCode == 404) {
          await Future<void>.delayed(_retryDelay);
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return null;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, Object?>.from(decoded);
        }
        return const {};
      } catch (error, stackTrace) {
        debugPrint('[AYG] apple ads attribution failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return null;
      }
    }
    return null;
  }
}
