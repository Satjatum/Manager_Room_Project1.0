-- Enable many payment_slips per invoice_id (idempotent, safe)
-- Also ensure referential integrity and performance

-- 1) Ensure FK from payment_slips.invoice_id -> invoices.invoice_id
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'payment_slips_invoice_id_fkey'
  ) THEN
    ALTER TABLE public.payment_slips
      ADD CONSTRAINT payment_slips_invoice_id_fkey
      FOREIGN KEY (invoice_id)
      REFERENCES public.invoices (invoice_id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- 2) Ensure there is NO unique constraint on payment_slips.invoice_id (allow many slips per invoice)
-- (No-op if none exists.) Attempt to drop common unique index names safely.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='uniq_payment_slips_invoice_id'
  ) THEN
    EXECUTE 'DROP INDEX public.uniq_payment_slips_invoice_id';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='payment_slips_invoice_id_key'
  ) THEN
    EXECUTE 'DROP INDEX public.payment_slips_invoice_id_key';
  END IF;
END $$;

-- 3) Helpful composite index for listing slips by invoice/date
CREATE INDEX IF NOT EXISTS idx_payment_slips_invoice_created
  ON public.payment_slips (invoice_id, created_at DESC);

-- 4) Auto-update updated_at on row modification (upsert, edit, verify, reject)
CREATE OR REPLACE FUNCTION public.tg_set_timestamp()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS set_timestamp_on_payment_slips ON public.payment_slips;
CREATE TRIGGER set_timestamp_on_payment_slips
BEFORE UPDATE ON public.payment_slips
FOR EACH ROW EXECUTE FUNCTION public.tg_set_timestamp();

-- 5) Safety: ensure removed columns do not exist (slip_status, transfer_*, ocr_data)
ALTER TABLE public.payment_slips
  DROP COLUMN IF EXISTS slip_status,
  DROP COLUMN IF EXISTS transfer_from_bank,
  DROP COLUMN IF EXISTS transfer_from_account,
  DROP COLUMN IF EXISTS transfer_to_account,
  DROP COLUMN IF EXISTS ocr_data;
