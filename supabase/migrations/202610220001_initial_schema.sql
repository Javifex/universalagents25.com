-- Universal Agents 25: database foundation, without enabling a marketplace or AI worker.
begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;

create table public.profiles (
  id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  display_name text not null default '' check (char_length(display_name) <= 100),
  bio text not null default '' check (char_length(bio) <= 2000),
  is_public boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.offerings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid default auth.uid() references public.profiles(id),
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' and char_length(slug) <= 120),
  title text not null check (char_length(title) between 1 and 200),
  description text not null default '' check (char_length(description) <= 10000),
  kind text not null check (kind in ('service', 'agent', 'multiagent', 'skill')),
  audience text not null default 'specialized' check (audience in ('general', 'specialized')),
  visibility text not null default 'draft' check (visibility in ('draft', 'private', 'public')),
  is_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  constraint offering_owner_matches_audience check (
    (audience = 'general' and owner_id is null) or
    (audience = 'specialized' and owner_id is not null)
  )
);

create table public.offering_versions (
  id uuid primary key default gen_random_uuid(),
  offering_id uuid not null references public.offerings(id),
  version integer not null check (version > 0),
  definition jsonb not null default '{}'::jsonb check (jsonb_typeof(definition) = 'object'),
  created_at timestamptz not null default now(),
  unique (offering_id, version)
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  contractor_id uuid not null default auth.uid() references public.profiles(id),
  executor_id uuid references public.profiles(id),
  title text not null check (char_length(title) between 1 and 200),
  description text not null default '' check (char_length(description) <= 10000),
  status text not null default 'draft' check (status in ('draft', 'active', 'completed', 'cancelled')),
  created_at timestamptz not null default now(),
  check (executor_id is null or contractor_id <> executor_id),
  check (status not in ('active', 'completed') or executor_id is not null)
);

create table public.project_tasks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id),
  title text not null check (char_length(title) between 1 and 200),
  description text not null default '' check (char_length(description) <= 10000),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'review', 'done')),
  created_at timestamptz not null default now()
);

create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id),
  reviewer_id uuid not null default auth.uid() references public.profiles(id),
  reviewed_id uuid not null references public.profiles(id),
  reviewed_role text not null check (reviewed_role in ('contractor', 'executor')),
  score smallint not null check (score between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 2000),
  created_at timestamptz not null default now(),
  unique (project_id, reviewer_id),
  check (reviewer_id <> reviewed_id)
);

create table public.agent_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  offering_id uuid not null references public.offerings(id),
  project_id uuid references public.projects(id),
  status text not null default 'queued' check (status in ('queued', 'running', 'succeeded', 'failed')),
  input_path text,
  output_path text,
  cost_usd numeric(16, 8) check (cost_usd >= 0 and cost_usd <> 'NaN'::numeric),
  input_tokens bigint check (input_tokens >= 0),
  output_tokens bigint check (output_tokens >= 0),
  created_at timestamptz not null default now()
);

create table public.project_consents (
  project_id uuid not null references public.projects(id),
  user_id uuid not null default auth.uid() references public.profiles(id),
  purpose text not null check (purpose in ('context', 'learning')),
  granted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (project_id, user_id, purpose)
);

create table public.self_evaluations (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(id),
  project_id uuid references public.projects(id),
  notes text not null check (char_length(notes) between 1 and 10000),
  created_at timestamptz not null default now()
);

create table public.learning_proposals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  project_id uuid references public.projects(id),
  kind text not null check (kind in ('agent', 'multiagent', 'skill')),
  explanation text not null check (char_length(explanation) between 1 and 10000),
  definition jsonb not null default '{}'::jsonb check (jsonb_typeof(definition) = 'object'),
  decision text not null default 'pending' check (decision in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create index offerings_owner_idx on public.offerings(owner_id);
create index offerings_public_idx on public.offerings(visibility) where visibility = 'public';
create index projects_contractor_idx on public.projects(contractor_id);
create index projects_executor_idx on public.projects(executor_id);
create index projects_storage_path_idx on public.projects((id::text));
create index project_tasks_project_idx on public.project_tasks(project_id);
create index reviews_reviewer_idx on public.reviews(reviewer_id);
create index reviews_reputation_idx on public.reviews(reviewed_id, reviewed_role);
create index agent_runs_owner_idx on public.agent_runs(owner_id);
create index agent_runs_offering_idx on public.agent_runs(offering_id);
create index agent_runs_project_idx on public.agent_runs(project_id);
create index project_consents_user_idx on public.project_consents(user_id);
create index self_evaluations_owner_idx on public.self_evaluations(owner_id);
create index self_evaluations_project_idx on public.self_evaluations(project_id);
create index learning_proposals_owner_idx on public.learning_proposals(owner_id);
create index learning_proposals_project_idx on public.learning_proposals(project_id);

create function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'display_name', ''), 100))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function private.handle_new_user() from public, anon, authenticated;
create trigger ua25_auth_user_created after insert on auth.users
for each row execute function private.handle_new_user();

-- User-controlled Auth metadata supplies a label only, never permissions or visibility.
insert into public.profiles (id, display_name)
select id, left(coalesce(raw_user_meta_data ->> 'display_name', ''), 100) from auth.users
on conflict (id) do nothing;

create function private.owns_offering(p_offering_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.offerings o
    where o.id = p_offering_id and o.owner_id = (select auth.uid())
  );
$$;

create function private.is_project_member(p_project_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    where p.id = p_project_id
      and (p.contractor_id = (select auth.uid()) or p.executor_id = (select auth.uid()))
  );
$$;

create function private.can_create_review(p_project_id uuid, p_reviewer_id uuid, p_reviewed_id uuid, p_role text)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_reviewer_id = (select auth.uid()) and exists (
    select 1 from public.projects p
    where p.id = p_project_id and p.status = 'completed' and (
      (p.contractor_id = p_reviewer_id and p.executor_id = p_reviewed_id and p_role = 'executor') or
      (p.executor_id = p_reviewer_id and p.contractor_id = p_reviewed_id and p_role = 'contractor')
    )
  );
$$;

create function private.is_project_path_member(p_project_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    where p.id::text = p_project_path
      and (p.contractor_id = (select auth.uid()) or p.executor_id = (select auth.uid()))
  );
$$;

create function private.can_read_project_file(p_project_path text, p_uploader_id text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.projects p
    where p.id::text = p_project_path
      and (p.contractor_id = (select auth.uid()) or p.executor_id = (select auth.uid()))
      and (p_uploader_id = p.contractor_id::text or p_uploader_id = p.executor_id::text)
      and (p_uploader_id = (select auth.uid())::text or exists (
        select 1 from public.project_consents c
        where c.project_id = p.id and c.user_id::text = p_uploader_id
          and c.purpose = 'context' and c.granted
      ))
  );
$$;

revoke all on function private.owns_offering(uuid), private.is_project_member(uuid),
  private.can_create_review(uuid, uuid, uuid, text), private.is_project_path_member(text),
  private.can_read_project_file(text, text) from public, anon, authenticated;
grant execute on function private.owns_offering(uuid), private.is_project_member(uuid),
  private.can_create_review(uuid, uuid, uuid, text), private.is_project_path_member(text),
  private.can_read_project_file(text, text) to authenticated;

create function private.protect_project_workflow()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (old.status in ('completed', 'cancelled') and new.status is distinct from old.status)
    or (old.status = 'active' and new.status not in ('active', 'completed', 'cancelled')) then
    raise exception 'Project cannot return to an earlier workflow state' using errcode = '23514';
  end if;
  if new.contractor_id is distinct from old.contractor_id
    or new.executor_id is distinct from old.executor_id then
    if old.status <> 'draft' then
      raise exception 'Project participants can only change in a draft' using errcode = '23514';
    end if;
    -- Consent to a previous counterpart must not carry into a different relationship.
    update public.project_consents set granted = false
      where project_id = old.id and granted;
  end if;
  return new;
end;
$$;
revoke all on function private.protect_project_workflow() from public, anon, authenticated;
create trigger ua25_protect_project_workflow before update on public.projects
for each row execute function private.protect_project_workflow();

create function private.stamp_consent_update()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.stamp_consent_update() from public, anon, authenticated;
create trigger ua25_consent_updated before update on public.project_consents
for each row execute function private.stamp_consent_update();

alter table public.profiles enable row level security;
alter table public.offerings enable row level security;
alter table public.offering_versions enable row level security;
alter table public.projects enable row level security;
alter table public.project_tasks enable row level security;
alter table public.reviews enable row level security;
alter table public.agent_runs enable row level security;
alter table public.project_consents enable row level security;
alter table public.self_evaluations enable row level security;
alter table public.learning_proposals enable row level security;

-- Supabase defaults may grant broad table access; start each application table closed.
revoke all on public.profiles, public.offerings, public.offering_versions, public.projects,
  public.project_tasks, public.reviews, public.agent_runs, public.project_consents,
  public.self_evaluations, public.learning_proposals from public, anon, authenticated;
grant all on public.profiles, public.offerings, public.projects,
  public.project_tasks, public.reviews, public.agent_runs, public.project_consents,
  public.self_evaluations, public.learning_proposals to service_role;
revoke all on public.offering_versions from service_role;
grant select, insert on public.offering_versions to service_role;

grant select on public.profiles, public.offerings to anon, authenticated;
grant insert (display_name, bio, is_public), update (display_name, bio, is_public)
  on public.profiles to authenticated;
create policy profiles_read on public.profiles for select to anon, authenticated
  using (is_public or id = (select auth.uid()));
create policy profiles_insert_own on public.profiles for insert to authenticated
  with check (id = (select auth.uid()));
create policy profiles_update_own on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

grant insert (owner_id, slug, title, description, kind, visibility),
  update (slug, title, description, kind, visibility) on public.offerings to authenticated;
create policy offerings_read on public.offerings for select to anon, authenticated
  using (visibility = 'public' or owner_id = (select auth.uid()));
create policy offerings_insert_own on public.offerings for insert to authenticated
  with check (owner_id = (select auth.uid()) and audience = 'specialized' and not is_enabled);
create policy offerings_update_own on public.offerings for update to authenticated
  using (owner_id = (select auth.uid()) and audience = 'specialized')
  with check (owner_id = (select auth.uid()) and audience = 'specialized');

grant select on public.offering_versions to authenticated;
grant insert (offering_id, version, definition) on public.offering_versions to authenticated;
create policy offering_versions_read_own on public.offering_versions for select to authenticated
  using (private.owns_offering(offering_id));
create policy offering_versions_insert_own on public.offering_versions for insert to authenticated
  with check (private.owns_offering(offering_id));
grant select on public.projects to authenticated;
grant insert (contractor_id, title, description), update (title, description) on public.projects to authenticated;
create policy projects_read_members on public.projects for select to authenticated
  using (contractor_id = (select auth.uid()) or executor_id = (select auth.uid()));
create policy projects_insert_draft on public.projects for insert to authenticated
  with check (contractor_id = (select auth.uid()) and executor_id is null and status = 'draft');
create policy projects_update_contractor on public.projects for update to authenticated
  using (contractor_id = (select auth.uid())) with check (contractor_id = (select auth.uid()));

grant select on public.project_tasks to authenticated;
grant insert (project_id, title, description, status), update (title, description, status)
  on public.project_tasks to authenticated;
create policy project_tasks_read_members on public.project_tasks for select to authenticated
  using (private.is_project_member(project_id));
create policy project_tasks_insert_members on public.project_tasks for insert to authenticated
  with check (private.is_project_member(project_id));
create policy project_tasks_update_members on public.project_tasks for update to authenticated
  using (private.is_project_member(project_id)) with check (private.is_project_member(project_id));

grant select on public.reviews to authenticated;
grant insert (project_id, reviewer_id, reviewed_id, reviewed_role, score, comment) on public.reviews to authenticated;
create policy reviews_read_participants on public.reviews for select to authenticated
  using (reviewer_id = (select auth.uid()) or reviewed_id = (select auth.uid()));
create policy reviews_insert_completed on public.reviews for insert to authenticated
  with check (private.can_create_review(project_id, reviewer_id, reviewed_id, reviewed_role));

grant select on public.agent_runs to authenticated;
create policy agent_runs_read_own on public.agent_runs for select to authenticated
  using (owner_id = (select auth.uid()));

grant select on public.project_consents to authenticated;
grant insert (project_id, user_id, purpose, granted), update (granted) on public.project_consents to authenticated;
create policy project_consents_read_members on public.project_consents for select to authenticated
  using (private.is_project_member(project_id));
create policy project_consents_insert_own on public.project_consents for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_project_member(project_id));
create policy project_consents_update_own on public.project_consents for update to authenticated
  using (user_id = (select auth.uid()) and private.is_project_member(project_id))
  with check (user_id = (select auth.uid()) and private.is_project_member(project_id));

grant select on public.self_evaluations to authenticated;
grant insert (owner_id, project_id, notes), update (notes) on public.self_evaluations to authenticated;
create policy self_evaluations_read_own on public.self_evaluations for select to authenticated
  using (owner_id = (select auth.uid()));
create policy self_evaluations_insert_own on public.self_evaluations for insert to authenticated
  with check (owner_id = (select auth.uid()) and (project_id is null or private.is_project_member(project_id)));
create policy self_evaluations_update_own on public.self_evaluations for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

grant select on public.learning_proposals to authenticated;
grant update (decision) on public.learning_proposals to authenticated;
create policy learning_proposals_read_own on public.learning_proposals for select to authenticated
  using (owner_id = (select auth.uid()));
create policy learning_proposals_decide_own on public.learning_proposals for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

create function public.get_reputation(p_profile_id uuid)
returns table (reviewed_role text, average_score numeric, review_count bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not exists (
    select 1 from public.profiles p
    where p.id = p_profile_id and (p.is_public or p.id = (select auth.uid()))
  ) then
    raise exception 'Reputation is private or profile does not exist' using errcode = '42501';
  end if;
  return query
    select roles.role, avg(r.score), count(r.id)
    from (values ('contractor'::text), ('executor'::text)) as roles(role)
    left join public.reviews r on r.reviewed_role = roles.role and r.reviewed_id = p_profile_id
    group by roles.role order by roles.role;
end;
$$;
revoke all on function public.get_reputation(uuid) from public, anon, authenticated;
grant execute on function public.get_reputation(uuid) to anon, authenticated, service_role;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('account-files', 'account-files', false, 10485760, array[
    'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain', 'application/json', 'text/csv', 'image/png', 'image/jpeg'
  ]),
  ('project-files', 'project-files', false, 10485760, array[
    'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain', 'application/json', 'text/csv', 'image/png', 'image/jpeg'
  ])
on conflict (id) do nothing;

-- Do not silently reuse or change an existing bucket with weaker security settings.
do $$
begin
  if exists (
    select 1 from storage.buckets b where b.id in ('account-files', 'project-files')
    and (b.name <> b.id or b.public is distinct from false or b.file_size_limit is distinct from 10485760
      or b.allowed_mime_types is distinct from array[
        'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'text/plain', 'application/json', 'text/csv', 'image/png', 'image/jpeg'
      ]::text[])
  ) then
    raise exception 'UA25 bucket already exists with different settings; review it before migrating';
  end if;
end;
$$;

create policy ua25_account_files_read on storage.objects for select to authenticated
  using (bucket_id = 'account-files' and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy ua25_account_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'account-files' and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy ua25_account_files_update on storage.objects for update to authenticated
  using (bucket_id = 'account-files' and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'account-files' and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy ua25_account_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'account-files' and owner_id = (select auth.uid())::text
    and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy ua25_project_files_read on storage.objects for select to authenticated
  using (bucket_id = 'project-files'
    and private.can_read_project_file((storage.foldername(name))[1], owner_id));
create policy ua25_project_files_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'project-files' and owner_id = (select auth.uid())::text
    and private.is_project_path_member((storage.foldername(name))[1]));
create policy ua25_project_files_update on storage.objects for update to authenticated
  using (bucket_id = 'project-files' and owner_id = (select auth.uid())::text
    and private.is_project_path_member((storage.foldername(name))[1]))
  with check (bucket_id = 'project-files' and owner_id = (select auth.uid())::text
    and private.is_project_path_member((storage.foldername(name))[1]));
create policy ua25_project_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'project-files' and owner_id = (select auth.uid())::text
    and private.is_project_path_member((storage.foldername(name))[1]));

commit;
