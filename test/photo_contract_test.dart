// サーバ（analyze-meal-photo）が返す JSON を、アプリがそのまま読めることを確かめる。
// test/fixtures/analyze_meal_photo_ok.json は、supabase/functions/
// photo_contract_fixture_test.ts が本物のハンドラから作ったもの。
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Map<String, Object?> fixture() => Map<String, Object?>.from(
    jsonDecode(File('test/fixtures/analyze_meal_photo_ok.json').readAsStringSync())
        as Map,
  );

  test('サーバの成功応答（13品→12品にまとめた弁当）をそのまま読める', () async {
    final sent = <Map<String, Object?>>[];
    final client = PhotoMealClient(
      invoke: (body) async {
        sent.add(body);
        return fixture();
      },
    );
    // 縦長の写真を、アプリが送る形にする（長辺 1024、縦横比そのまま）。
    final portrait = img.Image(width: 1200, height: 2000);
    final jpeg = compressMealPhoto(
      Uint8List.fromList(img.encodeJpg(portrait)),
    );
    final decoded = img.decodeJpg(jpeg)!;
    expect([decoded.width, decoded.height], [614, 1024]);

    final result = await client.analyze(jpeg: jpeg, dishName: '', amount: '');
    expect(sent.single.keys.toSet(), {'image_base64', 'dish_name', 'amount', 'note'});
    expect(base64Decode(sent.single['image_base64']! as String), jpeg);
    expect(result.usageId, 'usage-1');
    expect(result.collectionId, 'collection-1');
    final estimate = result.estimate;
    expect(estimate.dishName, '幕の内弁当');
    expect(estimate.kcal, 820);
    expect(estimate.proteinG, 32);
    expect(estimate.items, hasLength(12));
    expect(estimate.items.last.name, 'その他（2品）');
    final sum = estimate.items.fold<double>(0, (total, item) => total + item.kcal);
    expect(sum, closeTo(estimate.kcal, 0.11));
  });

  test('サーバの失敗応答は、その文面をそのまま出す（推定できませんでした等）', () async {
    for (final body in [
      {'ok': false, 'code': 'not_plus', 'message': 'こちらはカロナビ+の機能です。手入力で記録できます。'},
      {'ok': false, 'code': 'provider_error', 'message': '推定できませんでした。しばらくしてからもう一度試すか、手入力で記録できます。'},
      {'ok': false, 'code': 'daily_cap', 'message': '本日の上限に達しました'},
    ]) {
      final client = PhotoMealClient(invoke: (_) async => body);
      await expectLater(
        client.analyze(jpeg: Uint8List.fromList([1]), dishName: '', amount: ''),
        throwsA(
          isA<PhotoMealFailure>().having(
            (failure) => failure.message,
            'message',
            body['message'],
          ),
        ),
      );
    }
  });
}
