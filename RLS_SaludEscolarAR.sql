-- ============================================================
-- SaludEscolar AR - endurecimiento RLS multi-escuela
-- Idempotente: no elimina tablas ni datos.
-- Ejecutar como administrador en Supabase SQL Editor.
-- ============================================================

begin;

-- Las funciones usadas por RLS viven fuera del esquema expuesto por la API.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.current_school_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select u.escuela_id
  from public.usuarios as u
  where u.id = (select auth.uid())
    and u.activo is true
$$;

create or replace function private.current_user_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select u.rol
  from public.usuarios as u
  where u.id = (select auth.uid())
    and u.activo is true
$$;

revoke all on function private.current_school_id() from public, anon;
revoke all on function private.current_user_role() from public, anon;
grant execute on function private.current_school_id() to authenticated;
grant execute on function private.current_user_role() to authenticated;

-- Toda tabla expuesta que contiene información operativa queda bajo RLS.
alter table public.escuelas       enable row level security;
alter table public.usuarios       enable row level security;
alter table public.alumnos        enable row level security;
alter table public.eventos        enable row level security;
alter table public.notificaciones enable row level security;

-- Evita acceso directo sin autenticar, aun si existieran grants antiguos.
revoke all on table public.usuarios, public.alumnos, public.eventos,
  public.notificaciones from anon;
revoke all on table public.escuelas from anon;

grant select on table public.escuelas to authenticated;
grant select on table public.usuarios to authenticated;
grant select, insert, update on table public.alumnos to authenticated;
grant select, insert, update on table public.eventos to authenticated;
grant select, update on table public.notificaciones to authenticated;

-- Reemplaza todas las políticas antiguas de estas tablas. Las políticas
-- permisivas se combinan con OR; conservar una regla vieja podría abrir datos.
do $$
declare
  p record;
begin
  for p in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('escuelas','usuarios','alumnos','eventos','notificaciones')
  loop
    execute format(
      'drop policy if exists %I on %I.%I',
      p.policyname, p.schemaname, p.tablename
    );
  end loop;
end
$$;

create policy "escuelas_select_own"
on public.escuelas
for select
to authenticated
using (id = (select private.current_school_id()));

create policy "usuarios_select"
on public.usuarios
for select
to authenticated
using (escuela_id = (select private.current_school_id()));

create policy "alumnos_select"
on public.alumnos
for select
to authenticated
using (escuela_id = (select private.current_school_id()));

create policy "alumnos_insert"
on public.alumnos
for insert
to authenticated
with check (
  escuela_id = (select private.current_school_id())
  and (select private.current_user_role()) in ('enfermero', 'director')
);

create policy "alumnos_update"
on public.alumnos
for update
to authenticated
using (
  escuela_id = (select private.current_school_id())
  and (select private.current_user_role()) in ('enfermero', 'director')
)
with check (
  escuela_id = (select private.current_school_id())
  and (select private.current_user_role()) in ('enfermero', 'director')
);

create policy "eventos_select"
on public.eventos
for select
to authenticated
using (escuela_id = (select private.current_school_id()));

create policy "eventos_insert"
on public.eventos
for insert
to authenticated
with check (
  escuela_id = (select private.current_school_id())
  and registrado_por = (select auth.uid())
);

create policy "eventos_update"
on public.eventos
for update
to authenticated
using (
  escuela_id = (select private.current_school_id())
  and (
    (select private.current_user_role()) in ('enfermero', 'director')
    or registrado_por = (select auth.uid())
  )
)
with check (
  escuela_id = (select private.current_school_id())
  and (
    (select private.current_user_role()) in ('enfermero', 'director')
    or registrado_por = (select auth.uid())
  )
);

create policy "notif_select"
on public.notificaciones
for select
to authenticated
using (escuela_id = (select private.current_school_id()));

create policy "notif_update"
on public.notificaciones
for update
to authenticated
using (escuela_id = (select private.current_school_id()))
with check (escuela_id = (select private.current_school_id()));

-- Las vistas creadas por administradores pueden eludir RLS. Esta vista debe
-- ejecutarse con los permisos del usuario que consulta.
alter view if exists public.v_estadisticas_escuela
  set (security_invoker = true);
revoke all on table public.v_estadisticas_escuela from anon;
grant select on table public.v_estadisticas_escuela to authenticated;

-- Fotografías clínicas: bucket privado y rutas:
--   <escuela_uuid>/<evento_uuid>/<archivo>
insert into storage.buckets
  (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'fotos-eventos',
    'fotos-eventos',
    false,
    10485760,
    array['image/jpeg','image/png','image/webp','image/heic','image/heif']
  )
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fotos_select_own_school" on storage.objects;
drop policy if exists "fotos_insert_own_school" on storage.objects;
drop policy if exists "fotos_update_own_school" on storage.objects;
drop policy if exists "fotos_delete_own_school" on storage.objects;
drop policy if exists "fotos_tenant_guard_select" on storage.objects;
drop policy if exists "fotos_tenant_guard_insert" on storage.objects;
drop policy if exists "fotos_tenant_guard_update" on storage.objects;
drop policy if exists "fotos_tenant_guard_delete" on storage.objects;

-- Barreras restrictivas: aunque exista otra política permisiva antigua,
-- nunca permite cruzar de escuela dentro de fotos-eventos. Para otros
-- buckets la condición es neutra y no altera sus reglas.
create policy "fotos_tenant_guard_select"
on storage.objects
as restrictive
for select
to authenticated
using (
  bucket_id <> 'fotos-eventos'
  or (storage.foldername(name))[1] =
     (select private.current_school_id())::text
);

create policy "fotos_tenant_guard_insert"
on storage.objects
as restrictive
for insert
to authenticated
with check (
  bucket_id <> 'fotos-eventos'
  or (storage.foldername(name))[1] =
     (select private.current_school_id())::text
);

create policy "fotos_tenant_guard_update"
on storage.objects
as restrictive
for update
to authenticated
using (
  bucket_id <> 'fotos-eventos'
  or (storage.foldername(name))[1] =
     (select private.current_school_id())::text
)
with check (
  bucket_id <> 'fotos-eventos'
  or (storage.foldername(name))[1] =
     (select private.current_school_id())::text
);

create policy "fotos_tenant_guard_delete"
on storage.objects
as restrictive
for delete
to authenticated
using (
  bucket_id <> 'fotos-eventos'
  or (storage.foldername(name))[1] =
     (select private.current_school_id())::text
);

create policy "fotos_select_own_school"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'fotos-eventos'
  and (storage.foldername(name))[1] =
      (select private.current_school_id())::text
);

create policy "fotos_insert_own_school"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'fotos-eventos'
  and (storage.foldername(name))[1] =
      (select private.current_school_id())::text
);

create policy "fotos_update_own_school"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'fotos-eventos'
  and (storage.foldername(name))[1] =
      (select private.current_school_id())::text
)
with check (
  bucket_id = 'fotos-eventos'
  and (storage.foldername(name))[1] =
      (select private.current_school_id())::text
);

create policy "fotos_delete_own_school"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'fotos-eventos'
  and (storage.foldername(name))[1] =
      (select private.current_school_id())::text
  and (
    (select private.current_user_role()) in ('enfermero', 'director')
    or owner_id = (select auth.uid()::text)
  )
);

commit;

-- ============================================================
-- Diagnóstico posterior (solo lectura)
-- ============================================================
select schemaname, tablename, rowsecurity
from pg_tables
where schemaname = 'public'
  and tablename in ('escuelas','usuarios','alumnos','eventos','notificaciones')
order by tablename;

select schemaname, tablename, policyname, roles, cmd
from pg_policies
where (schemaname = 'public'
       and tablename in ('escuelas','usuarios','alumnos','eventos','notificaciones'))
   or (schemaname = 'storage' and tablename = 'objects')
order by schemaname, tablename, policyname;

select id, public
from storage.buckets
where id = 'fotos-eventos';
