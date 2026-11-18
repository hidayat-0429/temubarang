-- Perbaikan idempoten: aman dijalankan walau sebagian objek sudah ada.
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as '
begin
  insert into profiles (id, name, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> ''name'', ''''),
    new.raw_user_meta_data ->> ''username''
  );
  return new;
end;
';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

alter table profiles enable row level security;
alter table reports enable row level security;
alter table claims enable row level security;

drop policy if exists "profiles terbaca semua" on profiles;
drop policy if exists "profil sendiri bisa diubah" on profiles;
drop policy if exists "reports terbaca semua" on reports;
drop policy if exists "reports dibuat oleh pemilik" on reports;
drop policy if exists "reports diubah oleh pemilik" on reports;
drop policy if exists "reports dihapus oleh pemilik" on reports;
drop policy if exists "claims terbaca semua" on claims;
drop policy if exists "claims dibuat oleh pengklaim" on claims;

create policy "profiles terbaca semua" on profiles for select using (true);
create policy "profil sendiri bisa diubah" on profiles for update using (auth.uid() = id);
create policy "reports terbaca semua" on reports for select using (true);
create policy "reports dibuat oleh pemilik" on reports for insert with check (auth.uid() = user_id);
create policy "reports diubah oleh pemilik" on reports for update using (auth.uid() = user_id);
create policy "reports dihapus oleh pemilik" on reports for delete using (auth.uid() = user_id);
create policy "claims terbaca semua" on claims for select using (true);
create policy "claims dibuat oleh pengklaim" on claims for insert with check (auth.uid() = user_id);

insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "foto terbaca semua" on storage.objects;
drop policy if exists "foto diupload pengguna masuk" on storage.objects;
drop policy if exists "foto dihapus pemiliknya" on storage.objects;
create policy "foto terbaca semua" on storage.objects for select using (bucket_id = 'photos');
create policy "foto diupload pengguna masuk" on storage.objects for insert to authenticated with check (bucket_id = 'photos');
create policy "foto dihapus pemiliknya" on storage.objects for delete to authenticated using (bucket_id = 'photos' and owner = auth.uid());