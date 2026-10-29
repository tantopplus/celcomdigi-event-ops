-- ============================================================
-- CelcomDigi Event Ops – Supabase database setup
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Safe to run again: it only creates what is missing and replaces functions.
--
-- Security model: tables are locked (RLS on, no policies), so the public
-- app key cannot read them directly. The app can only call the app_*
-- functions below, and every function checks the caller's login token.
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- ---------- TABLES ----------
create table if not exists admins (
  id            uuid primary key default gen_random_uuid(),
  login_id      text not null,
  password_hash text not null,
  name          text not null,
  is_main       boolean not null default false,
  token         uuid,
  created_at    timestamptz not null default now()
);
create unique index if not exists admins_login_uq on admins (lower(login_id));

create table if not exists staff (
  id            uuid primary key default gen_random_uuid(),
  login_id      text not null,
  password_hash text not null,
  name          text not null,
  email         text not null default '',
  contact       text not null default '',
  token         uuid,
  created_at    timestamptz not null default now()
);
create unique index if not exists staff_login_uq on staff (lower(login_id));

create table if not exists settings (
  id   int primary key default 1 check (id = 1),
  data jsonb not null
);

create table if not exists submissions (
  id              uuid primary key default gen_random_uuid(),
  staff_id        uuid,                       -- kept even if the staff account is deleted
  staff_login_id  text not null default '',
  staff_name      text not null default '',
  event_date      date not null,
  event_venue     text not null default '',
  full_name       text not null default '',
  id_type         text not null default 'IC',
  id_number       text not null default '',
  current_number  text not null default '',
  new_number      text not null default '',
  game_id         text not null default '',
  server_id       text not null default '',
  plan            text not null default '',
  freebie         text not null default '',
  id_norm   text generated always as (upper(regexp_replace(id_number, '[^A-Za-z0-9]', '', 'g'))) stored,
  game_norm text generated always as (upper(regexp_replace(game_id,   '[^A-Za-z0-9]', '', 'g'))) stored,
  edited_by_staff boolean not null default false,
  edited_by_admin boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz
);
-- One IC/Passport, New Number and Game ID per event (deleted rows free the value again)
create unique index if not exists sub_id_uq   on submissions (event_venue, id_norm)    where id_norm <> '';
create unique index if not exists sub_new_uq  on submissions (event_venue, new_number) where new_number <> '';
create unique index if not exists sub_game_uq on submissions (event_venue, game_norm)  where game_norm <> '';
create index if not exists sub_staff_idx   on submissions (staff_id);
create index if not exists sub_created_idx on submissions (created_at desc);

alter table admins      enable row level security;
alter table staff       enable row level security;
alter table settings    enable row level security;
alter table submissions enable row level security;

-- ---------- STARTING DATA ----------
insert into settings (id, data) values (1, '{
  "mandatory": {"eventVenue":true,"fullName":true,"idNumber":true,"currentNumber":true,"newNumber":true,"gameId":true,"serverId":true,"plan":true,"freebie":true},
  "events":   ["Mid Valley Megamall Roadshow"],
  "plans":    ["Hyper30","Hyper35","Power35","Power45","Power+ 55","Power+ 65","CD Postpaid 60SE","PMJ 80","PMJ 100"],
  "freebies": ["Power Bank 10000mAh"]
}'::jsonb) on conflict (id) do nothing;

insert into admins (login_id, password_hash, name, is_main)
select 'tan', extensions.crypt('Tan@0302', extensions.gen_salt('bf')), 'Tan', true
where not exists (select 1 from admins);

-- ---------- HELPERS (internal, not callable by the app) ----------
create or replace function _ses(p_token uuid, out o_role text, out o_id uuid, out o_main boolean)
language plpgsql security definer set search_path = public as $$
begin
  if p_token is null then raise exception 'SESSION_INVALID'; end if;
  select 'admin', a.id, a.is_main into o_role, o_id, o_main from admins a where a.token = p_token;
  if found then return; end if;
  select 'sales', s.id, false into o_role, o_id, o_main from staff s where s.token = p_token;
  if found then return; end if;
  raise exception 'SESSION_INVALID';
end $$;

create or replace function _admin(p_token uuid, out o_id uuid, out o_main boolean)
language plpgsql security definer set search_path = public as $$
declare s record;
begin
  select * into s from _ses(p_token);
  if s.o_role <> 'admin' then raise exception 'FORBIDDEN'; end if;
  o_id := s.o_id; o_main := s.o_main;
end $$;

create or replace function _sub_json(s submissions) returns jsonb
language sql immutable as $$
  select jsonb_build_object(
    'id', s.id, 'staffId', s.staff_id, 'staffLoginId', s.staff_login_id, 'staffName', s.staff_name,
    'eventDate', to_char(s.event_date, 'YYYY-MM-DD'), 'eventVenue', s.event_venue, 'fullName', s.full_name,
    'idType', s.id_type, 'idNumber', s.id_number, 'currentNumber', s.current_number, 'newNumber', s.new_number,
    'gameId', s.game_id, 'serverId', s.server_id, 'plan', s.plan, 'freebie', s.freebie,
    'editedByStaff', s.edited_by_staff, 'editedByAdmin', s.edited_by_admin,
    'createdAt', s.created_at, 'updatedAt', s.updated_at)
$$;

create or replace function _norm(v text) returns text
language sql immutable as $$ select upper(regexp_replace(coalesce(v, ''), '[^A-Za-z0-9]', '', 'g')) $$;

-- Field-level checks: duplicates per event + number formats
create or replace function _check_sub(p_rec jsonb, p_exclude uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_venue text := coalesce(p_rec->>'eventVenue', '');
  e jsonb := '{}';
begin
  if coalesce(p_rec->>'eventDate', '') = '' then e := e || '{"eventDate":"required"}'; end if;
  if coalesce(p_rec->>'idType', 'IC') = 'IC' and coalesce(p_rec->>'idNumber', '') <> ''
     and length(regexp_replace(p_rec->>'idNumber', '\D', '', 'g')) <> 12 then e := e || '{"idNumber":"badIc"}'; end if;
  if coalesce(p_rec->>'currentNumber', '') <> '' and p_rec->>'currentNumber' !~ '^601[0-9]{8,9}$' then e := e || '{"currentNumber":"badPhone"}'; end if;
  if coalesce(p_rec->>'newNumber', '') <> '' and p_rec->>'newNumber' !~ '^601[0-9]{8,9}$' then e := e || '{"newNumber":"badPhone"}'; end if;

  if _norm(p_rec->>'idNumber') <> '' and exists (select 1 from submissions
       where event_venue = v_venue and id_norm = _norm(p_rec->>'idNumber') and id is distinct from p_exclude) then
    e := e || '{"idNumber":"dupId"}'; end if;
  if coalesce(p_rec->>'newNumber', '') <> '' and exists (select 1 from submissions
       where event_venue = v_venue and new_number = p_rec->>'newNumber' and id is distinct from p_exclude) then
    e := e || '{"newNumber":"dupNew"}'; end if;
  if _norm(p_rec->>'gameId') <> '' and exists (select 1 from submissions
       where event_venue = v_venue and game_norm = _norm(p_rec->>'gameId') and id is distinct from p_exclude) then
    e := e || '{"gameId":"dupGame"}'; end if;

  return case when e = '{}'::jsonb then null else e end;
end $$;

-- ---------- LOGIN / SESSION ----------
create or replace function app_login(p_role text, p_login_id text, p_password text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid; v_tok uuid := gen_random_uuid();
begin
  -- A new token replaces the old one, so any other phone using this account is logged out.
  if p_role = 'admin' then
    update admins set token = v_tok
     where lower(login_id) = lower(trim(p_login_id)) and password_hash = crypt(p_password, password_hash)
     returning id into v_id;
  else
    update staff set token = v_tok
     where lower(login_id) = lower(trim(p_login_id)) and password_hash = crypt(p_password, password_hash)
     returning id into v_id;
  end if;
  if v_id is null then perform pg_sleep(0.5); return null; end if;
  return jsonb_build_object('role', p_role, 'id', v_id, 'token', v_tok);
end $$;

create or replace function app_logout(p_token uuid) returns void
language sql security definer set search_path = public as $$
  update admins set token = null where token = p_token;
  update staff  set token = null where token = p_token;
$$;

create or replace function app_session_status(p_role text, p_id uuid, p_token uuid) returns text
language plpgsql security definer set search_path = public as $$
declare v_tok uuid;
begin
  if p_role = 'admin' then select token into v_tok from admins where id = p_id;
  else select token into v_tok from staff where id = p_id; end if;
  if not found then return 'removed'; end if;
  return case when v_tok is distinct from p_token then 'kicked' else 'ok' end;
end $$;

create or replace function app_me(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s record; r jsonb;
begin
  select * into s from _ses(p_token);
  if s.o_role = 'admin' then
    select jsonb_build_object('id', id, 'loginId', login_id, 'name', name, 'isMain', is_main) into r from admins where id = s.o_id;
  else
    select jsonb_build_object('id', id, 'loginId', login_id, 'name', name, 'email', email, 'contact', contact) into r from staff where id = s.o_id;
  end if;
  return r;
end $$;

create or replace function app_change_password(p_token uuid, p_current text, p_new text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s record;
begin
  select * into s from _ses(p_token);
  if length(coalesce(p_new, '')) < 8 then return '{"error":"pwMin8"}'; end if;
  if s.o_role = 'admin' then
    update admins set password_hash = crypt(p_new, gen_salt('bf'))
     where id = s.o_id and password_hash = crypt(p_current, password_hash);
  else
    update staff set password_hash = crypt(p_new, gen_salt('bf'))
     where id = s.o_id and password_hash = crypt(p_current, password_hash);
  end if;
  if not found then return '{"error":"wrongPw"}'; end if;
  return '{"ok":true}';
end $$;

-- ---------- SETTINGS ----------
create or replace function app_get_settings(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _ses(p_token);
  return (select data from settings where id = 1);
end $$;

create or replace function app_save_settings(p_token uuid, p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _admin(p_token);
  update settings set data = p_data where id = 1;
end $$;

-- ---------- SUBMISSIONS ----------
create or replace function app_list_submissions(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s record;
begin
  select * into s from _ses(p_token);
  return coalesce((
    select jsonb_agg(_sub_json(x) order by x.created_at desc) from submissions x
     where s.o_role = 'admin' or x.staff_id = s.o_id), '[]'::jsonb);
end $$;

create or replace function app_add_submission(p_token uuid, p_rec jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s record; st record; e jsonb; r submissions;
begin
  select * into s from _ses(p_token);
  if s.o_role <> 'sales' then raise exception 'FORBIDDEN'; end if;
  e := _check_sub(p_rec, null);
  if e is not null then return jsonb_build_object('errors', e); end if;
  select login_id, name into st from staff where id = s.o_id;
  insert into submissions (staff_id, staff_login_id, staff_name, event_date, event_venue, full_name, id_type, id_number,
                           current_number, new_number, game_id, server_id, plan, freebie)
  values (s.o_id, st.login_id, st.name, (p_rec->>'eventDate')::date, coalesce(p_rec->>'eventVenue', ''),
          upper(coalesce(p_rec->>'fullName', '')), coalesce(nullif(p_rec->>'idType', ''), 'IC'), coalesce(p_rec->>'idNumber', ''),
          coalesce(p_rec->>'currentNumber', ''), coalesce(p_rec->>'newNumber', ''), coalesce(p_rec->>'gameId', ''),
          coalesce(p_rec->>'serverId', ''), coalesce(p_rec->>'plan', ''), coalesce(p_rec->>'freebie', ''))
  returning * into r;
  return jsonb_build_object('row', _sub_json(r));
exception when unique_violation then
  -- two phones submitted the same customer at the same moment
  return jsonb_build_object('errors', coalesce(_check_sub(p_rec, null), '{"idNumber":"dupId"}'::jsonb));
end $$;

create or replace function app_update_submission(p_token uuid, p_id uuid, p_rec jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare s record; cur submissions; e jsonb; r submissions;
begin
  select * into s from _ses(p_token);
  select * into cur from submissions where id = p_id for update;
  if not found then return '{"error":"deleted"}'; end if;
  if s.o_role = 'sales' and (cur.staff_id <> s.o_id or cur.edited_by_staff) then return '{"error":"locked"}'; end if;
  e := _check_sub(p_rec, p_id);
  if e is not null then return jsonb_build_object('errors', e); end if;
  update submissions set
    event_date = (p_rec->>'eventDate')::date, event_venue = coalesce(p_rec->>'eventVenue', ''),
    full_name = upper(coalesce(p_rec->>'fullName', '')), id_type = coalesce(nullif(p_rec->>'idType', ''), 'IC'),
    id_number = coalesce(p_rec->>'idNumber', ''), current_number = coalesce(p_rec->>'currentNumber', ''),
    new_number = coalesce(p_rec->>'newNumber', ''), game_id = coalesce(p_rec->>'gameId', ''),
    server_id = coalesce(p_rec->>'serverId', ''), plan = coalesce(p_rec->>'plan', ''), freebie = coalesce(p_rec->>'freebie', ''),
    updated_at = now(),
    edited_by_staff = edited_by_staff or s.o_role = 'sales',
    edited_by_admin = edited_by_admin or s.o_role = 'admin'
  where id = p_id returning * into r;
  return jsonb_build_object('row', _sub_json(r));
exception when unique_violation then
  return jsonb_build_object('errors', coalesce(_check_sub(p_rec, p_id), '{"idNumber":"dupId"}'::jsonb));
end $$;

create or replace function app_delete_submission(p_token uuid, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s record;
begin
  select * into s from _ses(p_token);
  delete from submissions where id = p_id and (s.o_role = 'admin' or staff_id = s.o_id);
end $$;

-- ---------- STAFF (admin only) ----------
create or replace function app_list_staff(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _admin(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'loginId', login_id, 'name', name, 'email', email,
           'contact', contact, 'online', token is not null, 'createdAt', created_at) order by created_at) from staff), '[]'::jsonb);
end $$;

create or replace function app_add_staff(p_token uuid, p_login_id text, p_password text, p_name text, p_email text, p_contact text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _admin(p_token);
  if coalesce(trim(p_login_id), '') = '' or trim(p_login_id) ~ '\s' or coalesce(trim(p_name), '') = '' then return '{"error":"required"}'; end if;
  if length(coalesce(p_password, '')) < 6 then return '{"error":"pwMin6"}'; end if;
  if exists (select 1 from staff where lower(login_id) = lower(trim(p_login_id)))
     or exists (select 1 from admins where lower(login_id) = lower(trim(p_login_id))) then return '{"error":"idTaken"}'; end if;
  insert into staff (login_id, password_hash, name, email, contact)
  values (trim(p_login_id), crypt(p_password, gen_salt('bf')), trim(p_name), coalesce(p_email, ''), coalesce(p_contact, ''));
  return '{"ok":true}';
end $$;

create or replace function app_reset_staff_password(p_token uuid, p_id uuid, p_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _admin(p_token);
  if length(coalesce(p_password, '')) < 6 then raise exception 'PASSWORD_TOO_SHORT'; end if;
  update staff set password_hash = crypt(p_password, gen_salt('bf')), token = null where id = p_id;
end $$;

create or replace function app_delete_staff(p_token uuid, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _admin(p_token);
  delete from staff where id = p_id;
end $$;

-- ---------- ADMINS (list: any admin; change: main admin only, max 5) ----------
create or replace function app_list_admins(p_token uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform _admin(p_token);
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'loginId', login_id, 'name', name, 'isMain', is_main,
           'online', token is not null, 'createdAt', created_at) order by created_at) from admins), '[]'::jsonb);
end $$;

create or replace function app_add_admin(p_token uuid, p_login_id text, p_password text, p_name text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare a record;
begin
  select * into a from _admin(p_token);
  if not a.o_main then return '{"error":"onlyMain"}'; end if;
  if (select count(*) from admins) >= 5 then return '{"error":"maxAdmins"}'; end if;
  if coalesce(trim(p_login_id), '') = '' or trim(p_login_id) ~ '\s' or coalesce(trim(p_name), '') = '' then return '{"error":"required"}'; end if;
  if length(coalesce(p_password, '')) < 8 then return '{"error":"pwMin8"}'; end if;
  if exists (select 1 from staff where lower(login_id) = lower(trim(p_login_id)))
     or exists (select 1 from admins where lower(login_id) = lower(trim(p_login_id))) then return '{"error":"idTaken"}'; end if;
  insert into admins (login_id, password_hash, name) values (trim(p_login_id), crypt(p_password, gen_salt('bf')), trim(p_name));
  return '{"ok":true}';
end $$;

create or replace function app_reset_admin_password(p_token uuid, p_id uuid, p_password text) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare a record;
begin
  select * into a from _admin(p_token);
  if not a.o_main then raise exception 'FORBIDDEN'; end if;
  if length(coalesce(p_password, '')) < 8 then raise exception 'PASSWORD_TOO_SHORT'; end if;
  update admins set password_hash = crypt(p_password, gen_salt('bf')), token = null where id = p_id;
end $$;

create or replace function app_delete_admin(p_token uuid, p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare a record;
begin
  select * into a from _admin(p_token);
  if not a.o_main then raise exception 'FORBIDDEN'; end if;
  delete from admins where id = p_id and not is_main;
end $$;

-- ---------- PERMISSIONS ----------
revoke execute on function _ses(uuid), _admin(uuid), _sub_json(submissions), _norm(text), _check_sub(jsonb, uuid)
  from public, anon, authenticated;
grant execute on function
  app_login(text, text, text), app_logout(uuid), app_session_status(text, uuid, uuid), app_me(uuid),
  app_change_password(uuid, text, text), app_get_settings(uuid), app_save_settings(uuid, jsonb),
  app_list_submissions(uuid), app_add_submission(uuid, jsonb), app_update_submission(uuid, uuid, jsonb),
  app_delete_submission(uuid, uuid), app_list_staff(uuid), app_add_staff(uuid, text, text, text, text, text),
  app_reset_staff_password(uuid, uuid, text), app_delete_staff(uuid, uuid), app_list_admins(uuid),
  app_add_admin(uuid, text, text, text), app_reset_admin_password(uuid, uuid, text), app_delete_admin(uuid, uuid)
  to anon;
