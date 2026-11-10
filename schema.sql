-- Jalankan seluruhnya di Supabase > SQL Editor
create table profiles(id uuid primary key references auth.users on delete cascade, name text, role text not null default 'karyawan', active boolean not null default true);
create table hospitals(id uuid primary key default gen_random_uuid(), name text not null, lat double precision not null, lng double precision not null, radius int not null default 200);
create table attendance(
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id), day date not null,
  in_at timestamptz, in_lat double precision, in_lng double precision, in_acc int, in_photo text, in_source text, in_synced timestamptz,
  out_at timestamptz, out_lat double precision, out_lng double precision, out_acc int, out_photo text, out_source text, out_synced timestamptz,
  unique(user_id, day));
create table visits(
  id uuid primary key, user_id uuid not null references profiles(id), day date not null,
  hospital_id uuid references hospitals(id) on delete set null, place_manual text, tujuan text,
  status text not null default 'rencana',
  ci_at timestamptz, ci_lat double precision, ci_lng double precision, ci_acc int, in_radius boolean, ci_synced timestamptz,
  co_at timestamptz, co_lat double precision, co_lng double precision, co_acc int, co_synced timestamptz,
  hasil text, created_at timestamptz default now());

-- Cap waktu server: terisi otomatis saat jam HP masuk ke database
create function stamp_att() returns trigger language plpgsql as $$ begin
  new.in_synced := case when new.in_at is null then null when tg_op='UPDATE' and old.in_at is not distinct from new.in_at then old.in_synced else now() end;
  new.out_synced := case when new.out_at is null then null when tg_op='UPDATE' and old.out_at is not distinct from new.out_at then old.out_synced else now() end;
  return new; end $$;
create function stamp_vis() returns trigger language plpgsql as $$ begin
  new.ci_synced := case when new.ci_at is null then null when tg_op='UPDATE' and old.ci_at is not distinct from new.ci_at then old.ci_synced else now() end;
  new.co_synced := case when new.co_at is null then null when tg_op='UPDATE' and old.co_at is not distinct from new.co_at then old.co_synced else now() end;
  return new; end $$;
create trigger t_att before insert or update on attendance for each row execute function stamp_att();
create trigger t_vis before insert or update on visits for each row execute function stamp_vis();

-- Profil otomatis dibuat saat akun baru ditambahkan
create function new_user() returns trigger language plpgsql security definer set search_path=public as $$ begin
  insert into profiles(id,name) values(new.id, coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1))); return new; end $$;
create trigger on_new_user after insert on auth.users for each row execute function new_user();

-- Hak akses: karyawan hanya data sendiri, admin melihat semua
create function is_admin() returns boolean language sql security definer stable set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
alter table profiles enable row level security;
alter table hospitals enable row level security;
alter table attendance enable row level security;
alter table visits enable row level security;
create policy p_sel on profiles for select using (id=auth.uid() or is_admin());
create policy p_adm on profiles for all using (is_admin()) with check (is_admin());
create policy h_sel on hospitals for select using (auth.uid() is not null);
create policy h_adm on hospitals for all using (is_admin()) with check (is_admin());
create policy a_own on attendance for all using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy a_adm on attendance for select using (is_admin());
create policy v_own on visits for all using (user_id=auth.uid()) with check (user_id=auth.uid());
create policy v_adm on visits for select using (is_admin());

-- Penyimpanan foto selfie (privat)
insert into storage.buckets(id,name,public) values('selfies','selfies',false) on conflict do nothing;
create policy s_ins on storage.objects for insert with check (bucket_id='selfies' and (storage.foldername(name))[1]=auth.uid()::text);
create policy s_upd on storage.objects for update using (bucket_id='selfies' and (storage.foldername(name))[1]=auth.uid()::text);
create policy s_sel on storage.objects for select using (bucket_id='selfies' and ((storage.foldername(name))[1]=auth.uid()::text or is_admin()));

-- Setelah membuat akun atasan di Authentication > Users, jadikan admin:
-- update profiles set role='admin' where id=(select id from auth.users where email='EMAIL_ATASAN');
