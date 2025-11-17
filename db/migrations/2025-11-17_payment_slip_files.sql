-- Files table for multiple attachments per payment_slip
-- Idempotent and safe for Supabase/Postgres

CREATE TABLE IF NOT EXISTS public.payment_slip_files (
  slip_file_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slip_id uuid NOT NULL,
  file_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- FK to payment_slips (cascade delete when slip removed)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payment_slip_files_slip_id_fkey'
  ) THEN
    ALTER TABLE public.payment_slip_files
      ADD CONSTRAINT payment_slip_files_slip_id_fkey
      FOREIGN KEY (slip_id)
      REFERENCES public.payment_slips (slip_id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Helpful indexes
CREATE INDEX IF NOT EXISTS idx_payment_slip_files_slip
  ON public.payment_slip_files (slip_id);
-- (no order/primary constraints as requested)

-- Timestamp trigger (reuse or define)
CREATE OR REPLACE FUNCTION public.tg_set_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS set_timestamp_on_payment_slip_files ON public.payment_slip_files;
CREATE TRIGGER set_timestamp_on_payment_slip_files
BEFORE UPDATE ON public.payment_slip_files
FOR EACH ROW EXECUTE FUNCTION public.tg_set_timestamp();
