-- TEST ONLY: never apply this file to a Supabase project. The runner uses an
-- isolated PostgreSQL engine; managed Auth/Storage APIs are not emulated here.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
GRANT anon, authenticated, service_role TO postgres;
CREATE SCHEMA auth;
CREATE TABLE auth.users (
  id uuid PRIMARY KEY,
  email text,
  raw_user_meta_data jsonb DEFAULT '{}'::jsonb
);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;
GRANT USAGE ON SCHEMA auth TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION auth.uid() TO anon, authenticated, service_role;
CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types text[]
);
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text REFERENCES storage.buckets(id),
  name text NOT NULL,
  owner_id text,
  metadata jsonb,
  created_at timestamptz DEFAULT now(),
  UNIQUE (bucket_id, name)
);
CREATE FUNCTION storage.foldername(path text) RETURNS text[] LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN array_length(parts, 1) > 1
    THEN parts[1:array_length(parts, 1)-1] ELSE ARRAY[]::text[] END
  FROM (SELECT string_to_array(path, '/') AS parts) AS split
$$;
-- Mirror Storage's statement guard so local tests must opt into its API deletion
-- context too. This does not emulate deleting the actual object bytes.
-- https://github.com/supabase/storage/blob/master/migrations/tenant/0055-prevent-direct-deletes.sql
CREATE FUNCTION storage.protect_delete() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('storage.allow_delete_query', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'Storage metadata deletion requires its API context' USING ERRCODE='42501';
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER protect_objects_delete BEFORE DELETE ON storage.objects
  FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();
CREATE TRIGGER protect_buckets_delete BEFORE DELETE ON storage.buckets
  FOR EACH STATEMENT EXECUTE FUNCTION storage.protect_delete();
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon, authenticated, service_role;
GRANT ALL ON storage.buckets, storage.objects TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO anon;
GRANT EXECUTE ON FUNCTION storage.foldername(text) TO anon, authenticated, service_role;
