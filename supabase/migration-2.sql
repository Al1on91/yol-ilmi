-- =====================================================================
-- YO‘L ILMI — 2-yangilanish: ekspert komissiyasi, muammo xabarlari, rasm saqlash.
-- Supabase → SQL Editor → New query → shu faylni to'liq joylab → RUN.
-- Qayta ishga tushirish xavfsiz.
-- =====================================================================

-- Havola faolmi (auditoriyadan qat'i nazar). Muammo xabarlari uchun.
create or replace function public.link_active(t text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.access_links l where l.token = t and l.active);
$$;
revoke all on function public.link_active(text) from public;
grant execute on function public.link_active(text) to anon, authenticated;

-- ---------- Ekspert komissiyasi baholari ----------
create table if not exists public.expert_scores (
  topic_id     uuid not null references public.research_topics(id) on delete cascade,
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  relevance    smallint not null check (relevance between 1 and 5),
  feasibility  smallint not null check (feasibility between 1 and 5),
  impact       smallint not null check (impact between 1 and 5),
  comment      text not null default '' check (char_length(comment) <= 300),
  updated_at   timestamptz not null default now(),
  primary key (topic_id, user_id)
);
alter table public.expert_scores enable row level security;
revoke all on public.expert_scores from anon, authenticated;
grant select, insert, update, delete on public.expert_scores to authenticated;
drop policy if exists scores_read on public.expert_scores;
create policy scores_read on public.expert_scores for select to authenticated using (public.is_admin());
drop policy if exists scores_insert on public.expert_scores;
create policy scores_insert on public.expert_scores for insert to authenticated with check (public.is_admin() and user_id = auth.uid());
drop policy if exists scores_update on public.expert_scores;
create policy scores_update on public.expert_scores for update to authenticated using (public.is_admin() and user_id = auth.uid()) with check (public.is_admin() and user_id = auth.uid());
drop policy if exists scores_delete on public.expert_scores;
create policy scores_delete on public.expert_scores for delete to authenticated using (public.is_admin() and user_id = auth.uid());

-- ---------- Muammo xabarlari (ixtiyoriy, anonim EMAS, so'rovdan alohida) ----------
create table if not exists public.road_reports (
  id           uuid primary key default gen_random_uuid(),
  created_at   timestamptz not null default now(),
  region       smallint not null check (region between 0 and 13),
  place        text not null check (char_length(place) between 3 and 200),
  category     text not null check (char_length(category) <= 80),
  description  text not null default '' check (char_length(description) <= 1000),
  lat          numeric(8,4) check (lat between 37 and 46),
  lng          numeric(8,4) check (lng between 55 and 74),
  photos       jsonb not null default '[]'::jsonb check (jsonb_typeof(photos) = 'array' and jsonb_array_length(photos) <= 3),
  contact      text check (char_length(contact) <= 120),
  consent      boolean not null check (consent),
  link_token   text references public.access_links(token) on delete set null,
  status       text not null default 'new' check (status in ('new','progress','resolved','rejected')),
  admin_note   text not null default '' check (char_length(admin_note) <= 500)
);
alter table public.road_reports enable row level security;
revoke all on public.road_reports from anon, authenticated;
grant insert (id, region, place, category, description, lat, lng, photos, contact, consent, link_token) on public.road_reports to anon, authenticated;
grant select, update, delete on public.road_reports to authenticated;
drop policy if exists reports_insert on public.road_reports;
create policy reports_insert on public.road_reports for insert to anon, authenticated
  with check (public.link_active(link_token) or public.is_admin());
drop policy if exists reports_admin_select on public.road_reports;
create policy reports_admin_select on public.road_reports for select to authenticated using (public.is_admin());
drop policy if exists reports_admin_update on public.road_reports;
create policy reports_admin_update on public.road_reports for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists reports_admin_delete on public.road_reports;
create policy reports_admin_delete on public.road_reports for delete to authenticated using (public.is_admin());

-- ---------- Rasmlar ombori (yopiq) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('reports', 'reports', false, 3145728, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg'];

drop policy if exists reports_photo_upload on storage.objects;
create policy reports_photo_upload on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'reports' and (public.link_active((storage.foldername(name))[1]) or public.is_admin()));
drop policy if exists reports_photo_read on storage.objects;
create policy reports_photo_read on storage.objects for select to authenticated
  using (bucket_id = 'reports' and public.is_admin());
drop policy if exists reports_photo_delete on storage.objects;
create policy reports_photo_delete on storage.objects for delete to authenticated
  using (bucket_id = 'reports' and public.is_admin());
