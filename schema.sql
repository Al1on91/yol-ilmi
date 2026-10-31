-- =====================================================================
-- YO‘L ILMI — anonim ilmiy so‘rov platformasi: ma'lumotlar bazasi sxemasi
-- Supabase → SQL Editor → New query → shu faylni to'liq joylab → RUN.
-- Qayta ishga tushirish xavfsiz (mavjud jadvallar o'chirilmaydi).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- Jadvallar ----------

-- Respondent javoblari. Shaxsiy identifikator, IP, vaqt (soat) saqlanmaydi:
-- sana faqat kun aniqligida, server tomonida qo'yiladi.
create table if not exists public.responses (
  id               uuid primary key default gen_random_uuid(),
  audience         text not null check (audience in ('citizen','expert')),
  version          text not null default '1.0' check (char_length(version) <= 20),
  date_bucket      date not null default ((now() at time zone 'Asia/Tashkent')::date),
  region           smallint check (region between 0 and 13),
  answers          jsonb not null check (jsonb_typeof(answers) = 'object' and pg_column_size(answers) < 12000),
  text_pii_masked  boolean not null default false,
  review           jsonb not null default '{"status":"none","themes":[]}'::jsonb
);

-- So'rov boshlanishlari (yakunlash ulushini hisoblash uchun). Hech qanday identifikator yo'q.
create table if not exists public.survey_starts (
  id          bigint generated always as identity primary key,
  audience    text not null check (audience in ('citizen','expert')),
  date_bucket date not null default ((now() at time zone 'Asia/Tashkent')::date)
);

-- So'rov sozlamalari (bitta qator): ochiq/yopiq, muddat, versiya, savol o'zgarishlari.
create table if not exists public.survey_config (
  id          int primary key default 1 check (id = 1),
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- Ommaviy e'lon qilingan agregat natijalar (bitta qator). n<10 guruhlar sayt tomonidan yashiriladi.
create table if not exists public.public_summary (
  id            int primary key default 1 check (id = 1),
  data          jsonb not null,
  published_at  timestamptz not null default now()
);

-- Tadqiqot portfeli.
create table if not exists public.research_topics (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 200),
  evidence    text not null default '' check (char_length(evidence) <= 1200),
  owner_role  text not null default '',
  status      text not null default 'proposal' check (status in ('proposal','review','approved','rejected')),
  themes      jsonb not null default '[]'::jsonb,
  public      boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Administratorlar ro'yxati (Supabase Auth foydalanuvchilariga bog'langan).
create table if not exists public.admin_users (
  user_id  uuid primary key references auth.users(id) on delete cascade,
  role     text not null default 'analyst' check (role in ('superadmin','lead','analyst','regional','reader')),
  active   boolean not null default true
);

-- Audit jurnali: faqat admin amallari. O'zgartirib/o'chirib bo'lmaydi.
create table if not exists public.admin_audit (
  id           bigint generated always as identity primary key,
  ts           timestamptz not null default now(),
  admin_id     uuid default auth.uid(),
  admin_email  text default (auth.jwt()->>'email'),
  event        text not null check (char_length(event) <= 40),
  ref          text not null default '' check (char_length(ref) <= 300)
);


-- Taklif havolalari: so'rovda faqat shu havolalar orqali qatnashish mumkin.
-- Havola kanalga (masalan "Samarqand, Telegram") tegishli, shaxsga emas.
create table if not exists public.access_links (
  token       text primary key check (char_length(token) between 12 and 64),
  label       text not null default '' check (char_length(label) <= 120),
  audience    text check (audience in ('citizen','expert')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);
alter table public.responses     add column if not exists link_token text references public.access_links(token) on delete set null;
alter table public.survey_starts add column if not exists link_token text references public.access_links(token) on delete set null;

-- ---------- Yordamchi funksiyalar ----------
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid() and active);
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- Havola faolmi va shu auditoriyaga ruxsat beradimi (respondent jadvalni o'qiy olmaydi, faqat shu funksiya orqali tekshiradi).
create or replace function public.link_ok(t text, aud text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.access_links l where l.token = t and l.active and (l.audience is null or l.audience = aud));
$$;
create or replace function public.check_link(t text) returns table(audience text)
language sql stable security definer set search_path = public as $$
  select l.audience from public.access_links l where l.token = t and l.active;
$$;
revoke all on function public.link_ok(text, text) from public;
revoke all on function public.check_link(text) from public;
grant execute on function public.link_ok(text, text) to anon, authenticated;
grant execute on function public.check_link(text) to anon, authenticated;

-- ---------- Xavfsizlik qoidalari (Row Level Security) ----------
alter table public.responses       enable row level security;
alter table public.survey_starts   enable row level security;
alter table public.survey_config   enable row level security;
alter table public.public_summary  enable row level security;
alter table public.research_topics enable row level security;
alter table public.admin_users     enable row level security;
alter table public.admin_audit     enable row level security;
alter table public.access_links    enable row level security;

-- Ruxsatlar (jadval darajasida). Avval Supabase'ning keng standart huquqlari olib tashlanadi.
revoke all on public.responses, public.survey_starts, public.survey_config, public.public_summary,
  public.research_topics, public.admin_users, public.admin_audit, public.access_links from anon, authenticated;
grant usage on schema public to anon, authenticated;
grant insert (audience, version, region, answers, text_pii_masked, review, link_token) on public.responses to anon, authenticated;
grant select, update, delete on public.responses to authenticated;
grant insert (audience, link_token) on public.survey_starts to anon, authenticated;
grant select, delete on public.survey_starts to authenticated;
grant select on public.survey_config, public.public_summary to anon, authenticated;
grant insert, update, delete on public.survey_config, public.public_summary to authenticated;
grant select, insert, update, delete on public.research_topics to authenticated;
grant select on public.admin_users to authenticated;
grant select on public.admin_audit to authenticated;
grant insert (event, ref) on public.admin_audit to authenticated;
grant select, insert, update, delete on public.access_links to authenticated;

-- responses: faol taklif havolasi bo'lgan har kim (akkauntsiz ham) faqat YANGI javob qo'sha oladi; o'qish/tahrirlash — faqat admin.
drop policy if exists responses_insert on public.responses;
create policy responses_insert on public.responses for insert to anon, authenticated
  with check (public.link_ok(link_token, audience) and review->>'status' in ('new','none') and jsonb_array_length(coalesce(review->'themes','[]'::jsonb)) = 0);
drop policy if exists responses_admin_select on public.responses;
create policy responses_admin_select on public.responses for select to authenticated using (public.is_admin());
drop policy if exists responses_admin_update on public.responses;
create policy responses_admin_update on public.responses for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists responses_admin_delete on public.responses;
create policy responses_admin_delete on public.responses for delete to authenticated using (public.is_admin());

-- survey_starts: hamma qo'sha oladi, faqat admin ko'radi.
drop policy if exists starts_insert on public.survey_starts;
create policy starts_insert on public.survey_starts for insert to anon, authenticated with check (public.link_ok(link_token, audience));
drop policy if exists starts_admin on public.survey_starts;
create policy starts_admin on public.survey_starts for select to authenticated using (public.is_admin());
drop policy if exists starts_admin_delete on public.survey_starts;
create policy starts_admin_delete on public.survey_starts for delete to authenticated using (public.is_admin());

-- survey_config va public_summary: hamma o'qiydi, faqat admin yozadi.
drop policy if exists config_read on public.survey_config;
create policy config_read on public.survey_config for select to anon, authenticated using (true);
drop policy if exists config_write on public.survey_config;
create policy config_write on public.survey_config for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists summary_read on public.public_summary;
create policy summary_read on public.public_summary for select to anon, authenticated using (true);
drop policy if exists summary_write on public.public_summary;
create policy summary_write on public.public_summary for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- access_links: faqat admin boshqaradi.
drop policy if exists links_admin on public.access_links;
create policy links_admin on public.access_links for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- research_topics: faqat admin.
drop policy if exists topics_admin on public.research_topics;
create policy topics_admin on public.research_topics for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- admin_users: foydalanuvchi faqat o'z qatorini ko'radi (rolini bilish uchun).
drop policy if exists admin_self on public.admin_users;
create policy admin_self on public.admin_users for select to authenticated using (user_id = auth.uid());

-- admin_audit: admin qo'shadi va o'qiydi; tahrirlash/o'chirish yo'q.
drop policy if exists audit_insert on public.admin_audit;
create policy audit_insert on public.admin_audit for insert to authenticated with check (public.is_admin() and admin_id = auth.uid());
drop policy if exists audit_read on public.admin_audit;
create policy audit_read on public.admin_audit for select to authenticated using (public.is_admin());

-- ---------- Boshlang'ich sozlama ----------
insert into public.survey_config (id, data)
values (1, '{"version":"1.0","citizen":{"open":true,"closes":""},"expert":{"open":true,"closes":""},"overrides":{}}')
on conflict (id) do nothing;

-- =====================================================================
-- ADMIN QO'SHISH (Authentication → Users → Add user bilan foydalanuvchi
-- yaratganingizdan keyin, email'ni o'zingiznikiga almashtirib RUN qiling):
--
--   insert into public.admin_users (user_id, role)
--   select id, 'superadmin' from auth.users where email = 'sizning@email.uz'
--   on conflict (user_id) do update set active = true, role = excluded.role;
-- =====================================================================
