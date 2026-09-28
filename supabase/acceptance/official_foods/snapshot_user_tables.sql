-- Read-only snapshot of existing public user objects.
-- Run this BEFORE the official-foods migration and data import.
-- Paste the single returned jsonb into accept_official_foods.sql (v_baseline).
--
-- Safe on any environment: the transaction is READ ONLY. It does not insert,
-- update, delete, or create objects. It does not read row contents, only
-- counts and catalog signatures.
--
-- This snapshot deliberately includes every public table, view, routine, and
-- owned sequence. It does not try to guess which objects the feature migration
-- will add. accept_official_foods.sql ignores only brand-new objects whose
-- names are listed in its CONFIG block. Objects that already exist here are
-- always compared, so adding saved_foods to that list cannot hide a change.
--
-- No name edit is required in this file. PR #31 names are aligned in
-- accept_official_foods.sql. Take this snapshot before applying
-- 20260928120000_official_foods.sql and
-- 20260928140000_official_food_provenance.sql. A baseline that already
-- contains official_foods is rejected.

begin read only;
set local statement_timeout = '120s';

-- BEGIN SHARED FINGERPRINT
select jsonb_build_object(
  'kind', 'official_foods_user_table_snapshot',
  'taken_at', timezone('utc', now()),
  'database', current_database(),
  'tables', coalesce((
    select jsonb_object_agg(s.relname, jsonb_build_object('n', s.n, 'sig', s.sig) order by s.relname)
    from (
      select
        t.relname,
        (
          select (xpath('//c/text()', query_to_xml(
            format('select count(*)::bigint as c from public.%I', t.relname),
            false, true, ''
          )))[1]::text::bigint
        ) as n,
        md5(concat_ws(e'\n',
          coalesce(t.relacl::text, ''),
          coalesce(obj_description(t.oid, 'pg_class'), ''),
          coalesce((
            select string_agg(
              concat_ws(':',
                a.attnum::text,
                a.attname,
                a.atttypid::text,
                a.atttypmod::text,
                a.attnotnull::text,
                a.attidentity,
                a.attgenerated,
                coalesce(pg_get_expr(ad.adbin, ad.adrelid), '')
              ),
              '|' order by a.attnum
            )
            from pg_attribute a
            left join pg_attrdef ad
              on ad.adrelid = a.attrelid
             and ad.adnum = a.attnum
            where a.attrelid = t.oid
              and a.attnum > 0
              and not a.attisdropped
          ), ''),
          coalesce((
            select string_agg(
              concat_ws(':', con.contype, con.conname, pg_get_constraintdef(con.oid)),
              '|' order by con.conname
            )
            from pg_constraint con
            where con.conrelid = t.oid
          ), ''),
          coalesce((
            select string_agg(pg_get_indexdef(i.indexrelid), '|' order by ic.relname)
            from pg_index i
            join pg_class ic on ic.oid = i.indexrelid
            where i.indrelid = t.oid
          ), ''),
          coalesce((
            select string_agg(pg_get_triggerdef(tg.oid), '|' order by tg.tgname)
            from pg_trigger tg
            where tg.tgrelid = t.oid
              and not tg.tgisinternal
          ), ''),
          coalesce((
            select string_agg(
              concat_ws(':',
                pol.polname,
                pol.polcmd,
                pol.polpermissive::text,
                pol.polroles::text,
                coalesce(pg_get_expr(pol.polqual, pol.polrelid), ''),
                coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid), '')
              ),
              '|' order by pol.polname
            )
            from pg_policy pol
            where pol.polrelid = t.oid
          ), '')
        )) as sig
      from pg_class t
      join pg_namespace n on n.oid = t.relnamespace
      where n.nspname = 'public'
        and t.relkind in ('r', 'p')
    ) s
  ), '{}'::jsonb),
  'views', coalesce((
    select jsonb_object_agg(
      c.relname,
      jsonb_build_object(
        'sig', md5(concat_ws(e'\n',
          c.relkind::text,
          coalesce(c.relacl::text, ''),
          coalesce(pg_get_viewdef(c.oid, false), '')
        ))
      )
      order by c.relname
    )
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('v', 'm')
  ), '{}'::jsonb),
  'routines', coalesce((
    select jsonb_object_agg(
      p.prokind::text || ':' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')',
      jsonb_build_object(
        'name', p.proname,
        'sig', md5(concat_ws('|',
          p.prokind::text,
          p.prosecdef::text,
          p.provolatile,
          p.proowner::text,
          p.proargtypes::text,
          p.prorettype::text,
          coalesce(p.proconfig::text, ''),
          coalesce(p.probin, ''),
          p.prosrc
        ))
      )
      order by p.proname, pg_get_function_identity_arguments(p.oid)
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  ), '{}'::jsonb),
  'sequences', coalesce((
    select jsonb_object_agg(
      seq.relname,
      jsonb_build_object(
        'last', pg_sequence_last_value(seq.oid),
        'owner', t.relname
      )
      order by seq.relname
    )
    from pg_class seq
    join pg_namespace sn on sn.oid = seq.relnamespace
    join pg_depend d
      on d.objid = seq.oid
     and d.deptype in ('a', 'i')
    join pg_class t on t.oid = d.refobjid
    join pg_namespace tn on tn.oid = t.relnamespace
    where seq.relkind = 'S'
      and sn.nspname = 'public'
      and tn.nspname = 'public'
  ), '{}'::jsonb)
) as snapshot;
-- END SHARED FINGERPRINT

commit;
