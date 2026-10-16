-- 本番反映用。マイグレーションではない。担当が、付与表を作ったあとで手動で流す。
-- 識別子はこのファイルに書かない。行の中身は public.kpi_excluded_users からその場で読む。
-- 本番の kpi_excluded_users は、20261007112725 の user_id / install_id / email / reason / added_at に、
-- 20261011070423 で足した provider と provider_id がある。この SQL はその形を読む。
--
-- 全体が1つのトランザクション。入るログインがちょうど3件でなければ、何も残さず中止する。
-- 同じ内容でもう一度流すと、3件のまま成功する。
--
-- 入れるもの:
--   reason が president_ で始まる行
--   provider と provider_id があるものは、そのログインの利用者が退会していないときだけ
--   provider が空で email だけのものは、退会していない利用者がちょうど1人のとき、その人のログイン
-- 入れないもの:
--   審査員（reason が president_ で始まらない）
--   user_id だけの行
--   deleted_at がある利用者（どの経路でも）
--   同じ email の退会していない利用者が2人以上いる行（1人も入れない）
--
-- 書くのは付与表だけ。加入表、通知、KPI、利用者ログは更新しない。

begin;

create temporary table complimentary_plus_candidates (
  provider text not null,
  provider_id text not null,
  primary key (provider, provider_id)
) on commit drop;

insert into complimentary_plus_candidates (provider, provider_id)
select distinct i.provider, i.provider_id
from public.kpi_excluded_users x
join auth.identities i
  on i.provider = x.provider
 and i.provider_id = x.provider_id
join public.users u
  on u.id = i.user_id
 and u.deleted_at is null
where x.reason like 'president\_%' escape '\'
  and x.provider is not null
  and x.provider_id is not null;

do $$
declare
  ambiguous integer;
  candidate_n integer;
  grant_n integer;
begin
  select count(*) into ambiguous
  from public.kpi_excluded_users x
  where x.reason like 'president\_%' escape '\'
    and x.provider is null
    and x.email is not null
    and (
      select count(*)
      from public.users u
      where lower(u.email) = lower(x.email)
        and u.deleted_at is null
    ) > 1;

  if ambiguous > 0 then
    raise exception 'a president email matches more than one live user';
  end if;

  insert into complimentary_plus_candidates (provider, provider_id)
  select distinct i.provider, i.provider_id
  from public.kpi_excluded_users x
  join public.users u
    on x.email is not null
   and lower(u.email) = lower(x.email)
   and u.deleted_at is null
  join auth.identities i on i.user_id = u.id
  where x.reason like 'president\_%' escape '\'
    and x.provider is null
    and (
      select count(*)
      from public.users live
      where lower(live.email) = lower(x.email)
        and live.deleted_at is null
    ) = 1
  on conflict (provider, provider_id) do nothing;

  select count(*) into candidate_n from complimentary_plus_candidates;
  if candidate_n <> 3 then
    raise exception 'complimentary grant count must be 3, got %', candidate_n;
  end if;

  insert into public.calonavi_plus_complimentary_grants (provider, provider_id)
  select provider, provider_id
  from complimentary_plus_candidates
  on conflict (provider, provider_id) do nothing;

  select count(*) into grant_n from public.calonavi_plus_complimentary_grants;
  if grant_n <> 3 then
    raise exception 'complimentary grant table must contain 3 rows, got %', grant_n;
  end if;

  if exists (
    select 1
    from public.calonavi_plus_complimentary_grants g
    where not exists (
      select 1
      from complimentary_plus_candidates c
      where c.provider = g.provider
        and c.provider_id = g.provider_id
    )
  ) then
    raise exception 'complimentary grant table has a row outside the 3 candidates';
  end if;
end
$$;

commit;
