-- Run this once in the Supabase SQL Editor after enabling Firebase as a
-- Third-Party Auth provider for Firebase project medicare-7b559.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('doctor-avatars', 'doctor-avatars', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']),
  ('catalog-images', 'catalog-images', true, 5242880,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('medical-files', 'medical-files', false, 20971520,
   array['application/pdf', 'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table if not exists public.health_file_access (
  object_path text primary key,
  owner_uid text not null,
  shared_with text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.health_file_access enable row level security;
grant select, insert, update, delete on public.health_file_access to anon, authenticated;
grant usage on schema storage to anon;
grant select, insert, update, delete on storage.objects to anon;

create or replace function public.is_medicare_firebase_user()
returns boolean
language sql
stable
as $$
  select coalesce(
    auth.jwt() ->> 'iss' = 'https://securetoken.google.com/medicare-7b559'
    and auth.jwt() ->> 'aud' = 'medicare-7b559'
    and auth.jwt() ->> 'email_verified' = 'true',
    false
  );
$$;

grant execute on function public.is_medicare_firebase_user() to anon, authenticated;

drop policy if exists "Firebase users read owned or shared file access" on public.health_file_access;
create policy "Firebase users read owned or shared file access"
on public.health_file_access for select to public
using (
  public.is_medicare_firebase_user()
  and (
    owner_uid = auth.jwt() ->> 'sub'
    or auth.jwt() ->> 'sub' = any(shared_with)
  )
);

drop policy if exists "Firebase users register owned files" on public.health_file_access;
create policy "Firebase users register owned files"
on public.health_file_access for insert to public
with check (
  public.is_medicare_firebase_user()
  and owner_uid = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users update owned file sharing" on public.health_file_access;
create policy "Firebase users update owned file sharing"
on public.health_file_access for update to public
using (public.is_medicare_firebase_user() and owner_uid = auth.jwt() ->> 'sub')
with check (public.is_medicare_firebase_user() and owner_uid = auth.jwt() ->> 'sub');

drop policy if exists "Firebase users delete owned file metadata" on public.health_file_access;
create policy "Firebase users delete owned file metadata"
on public.health_file_access for delete to public
using (public.is_medicare_firebase_user() and owner_uid = auth.jwt() ->> 'sub');

drop policy if exists "Firebase users upload own doctor avatars" on storage.objects;
create policy "Firebase users upload own doctor avatars"
on storage.objects for insert to public
with check (
  bucket_id = 'doctor-avatars'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users delete own doctor avatars" on storage.objects;
create policy "Firebase users delete own doctor avatars"
on storage.objects for delete to public
using (
  bucket_id = 'doctor-avatars'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users upload own catalog images" on storage.objects;
create policy "Firebase users upload own catalog images"
on storage.objects for insert to public
with check (
  bucket_id = 'catalog-images'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users delete own catalog images" on storage.objects;
create policy "Firebase users delete own catalog images"
on storage.objects for delete to public
using (
  bucket_id = 'catalog-images'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users upload own medical files" on storage.objects;
create policy "Firebase users upload own medical files"
on storage.objects for insert to public
with check (
  bucket_id = 'medical-files'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Owners and explicitly shared doctors read medical files" on storage.objects;
create policy "Owners and explicitly shared doctors read medical files"
on storage.objects for select to public
using (
  bucket_id = 'medical-files'
  and public.is_medicare_firebase_user()
  and (
    (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
    or exists (
      select 1
      from public.health_file_access access
      where access.object_path = name
        and (
          access.owner_uid = auth.jwt() ->> 'sub'
          or auth.jwt() ->> 'sub' = any(access.shared_with)
        )
    )
  )
);

drop policy if exists "Firebase users delete own medical files" on storage.objects;
create policy "Firebase users delete own medical files"
on storage.objects for delete to public
using (
  bucket_id = 'medical-files'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);

drop policy if exists "Firebase users replace own medical files" on storage.objects;
create policy "Firebase users replace own medical files"
on storage.objects for update to public
using (
  bucket_id = 'medical-files'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
)
with check (
  bucket_id = 'medical-files'
  and public.is_medicare_firebase_user()
  and (storage.foldername(name))[1] = auth.jwt() ->> 'sub'
);