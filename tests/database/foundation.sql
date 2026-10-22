-- Run against a disposable/local Supabase database as postgres:
-- psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f tests/database/foundation.sql
-- No managed-schema fixture is loaded here. Every test record/helper rolls back.
BEGIN;
CREATE TEMP TABLE database_test_results (label text NOT NULL);
GRANT SELECT, INSERT ON database_test_results TO anon, authenticated, service_role;
CREATE FUNCTION public.ua25_test_assert(condition boolean, label text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
BEGIN
  IF condition IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: %', label;
  END IF;
  INSERT INTO pg_temp.database_test_results VALUES (label);
END;
$$;
CREATE FUNCTION public.ua25_test_expect_error(statement text, expected_state text, label text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER AS $$
DECLARE actual_state text;
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS actual_state = RETURNED_SQLSTATE;
  END;
  PERFORM public.ua25_test_assert(actual_state = expected_state,
    label || ' (expected ' || expected_state || ', received ' || coalesce(actual_state, 'no error') || ')');
END;
$$;
GRANT EXECUTE ON FUNCTION public.ua25_test_assert(boolean,text),
  public.ua25_test_expect_error(text,text,text) TO anon, authenticated, service_role;

SELECT public.ua25_test_assert(NOT EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r' AND NOT c.relrowsecurity
), 'every public data table enables RLS');
SELECT public.ua25_test_assert(NOT EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r'
    AND has_table_privilege('anon',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER')
), 'anonymous clients have no table write grants');
SELECT public.ua25_test_assert(NOT EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='public' AND c.relkind='r'
    AND has_table_privilege('authenticated',c.oid,'DELETE,TRUNCATE,REFERENCES,TRIGGER')
), 'clients have no destructive or schema-level table grants');
SELECT public.ua25_test_assert(NOT has_table_privilege('authenticated','public.agent_runs','INSERT')
  AND NOT has_table_privilege('authenticated','public.agent_runs','UPDATE')
  AND NOT has_table_privilege('authenticated','public.agent_runs','DELETE'),
  'only the server writes agent run accounting and state');
SELECT public.ua25_test_assert(NOT has_column_privilege('authenticated','public.projects','contractor_id','UPDATE')
  AND NOT has_column_privilege('authenticated','public.projects','executor_id','INSERT,UPDATE')
  AND NOT has_column_privilege('authenticated','public.projects','status','INSERT,UPDATE')
  AND NOT has_column_privilege('authenticated','public.project_tasks','project_id','UPDATE')
  AND NOT has_column_privilege('authenticated','public.offerings','audience','INSERT,UPDATE')
  AND NOT has_column_privilege('authenticated','public.offerings','is_enabled','INSERT,UPDATE')
  AND NOT has_column_privilege('authenticated','public.learning_proposals','definition','UPDATE'),
  'column grants reserve identities, workflow, publication and generated definitions');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offerings
  WHERE slug IN ('cv-adaptado','entrevista','redaccion-profesional')
    AND owner_id IS NULL AND audience='general' AND visibility='draft' AND NOT is_enabled)=3,
  'seed supplies exactly three non-executable general agent proposals without duplicates');

INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('10000000-0000-4000-8000-000000000001','ua25-a@example.invalid','{}'),
 ('10000000-0000-4000-8000-000000000002','ua25-b@example.invalid','{}'),
 ('10000000-0000-4000-8000-000000000003','ua25-c@example.invalid','{"display_name":"Test C","is_public":true,"role":"admin"}'),
 ('10000000-0000-4000-8000-000000000004','ua25-d@example.invalid','{}');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.profiles WHERE id::text LIKE '10000000-%')=4,
  'auth creates all four profiles');
SELECT public.ua25_test_assert((SELECT display_name='Test C' AND NOT is_public FROM public.profiles WHERE id='10000000-0000-4000-8000-000000000003'),
  'untrusted Auth metadata can supply a label but cannot opt into public visibility');
UPDATE public.profiles SET display_name='Test A',is_public=true WHERE id='10000000-0000-4000-8000-000000000001';
UPDATE public.profiles SET display_name='Test B',is_public=true WHERE id='10000000-0000-4000-8000-000000000002';
UPDATE public.profiles SET display_name='Test C',is_public=false WHERE id='10000000-0000-4000-8000-000000000003';
DELETE FROM public.profiles WHERE id='10000000-0000-4000-8000-000000000004';

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000004';
INSERT INTO public.profiles(display_name,bio) VALUES ('Test D','Private by default');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.profiles WHERE id='10000000-0000-4000-8000-000000000004' AND NOT is_public)=1,
  'profile registration uses the authenticated identity and defaults private');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.profiles(id,display_name) VALUES ('10000000-0000-4000-8000-000000000005','Impostor')$sql$,
  '42501','cannot register another identity');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.profiles WHERE id='10000000-0000-4000-8000-000000000003')=0,
  'private third-party profiles are hidden');
UPDATE public.profiles SET display_name='Hijacked' WHERE id='10000000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT public.ua25_test_assert((SELECT display_name FROM public.profiles WHERE id='10000000-0000-4000-8000-000000000001')='Test A',
  'a zero-row update cannot hijack another profile');

INSERT INTO public.offerings(id,owner_id,slug,title,description,kind,audience,visibility,is_enabled) VALUES
 ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','ua25-test-draft','Draft A','Private offering','agent','specialized','draft',false),
 ('30000000-0000-4000-8000-000000000002',NULL,'ua25-test-general','General published','Server publication','multiagent','general','public',true),
 ('30000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003','ua25-test-hidden','Private C','Private offering','skill','specialized','private',false);
INSERT INTO public.offering_versions(offering_id,version,definition) VALUES
 ('30000000-0000-4000-8000-000000000001',1,'{"secret":"owner A"}'),
 ('30000000-0000-4000-8000-000000000002',1,'{"secret":"server configuration"}'),
 ('30000000-0000-4000-8000-000000000003',1,'{"secret":"owner C"}');

SET LOCAL ROLE anon;
SET LOCAL request.jwt.claim.sub='';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offerings WHERE id::text LIKE '30000000-%')=1,
  'anonymous catalog shows only the server-published offering');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offerings WHERE slug IN ('cv-adaptado','entrevista','redaccion-profesional'))=0,
  'the three proposed seed agents stay unpublished');
SELECT public.ua25_test_expect_error($sql$SELECT * FROM public.offering_versions$sql$,
  '42501','published catalog never exposes agent definitions');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.profiles WHERE id::text LIKE '10000000-%')=2,
  'only explicitly public profiles appear anonymously');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.offerings(owner_id,slug,title,description,kind) VALUES (NULL,'ua25-anon','Bad','Bad','agent')$sql$,
  '42501','anonymous catalog writes are denied');
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offerings WHERE id::text LIKE '30000000-%')=2,
  'offering owner sees own draft and the public catalog');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offering_versions)=1,
  'owner sees only own agent definitions');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.offerings(owner_id,slug,title,description,kind,audience,is_enabled) VALUES ('10000000-0000-4000-8000-000000000001','ua25-client-general','Bad','Bad','agent','general',true)$sql$,
  '42501','client cannot self-publish a general enabled agent');
SELECT public.ua25_test_expect_error($sql$UPDATE public.offerings SET owner_id='10000000-0000-4000-8000-000000000001' WHERE id='30000000-0000-4000-8000-000000000003'$sql$,
  '42501','client cannot steal ownership metadata');
SELECT public.ua25_test_expect_error($sql$UPDATE public.offerings SET is_enabled=true WHERE id='30000000-0000-4000-8000-000000000001'$sql$,
  '42501','client cannot enable execution');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.offering_versions(offering_id,version,definition) VALUES ('30000000-0000-4000-8000-000000000003',2,'{}')$sql$,
  '42501','client cannot inject another owner agent version');
INSERT INTO public.offerings(owner_id,slug,title,kind) VALUES
 ('10000000-0000-4000-8000-000000000001','ua25-client-service','Own service','service');
SELECT public.ua25_test_assert((SELECT audience='specialized' AND visibility='draft' AND NOT is_enabled FROM public.offerings WHERE slug='ua25-client-service'),
  'client can create their own specialized draft offering');
INSERT INTO public.offering_versions(offering_id,version,definition) VALUES
 ('30000000-0000-4000-8000-000000000001',2,'{"steps":["draft"]}');
SELECT public.ua25_test_assert((SELECT definition='{"steps":["draft"]}'::jsonb FROM public.offering_versions WHERE offering_id='30000000-0000-4000-8000-000000000001' AND version=2),
  'agent owner can append a private definition version');
SELECT public.ua25_test_expect_error($sql$UPDATE public.offering_versions SET definition='{"steps":["revised"]}' WHERE offering_id='30000000-0000-4000-8000-000000000001' AND version=2$sql$,
  '42501','published version history cannot be rewritten by a client');
SELECT public.ua25_test_expect_error($sql$UPDATE public.offering_versions SET offering_id='30000000-0000-4000-8000-000000000003' WHERE offering_id='30000000-0000-4000-8000-000000000001' AND version=2$sql$,
  '42501','agent definition cannot be moved to another offering');
RESET ROLE;
SELECT public.ua25_test_assert((SELECT owner_id FROM public.offerings WHERE id='30000000-0000-4000-8000-000000000003')='10000000-0000-4000-8000-000000000003',
  'private offering owner remains intact');

INSERT INTO public.projects(id,contractor_id,executor_id,title,description,status) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Active AB','Shared work','active'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Completed AB','Closed work','completed'),
 ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','Completed CB','Other closed work','completed');
INSERT INTO public.project_tasks(id,project_id,title,status) VALUES
 ('40000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Shared task','todo');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.projects(contractor_id,executor_id,title,status) VALUES ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Self hire','active')$sql$,
  '23514','a person cannot contract themselves');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.projects WHERE id::text LIKE '20000000-%')=2,
  'contractor sees their two projects only');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.project_tasks)=1,'contractor sees the shared task');
INSERT INTO public.projects(contractor_id,title,description) VALUES ('10000000-0000-4000-8000-000000000001','Client draft','Initial');
UPDATE public.projects SET title='Client draft edited',description='Editable brief' WHERE title='Client draft';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.projects WHERE title='Client draft edited' AND status='draft' AND executor_id IS NULL)=1,
  'client can create and edit an unassigned draft');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.projects(contractor_id,title) VALUES ('10000000-0000-4000-8000-000000000003','Impersonated project')$sql$,
  '42501','client cannot create another contractor project');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.projects(contractor_id,executor_id,title,status) VALUES ('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Forced assignment','active')$sql$,
  '42501','client cannot force assignment or workflow status');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET status='active',executor_id='10000000-0000-4000-8000-000000000002' WHERE title='Client draft edited'$sql$,
  '42501','client cannot activate or assign a draft');
SELECT public.ua25_test_expect_error($sql$UPDATE public.project_tasks SET project_id='20000000-0000-4000-8000-000000000003' WHERE id='40000000-0000-4000-8000-000000000001'$sql$,
  '42501','client cannot move tasks to another project');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.projects WHERE id::text LIKE '20000000-%')=3,
  'executor sees all three projects they participate in');
UPDATE public.project_tasks SET status='in_progress' WHERE id='40000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT status FROM public.project_tasks WHERE id='40000000-0000-4000-8000-000000000001')='in_progress',
  'executor can progress the shared task');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000003';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.projects WHERE id::text LIKE '20000000-%')=1,
  'third party C sees only their own separate project');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.project_tasks)=0,'third party cannot read AB tasks');
UPDATE public.project_tasks SET title='Hijacked' WHERE id='40000000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT public.ua25_test_assert((SELECT title FROM public.project_tasks WHERE id='40000000-0000-4000-8000-000000000001')='Shared task',
  'denied zero-row task update preserves the real task');

-- Reviews require a real completed engagement and are immutable to clients.
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','executor',4)$sql$,
  '42501','active work cannot yet be reviewed');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','contractor',4)$sql$,
  '42501','self-review is denied');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','contractor',4)$sql$,
  '42501','reviewed role must match the other engagement party');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','executor',0)$sql$,
  '23514','score below one is invalid');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','executor',6)$sql$,
  '23514','score above five is invalid');
INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score,comment) VALUES
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','executor',4,'Good execution');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','executor',5)$sql$,
  '23505','each reviewer submits only one review per engagement');
SELECT public.ua25_test_expect_error($sql$UPDATE public.reviews SET score=5 WHERE project_id='20000000-0000-4000-8000-000000000002'$sql$,
  '42501','client cannot edit a submitted review');
SELECT public.ua25_test_expect_error($sql$DELETE FROM public.reviews WHERE project_id='20000000-0000-4000-8000-000000000002'$sql$,
  '42501','client cannot erase a submitted review');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','contractor',5);
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000003';
INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score,comment) VALUES
 ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','executor',2,'Private third-party engagement');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.reviews(project_id,reviewer_id,reviewed_id,reviewed_role,score) VALUES ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000002','executor',5)$sql$,
  '42501','third party cannot review someone else engagement');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000004';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.reviews)=0,'outsider cannot read raw reviews');
SELECT public.ua25_test_assert((SELECT average_score=3 AND review_count=2 FROM public.get_reputation('10000000-0000-4000-8000-000000000002') WHERE reviewed_role='executor'),
  'public executor average includes private engagements beyond the caller visibility');
SELECT public.ua25_test_assert((SELECT average_score IS NULL AND review_count=0 FROM public.get_reputation('10000000-0000-4000-8000-000000000002') WHERE reviewed_role='contractor'),
  'unused contractor reputation has zero reviews and a NULL average');
SELECT public.ua25_test_assert((SELECT average_score=5 AND review_count=1 FROM public.get_reputation('10000000-0000-4000-8000-000000000001') WHERE reviewed_role='contractor'),
  'contractor reputation is independent of executor reputation');
SELECT public.ua25_test_expect_error($sql$SELECT * FROM public.get_reputation('10000000-0000-4000-8000-000000000003')$sql$,
  '42501','private profile reputation is hidden from outsiders');
RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL request.jwt.claim.sub='';
SELECT public.ua25_test_assert((SELECT average_score=3 AND review_count=2 FROM public.get_reputation('10000000-0000-4000-8000-000000000002') WHERE reviewed_role='executor'),
  'anonymous public reputation is complete and independent of caller identity');
SELECT public.ua25_test_expect_error($sql$SELECT * FROM public.reviews$sql$,
  '42501','anonymous reputation does not reveal raw reviews');
RESET ROLE;
SELECT public.ua25_test_assert((SELECT count(*) FROM public.reviews WHERE project_id='20000000-0000-4000-8000-000000000002')=2
  AND (SELECT score FROM public.reviews WHERE project_id='20000000-0000-4000-8000-000000000002' AND reviewed_role='executor')=4,
  'submitted reviews remain intact after denied mutations');
SET LOCAL ROLE service_role;
SELECT public.ua25_test_expect_error($sql$UPDATE public.offering_versions SET definition='{}' WHERE offering_id='30000000-0000-4000-8000-000000000001' AND version=1$sql$,
  '42501','server worker cannot rewrite immutable agent version history');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET status='active' WHERE id='20000000-0000-4000-8000-000000000002'$sql$,
  '23514','even server workflow cannot reopen a completed reviewed engagement');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET executor_id='10000000-0000-4000-8000-000000000004' WHERE id='20000000-0000-4000-8000-000000000002'$sql$,
  '23514','completed engagement parties cannot be replaced');
INSERT INTO public.agent_runs(owner_id,offering_id,status) VALUES
 ('10000000-0000-4000-8000-000000000004','30000000-0000-4000-8000-000000000002','queued');
UPDATE public.agent_runs SET status='running',input_tokens=10,cost_usd=0.0001
 WHERE owner_id='10000000-0000-4000-8000-000000000004';
SELECT public.ua25_test_assert((SELECT status='running' AND input_tokens=10 AND cost_usd=0.0001 FROM public.agent_runs WHERE owner_id='10000000-0000-4000-8000-000000000004'),
  'privileged server role can create and account for real agent runs');
SELECT public.ua25_test_expect_error($sql$UPDATE public.agent_runs SET cost_usd='NaN'::numeric WHERE owner_id='10000000-0000-4000-8000-000000000004'$sql$,
  '23514','server cannot persist a non-finite cost');
RESET ROLE;

INSERT INTO public.agent_runs(id,owner_id,offering_id,project_id,status,cost_usd,input_tokens,output_tokens) VALUES
 ('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001','succeeded',0.001,100,50);
INSERT INTO public.learning_proposals(id,owner_id,project_id,kind,explanation,definition) VALUES
 ('70000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','skill','A private candidate','{"steps":["private"]}');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.agent_runs)=1,'run owner can inspect their execution');
SELECT public.ua25_test_expect_error($sql$UPDATE public.agent_runs SET cost_usd=0,status='queued' WHERE id='50000000-0000-4000-8000-000000000001'$sql$,
  '42501','client cannot alter costs or run states');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.agent_runs(owner_id,offering_id,status) VALUES ('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002','succeeded')$sql$,
  '42501','client cannot fabricate an agent run');
INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','context',false);
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','context',true)$sql$,
  '42501','one member cannot consent on behalf of another');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES ('20000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','learning',true)$sql$,
  '42501','nonmember cannot create a project consent');
INSERT INTO public.self_evaluations(owner_id,project_id,notes) VALUES
 ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Private self assessment');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.self_evaluations)=1,'owner can read their self evaluation');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.self_evaluations(owner_id,notes) VALUES ('10000000-0000-4000-8000-000000000002','Impersonated assessment')$sql$,
  '42501','self evaluations cannot impersonate a different owner');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.self_evaluations(owner_id,project_id,notes) VALUES ('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000003','Unrelated project assessment')$sql$,
  '42501','self evaluation cannot attach to someone else project');
UPDATE public.learning_proposals SET decision='approved' WHERE id='70000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT decision FROM public.learning_proposals WHERE id='70000000-0000-4000-8000-000000000001')='approved',
  'proposal owner can explicitly approve a proposal');
SELECT public.ua25_test_expect_error($sql$UPDATE public.learning_proposals SET definition='{"steps":["injected"]}' WHERE id='70000000-0000-4000-8000-000000000001'$sql$,
  '42501','approving a proposal cannot rewrite its definition');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.learning_proposals(owner_id,kind,explanation,definition) VALUES ('10000000-0000-4000-8000-000000000001','agent','Fake server output','{}')$sql$,
  '42501','client cannot fabricate a learning proposal');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM public.agent_runs)=0,'project member cannot read another owner run accounting');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.self_evaluations)=0,'self evaluations stay private from project peers');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.learning_proposals)=0,'learning proposals stay private from project peers');
UPDATE public.learning_proposals SET decision='rejected' WHERE id='70000000-0000-4000-8000-000000000001';
UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000001' AND user_id='10000000-0000-4000-8000-000000000001';
RESET ROLE;
SELECT public.ua25_test_assert((SELECT decision='approved' AND definition='{"steps":["private"]}'::jsonb FROM public.learning_proposals WHERE id='70000000-0000-4000-8000-000000000001'),
  'outsider update does not alter the approved proposal or definition');
SELECT public.ua25_test_assert((SELECT NOT granted FROM public.project_consents WHERE project_id='20000000-0000-4000-8000-000000000001' AND user_id='10000000-0000-4000-8000-000000000001' AND purpose='context'),
  'denied zero-row update cannot grant another member consent');
SELECT public.ua25_test_assert((SELECT count(*) FROM public.offerings WHERE id::text LIKE '30000000-%')=3
  AND (SELECT count(*) FROM public.offerings WHERE id='30000000-0000-4000-8000-000000000001' AND NOT is_enabled AND visibility='draft')=1,
  'proposal approval does not activate execution or publish an offering');

-- Private Storage reads require both project membership and uploader consent.
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.buckets WHERE id IN ('account-files','project-files') AND NOT public)=2,
  'both managed file buckets are private');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES
 ('account-files','10000000-0000-4000-8000-000000000001/cv.pdf','10000000-0000-4000-8000-000000000001'),
 ('project-files','20000000-0000-4000-8000-000000000001/brief.pdf','10000000-0000-4000-8000-000000000001');
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects)=2,'uploader reads own account and project files without sharing');
SELECT public.ua25_test_expect_error($sql$INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('account-files','10000000-0000-4000-8000-000000000002/stolen.pdf','10000000-0000-4000-8000-000000000001')$sql$,
  '42501','account file path cannot claim another identity');
SELECT public.ua25_test_expect_error($sql$INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('account-files','10000000-0000-4000-8000-000000000001/forged.pdf','10000000-0000-4000-8000-000000000002')$sql$,
  '42501','file owner cannot be forged');
SELECT public.ua25_test_expect_error($sql$INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('project-files','20000000-0000-4000-8000-000000000003/outsider.pdf','10000000-0000-4000-8000-000000000001')$sql$,
  '42501','valid uploader path does not bypass project membership');
SELECT public.ua25_test_expect_error($sql$UPDATE storage.objects SET owner_id='10000000-0000-4000-8000-000000000002' WHERE bucket_id='project-files'$sql$,
  '42501','an existing file cannot be reassigned to a forged owner');
SELECT public.ua25_test_expect_error($sql$UPDATE storage.objects SET name='10000000-0000-4000-8000-000000000002/renamed.pdf' WHERE bucket_id='account-files'$sql$,
  '42501','an existing file cannot be moved to someone else account path');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects)=0,'project membership alone does not expose another uploader files');
SELECT public.ua25_test_expect_error($sql$INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES ('project-files','20000000-0000-4000-8000-000000000001/forged.pdf','10000000-0000-4000-8000-000000000001')$sql$,
  '42501','peer cannot claim another member as uploader');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000001' AND purpose='context';
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE bucket_id='project-files')=1,
  'member can read project context only after the uploader consent');
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE bucket_id='account-files')=0,
  'project consent never exposes account files');
INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES
 ('project-files','20000000-0000-4000-8000-000000000001/own-delete.txt','10000000-0000-4000-8000-000000000002');
SELECT public.ua25_test_expect_error($sql$DELETE FROM storage.objects WHERE bucket_id='project-files'$sql$,
  '42501','direct Storage metadata deletion is blocked outside the API context');
-- Match Supabase's own test helper, only for rolled-back metadata fixtures.
-- RLS and triggers remain enabled; no real object bytes are created/deleted.
-- https://github.com/supabase/storage/blob/master/src/test/utils/storage.ts
SET LOCAL storage.allow_delete_query='true';
DELETE FROM storage.objects WHERE bucket_id='project-files';
SET LOCAL storage.allow_delete_query='false';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE name='20000000-0000-4000-8000-000000000001/own-delete.txt')=0,
  'Storage API context allows deleting the caller own metadata');
RESET ROLE;
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE bucket_id='project-files')=1,
  'read permission does not let a peer delete an uploader file');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000004';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects)=0,'uploader consent cannot grant a third party access');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
UPDATE public.project_consents SET granted=false WHERE project_id='20000000-0000-4000-8000-000000000001' AND purpose='context';
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects)=0,'revoking uploader consent immediately blocks peer file reads');
RESET ROLE;
SET LOCAL ROLE anon;
SET LOCAL request.jwt.claim.sub='';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects)=0,'anonymous clients cannot read private files');
RESET ROLE;

-- Draft reassignment revokes prior consent; active/terminal parties are stable.
INSERT INTO public.projects(id,contractor_id,executor_id,title,status) VALUES
 ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Draft reassignment','draft'),
 ('20000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','Cancelled engagement','cancelled');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES
 ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','context',false);
SELECT public.ua25_test_expect_error($sql$UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context'$sql$,
  '42501','a member cannot grant draft consent through an update');
SELECT public.ua25_test_expect_error($sql$INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','learning',true)$sql$,
  '42501','a member cannot grant draft consent through an insert');
SELECT public.ua25_test_assert((SELECT NOT granted FROM public.project_consents WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context'),
  'draft consent remains ungranted after both denied paths');
RESET ROLE;
-- Privileged legacy data must not enable sharing during a mutable draft.
UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context';
INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES
 ('20000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002','learning',true);
INSERT INTO storage.objects(bucket_id,name,owner_id) VALUES
 ('project-files','20000000-0000-4000-8000-000000000004/draft.pdf','10000000-0000-4000-8000-000000000001');
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE name='20000000-0000-4000-8000-000000000004/draft.pdf')=0,
  'draft peers cannot read a file even with privileged granted consent');
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE name='20000000-0000-4000-8000-000000000004/draft.pdf')=1,
  'draft uploader can still read their own private file');
UPDATE public.project_consents SET granted=false WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context';
SELECT public.ua25_test_assert((SELECT NOT granted FROM public.project_consents WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context'),
  'a member can always revoke their own draft consent');
RESET ROLE;
UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context';
SET LOCAL ROLE service_role;
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET executor_id='10000000-0000-4000-8000-000000000004' WHERE id='20000000-0000-4000-8000-000000000001'$sql$,
  '23514','active engagement parties cannot be silently replaced');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET status='draft' WHERE id='20000000-0000-4000-8000-000000000001'$sql$,
  '23514','active engagement cannot return to a mutable draft');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET status='active' WHERE id='20000000-0000-4000-8000-000000000005'$sql$,
  '23514','cancelled engagement cannot reopen');
SELECT public.ua25_test_expect_error($sql$UPDATE public.projects SET executor_id='10000000-0000-4000-8000-000000000004' WHERE id='20000000-0000-4000-8000-000000000005'$sql$,
  '23514','cancelled engagement parties cannot be replaced');
UPDATE public.projects SET contractor_id='10000000-0000-4000-8000-000000000003' WHERE id='20000000-0000-4000-8000-000000000004';
RESET ROLE;
SELECT public.ua25_test_assert((SELECT count(*) FROM public.project_consents WHERE project_id='20000000-0000-4000-8000-000000000004' AND granted)=0,
  'draft reassignment revokes context and learning consents of all prior parties');
-- Simulate stale privileged data to independently check the Storage guard.
UPDATE public.project_consents SET granted=true WHERE project_id='20000000-0000-4000-8000-000000000004' AND purpose='context';
SET LOCAL ROLE service_role;
UPDATE public.projects SET status='active' WHERE id='20000000-0000-4000-8000-000000000004';
RESET ROLE;
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
SELECT public.ua25_test_assert((SELECT count(*) FROM storage.objects WHERE name='20000000-0000-4000-8000-000000000004/draft.pdf')=0,
  'after activation even a stale consent cannot share a departed uploader file');
INSERT INTO public.project_consents(project_id,user_id,purpose,granted) VALUES
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','learning',true),
 ('20000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000002','context',true);
SELECT public.ua25_test_assert((SELECT count(*) FROM public.project_consents
  WHERE project_id IN ('20000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000005')
    AND user_id='10000000-0000-4000-8000-000000000002' AND granted)=2,
  'members can explicitly grant consent after completed or cancelled parties freeze');
RESET ROLE;

SELECT count(*)::integer AS assertions_passed FROM database_test_results;
ROLLBACK;
