-- 20261010143000 を戻す。禁止語の関数は残し、トリガー名だけ先の形に戻す。
-- 先にこれを流し、そのあと 20261010045607 のロールバックを流す。

drop trigger if exists saved_foods_reject_banned_public_text on public.saved_foods;

create trigger reject_banned_public_food_text
  before insert or update of
    name,
    normalized_name,
    brand,
    serving_unit_label,
    supplementary_weight,
    barcode,
    voice_reading,
    voice_katakana,
    voice_normalized,
    visibility,
    status,
    deleted_at,
    moderation_status
  on public.saved_foods
  for each row
  when (new.visibility in ('public', 'unlisted'))
  execute function moderation.reject_banned_public_food_text();
