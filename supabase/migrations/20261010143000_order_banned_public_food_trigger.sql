-- 読みの生成より後に禁止語を見る。BEFORE トリガーは名前順なので、
-- saved_foods_fill_voice の次になる名前にする。
-- 公式の食品名と出典も、公開面の自由文として見る。
-- 既存の公開行は書き換えない。

create or replace function moderation.reject_banned_public_food_text()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now_shared boolean;
  v_was_shared boolean;
begin
  v_now_shared :=
    new.visibility in ('public', 'unlisted')
    and new.status = 'active'
    and new.deleted_at is null
    and new.moderation_status in ('none', 'reported', 'under_review');

  if not v_now_shared then
    return new;
  end if;

  if tg_op = 'INSERT' then
    v_was_shared := false;
  else
    v_was_shared :=
      old.visibility in ('public', 'unlisted')
      and old.status = 'active'
      and old.deleted_at is null
      and old.moderation_status in ('none', 'reported', 'under_review');
  end if;

  if not v_was_shared then
    if moderation.text_is_banned(new.name)
       or moderation.text_is_banned(new.normalized_name)
       or moderation.text_is_banned(coalesce(new.brand, ''))
       or moderation.text_is_banned(coalesce(new.serving_unit_label, ''))
       or moderation.text_is_banned(coalesce(new.supplementary_weight, ''))
       or moderation.text_is_banned(coalesce(new.barcode, ''))
       or moderation.text_is_banned(coalesce(new.official_food_name, ''))
       or moderation.text_is_banned(coalesce(new.source_attribution, ''))
       or moderation.text_is_banned(coalesce(new.voice_reading, ''))
       or moderation.text_is_banned(coalesce(new.voice_katakana, ''))
       or moderation.text_is_banned(coalesce(new.voice_normalized, '')) then
      raise exception 'moderation banned public food text'
        using errcode = '23514';
    end if;
    return new;
  end if;

  if (new.name is distinct from old.name and moderation.text_is_banned(new.name))
     or (new.normalized_name is distinct from old.normalized_name
         and moderation.text_is_banned(new.normalized_name))
     or (new.brand is distinct from old.brand
         and moderation.text_is_banned(coalesce(new.brand, '')))
     or (new.serving_unit_label is distinct from old.serving_unit_label
         and moderation.text_is_banned(coalesce(new.serving_unit_label, '')))
     or (new.supplementary_weight is distinct from old.supplementary_weight
         and moderation.text_is_banned(coalesce(new.supplementary_weight, '')))
     or (new.barcode is distinct from old.barcode
         and moderation.text_is_banned(coalesce(new.barcode, '')))
     or (new.official_food_name is distinct from old.official_food_name
         and moderation.text_is_banned(coalesce(new.official_food_name, '')))
     or (new.source_attribution is distinct from old.source_attribution
         and moderation.text_is_banned(coalesce(new.source_attribution, '')))
     or (new.voice_reading is distinct from old.voice_reading
         and moderation.text_is_banned(coalesce(new.voice_reading, '')))
     or (new.voice_katakana is distinct from old.voice_katakana
         and moderation.text_is_banned(coalesce(new.voice_katakana, '')))
     or (new.voice_normalized is distinct from old.voice_normalized
         and moderation.text_is_banned(coalesce(new.voice_normalized, ''))) then
    raise exception 'moderation banned public food text'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

revoke all on function moderation.reject_banned_public_food_text() from public, anon, authenticated;
grant execute on function moderation.reject_banned_public_food_text()
  to anon, authenticated, service_role;

drop trigger if exists reject_banned_public_food_text on public.saved_foods;
drop trigger if exists saved_foods_reject_banned_public_text on public.saved_foods;
create trigger saved_foods_reject_banned_public_text
  before insert or update of
    name,
    normalized_name,
    brand,
    serving_unit_label,
    supplementary_weight,
    barcode,
    official_food_name,
    source_attribution,
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
