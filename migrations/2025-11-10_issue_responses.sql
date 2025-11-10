-- Issue responses minimal schema
-- Run on Supabase/Postgres

create table if not exists public.issue_responses (
  response_id uuid primary key default gen_random_uuid(),
  issue_id uuid not null references public.issue_reports(issue_id) on delete cascade,
  response_text text,
  created_by uuid not null references public.users(user_id) on delete restrict,
  created_at timestamptz not null default now()
);

create index if not exists idx_issue_responses_issue_id on public.issue_responses(issue_id);
create index if not exists idx_issue_responses_created_at on public.issue_responses(created_at desc);

create table if not exists public.issue_response_images (
  id uuid primary key default gen_random_uuid(),
  response_id uuid not null references public.issue_responses(response_id) on delete cascade,
  image_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_issue_response_images_response_id on public.issue_response_images(response_id);
create index if not exists idx_issue_response_images_created_at on public.issue_response_images(created_at desc);
