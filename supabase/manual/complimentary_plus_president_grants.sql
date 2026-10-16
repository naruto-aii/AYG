-- 本番反映用。マイグレーションではない。担当が、表を作ったあとで手動で流す。
-- 識別子はこのファイルに書かない。行の中身は public.kpi_excluded_users からその場で読む。
--
-- 入れるもの:
--   reason が president_ で始まる行
--   すでに provider と provider_id があるもの
--   provider が空で email だけのものは、退会していない利用者の auth.identities
-- 入れないもの:
--   審査員（reason が president_ で始まらない）
--   user_id だけで残っている行（退会済みを含む）
--   deleted_at がある利用者
--
-- 書くのは付与表だけ。加入表、通知、KPI、利用者ログは更新しない。
-- 2回流しても、同じ識別子は1行のまま。

insert into public.calonavi_plus_complimentary_grants (provider, provider_id)
select x.provider, x.provider_id
from public.kpi_excluded_users x
where x.reason like 'president\_%' escape '\'
  and x.provider is not null
  and x.provider_id is not null
on conflict (provider, provider_id) do nothing;

insert into public.calonavi_plus_complimentary_grants (provider, provider_id)
select i.provider, i.provider_id
from public.kpi_excluded_users x
join public.users u
  on x.email is not null
 and lower(u.email) = lower(x.email)
 and u.deleted_at is null
join auth.identities i on i.user_id = u.id
where x.reason like 'president\_%' escape '\'
  and x.provider is null
on conflict (provider, provider_id) do nothing;
