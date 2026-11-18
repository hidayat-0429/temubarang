-- Skema TemuBarang di Supabase. Jalankan sekali di SQL Editor proyek baru.

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  name text not null,
  username text unique not null
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  location text not null,
  description text not null default '',
  status text not null,
  item_status text not null,
  created_at timestamptz not null default now(),
  user_id uuid references profiles(id) on delete cascade,
  phone text,
  photos text[] not null default '{}'
);

create table claims (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (report_id, user_id)
);

-- Profil dibuat otomatis saat akun auth mendaftar.
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name, username)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'username'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function handle_new_user();

alter table profiles enable row level security;
alter table reports enable row level security;
alter table claims enable row level security;

create policy "profiles terbaca semua" on profiles for select using (true);
create policy "profil sendiri bisa diubah" on profiles for update using (auth.uid() = id);

create policy "reports terbaca semua" on reports for select using (true);
create policy "reports dibuat oleh pemilik" on reports for insert with check (auth.uid() = user_id);
create policy "reports diubah oleh pemilik" on reports for update using (auth.uid() = user_id);
create policy "reports dihapus oleh pemilik" on reports for delete using (auth.uid() = user_id);

create policy "claims terbaca semua" on claims for select using (true);
create policy "claims dibuat oleh pengklaim" on claims for insert with check (auth.uid() = user_id);

-- Bucket foto publik untuk dibaca, upload hanya oleh pengguna masuk.
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

create policy "foto terbaca semua" on storage.objects for select using (bucket_id = 'photos');
create policy "foto diupload pengguna masuk" on storage.objects for insert to authenticated with check (bucket_id = 'photos');
create policy "foto dihapus pemiliknya" on storage.objects for delete to authenticated using (bucket_id = 'photos' and owner = auth.uid());