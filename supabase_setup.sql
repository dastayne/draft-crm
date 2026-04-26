-- 1) Создай проект Supabase на бесплатном тарифе.
-- 2) SQL Editor → New query → вставь этот SQL → Run.
-- 3) Project Settings → API → скопируй Project URL и anon public key.
-- 4) В CRM нажми "Синк" и вставь URL, anon key, Sync ID = main.

create table if not exists public.draft_crm_state (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.draft_crm_state enable row level security;

drop policy if exists "draft_crm_state_read" on public.draft_crm_state;
drop policy if exists "draft_crm_state_write" on public.draft_crm_state;

-- Для личного теста: доступ по anon key. Не публикуй ссылку и ключ в открытом доступе.
create policy "draft_crm_state_read"
  on public.draft_crm_state
  for select
  to anon
  using (true);

create policy "draft_crm_state_write"
  on public.draft_crm_state
  for all
  to anon
  using (true)
  with check (true);

insert into public.draft_crm_state (id, data)
values ('main', '{}'::jsonb)
on conflict (id) do nothing;

-- Включает realtime-события для таблицы.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'draft_crm_state'
  ) then
    alter publication supabase_realtime add table public.draft_crm_state;
  end if;
end $$;

-- Storage для фотографий. Фото хранятся отдельно, а в JSON остаётся только ссылка.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'draft-photos',
  'draft-photos',
  true,
  5242880,
  array['image/jpeg','image/png','image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "draft_photos_read" on storage.objects;
drop policy if exists "draft_photos_insert" on storage.objects;
drop policy if exists "draft_photos_update" on storage.objects;
drop policy if exists "draft_photos_delete" on storage.objects;

create policy "draft_photos_read"
  on storage.objects
  for select
  to anon
  using (bucket_id = 'draft-photos');

create policy "draft_photos_insert"
  on storage.objects
  for insert
  to anon
  with check (bucket_id = 'draft-photos');

create policy "draft_photos_update"
  on storage.objects
  for update
  to anon
  using (bucket_id = 'draft-photos')
  with check (bucket_id = 'draft-photos');

create policy "draft_photos_delete"
  on storage.objects
  for delete
  to anon
  using (bucket_id = 'draft-photos');
