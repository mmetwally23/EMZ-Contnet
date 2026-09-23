-- EMZ Content Studio. Run in the project's SQL editor as the project owner.
-- Access is granted only through these functions. No client has direct table access.
create table if not exists public.emz_members(email text primary key, role text not null check(role in ('admin','editor')));
create table if not exists public.emz_workspace(id integer primary key check(id=1), revision bigint not null default 0, document jsonb, updated_at timestamptz default now(), updated_by uuid);
create table if not exists public.emz_revisions(revision bigint primary key, document jsonb not null, changed_at timestamptz default now(), changed_by uuid);
alter table public.emz_members enable row level security;
alter table public.emz_workspace enable row level security;
alter table public.emz_revisions enable row level security;
revoke all on public.emz_members,public.emz_workspace,public.emz_revisions from anon,authenticated;
insert into public.emz_workspace(id,revision,document) values(1,0,null) on conflict(id) do nothing;

create or replace function public.emz_is_member() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.emz_members m join auth.users u on lower(u.email)=lower(m.email)
 where u.id=auth.uid() and u.email_confirmed_at is not null)
$$;
revoke all on function public.emz_is_member() from public;
grant execute on function public.emz_is_member() to authenticated;


-- Owner-approved link editing. Only the database owner can change this switch.
create table if not exists public.emz_sharing(id integer primary key check(id=1),link_editing boolean not null default false);
alter table public.emz_sharing enable row level security;
revoke all on public.emz_sharing from anon,authenticated;
insert into public.emz_sharing(id,link_editing) values(1,false) on conflict do nothing;
create or replace function public.emz_can_edit() returns boolean
language sql stable security definer set search_path='' as $$
 select coalesce((select link_editing from public.emz_sharing where id=1),false) or public.emz_is_member()
$$;
revoke all on function public.emz_can_edit() from public;

create or replace function public.emz_public_document(d jsonb) returns jsonb
language sql immutable set search_path='' as $$
 select jsonb_build_object('schema','emz-studio-v2','revision',d->'revision','snapshotId',d->'snapshotId',
 'settings',jsonb_build_object('teamName',d->'settings'->'teamName','timezone',coalesce(d->'settings'->'timezone','""'::jsonb)),
 'stages',d->'stages','views','[]'::jsonb,'customFields','[]'::jsonb,
 'notes',coalesce((select jsonb_agg(n) from jsonb_array_elements(coalesce(d->'notes','[]')) n where not coalesce((n->>'internal')::boolean,false)),'[]'),
 'posts',coalesce((select jsonb_agg((select jsonb_object_agg(k,v) from jsonb_each(p) e(k,v) where k=any(array['id','date','time','type','title','summary','caption','reference','finalLink','postingLink','tov','service','pillar','campaign','cover','media','platforms','stage','order','archived'])))
 from jsonb_array_elements(d->'posts') p where not coalesce((p->>'archived')::boolean,false)),'[]'))
$$;
revoke all on function public.emz_public_document(jsonb) from public;

create or replace function public.emz_read(team boolean default false,known_revision bigint default -1) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare w public.emz_workspace; allowed boolean;
begin
 allowed:=public.emz_can_edit();
 if team and not allowed then raise exception 'Your account does not have EMZ team access.'; end if;
 select * into w from public.emz_workspace where id=1;
 if w.document is null then return null; end if;
 if w.revision=known_revision then return jsonb_build_object('revision',w.revision,'can_edit',allowed); end if;
 return jsonb_build_object('revision',w.revision,'can_edit',allowed,'document',case when allowed and (team or coalesce((select link_editing from public.emz_sharing where id=1),false)) then w.document else public.emz_public_document(w.document) end);
end $$;
revoke all on function public.emz_read(boolean,bigint) from public;
grant execute on function public.emz_read(boolean,bigint) to anon,authenticated;

create or replace function public.emz_save(expected_revision bigint,document jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare w public.emz_workspace; p jsonb; next_revision bigint;
begin
 if not public.emz_can_edit() then raise exception 'Team access required.'; end if;
 if document->>'schema'<>'emz-studio-v2' or jsonb_typeof(document->'posts') is distinct from 'array' or jsonb_array_length(document->'posts')>3000 or octet_length(document::text)>15000000 then raise exception 'Invalid workspace document.'; end if;
 if (select count(*)<>count(distinct x->>'id') from jsonb_array_elements(document->'posts') x) then raise exception 'Duplicate post IDs.'; end if;
 for p in select * from jsonb_array_elements(document->'posts') loop
   if coalesce(p->>'id','')='' or jsonb_typeof(p->'title') is distinct from 'string' then raise exception 'Invalid post.'; end if;
   if p->>'stage'='ready' and coalesce(p->>'finalLink','')!~'^https?://' then raise exception 'Ready posts require a final URL.'; end if;
 end loop;
 select * into w from public.emz_workspace where id=1 for update;
 if w.revision<>expected_revision then raise exception 'Edit conflict: a newer version is online.'; end if;
 if w.document is not null then insert into public.emz_revisions(revision,document,changed_by) values(w.revision,w.document,w.updated_by) on conflict do nothing; end if;
 next_revision:=w.revision+1;
 update public.emz_workspace set revision=next_revision,document=emz_save.document,updated_at=now(),updated_by=auth.uid() where id=1;
 delete from public.emz_revisions where revision<(next_revision-100);
 return jsonb_build_object('revision',next_revision);
end $$;
revoke all on function public.emz_save(bigint,jsonb) from public;
grant execute on function public.emz_save(bigint,jsonb) to anon,authenticated;

create or replace function public.emz_access(operation text default 'list',member_email text default '',member_role text default 'editor') returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.emz_members m join auth.users u on lower(u.email)=lower(m.email) where u.id=auth.uid() and u.email_confirmed_at is not null and m.role='admin') then raise exception 'Workspace administrator access required.'; end if;
 if operation in ('grant','revoke') then
  if member_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then raise exception 'Enter a valid email.'; end if;
  if exists(select 1 from auth.users u where u.id=auth.uid() and lower(u.email)=lower(member_email)) then raise exception 'You cannot change your own administrator access.'; end if;
  if operation='grant' then insert into public.emz_members(email,role) values(lower(trim(member_email)),member_role) on conflict(email) do update set role=excluded.role;
  else delete from public.emz_members where email=lower(trim(member_email)); end if;
 elsif operation<>'list' then raise exception 'Unknown operation.'; end if;
 return coalesce((select jsonb_agg(to_jsonb(m)) from public.emz_members m),'[]');
end $$;
revoke all on function public.emz_access(text,text,text) from public;
grant execute on function public.emz_access(text,text,text) to authenticated;

-- Grant access explicitly (replace the example email, then run separately).
-- insert into public.emz_members(email,role) values ('YOUR_TEAM_EMAIL','admin')
-- on conflict(email) do update set role=excluded.role;
notify pgrst,'reload schema';
