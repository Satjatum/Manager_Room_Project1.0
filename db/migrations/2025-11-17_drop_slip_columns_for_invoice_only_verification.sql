-- Drop slip-level fields to use invoice-level verification only

-- 1) Drop indexes/triggers/functions that depend on slip_status
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_indexes WHERE schemaname='public' AND indexname='idx_payment_slips_status'
  ) THEN
    DROP INDEX public.idx_payment_slips_status;
  END IF;
EXCEPTION WHEN undefined_table THEN
  NULL;
END $$;

-- Drop triggers that referenced slip_status (from previous migration)
DO $$
BEGIN
  PERFORM 1 FROM pg_trigger WHERE tgname = 'payment_slips_require_payment';
  IF FOUND THEN
    DROP TRIGGER payment_slips_require_payment ON public.payment_slips;
  END IF;
  PERFORM 1 FROM pg_trigger WHERE tgname = 'payment_slips_mark_duplicates';
  IF FOUND THEN
    DROP TRIGGER payment_slips_mark_duplicates ON public.payment_slips;
  END IF;
  PERFORM 1 FROM pg_trigger WHERE tgname = 'payment_slips_auto_duplicate_on_paid';
  IF FOUND THEN
    DROP TRIGGER payment_slips_auto_duplicate_on_paid ON public.payment_slips;
  END IF;
EXCEPTION WHEN undefined_table THEN
  NULL;
END $$;

-- Drop helper trigger functions if exist
DO $$
BEGIN
  PERFORM 1 FROM pg_proc WHERE proname = 'tg_payment_slips_require_payment';
  IF FOUND THEN
    DROP FUNCTION public.tg_payment_slips_require_payment();
  END IF;
  PERFORM 1 FROM pg_proc WHERE proname = 'tg_payment_slips_mark_duplicates';
  IF FOUND THEN
    DROP FUNCTION public.tg_payment_slips_mark_duplicates();
  END IF;
  PERFORM 1 FROM pg_proc WHERE proname = 'tg_payment_slips_auto_duplicate_on_paid';
  IF FOUND THEN
    DROP FUNCTION public.tg_payment_slips_auto_duplicate_on_paid();
  END IF;
END $$;

-- 2) Drop slip-level columns
ALTER TABLE public.payment_slips
  DROP COLUMN IF EXISTS transfer_from_bank,
  DROP COLUMN IF EXISTS transfer_from_account,
  DROP COLUMN IF EXISTS transfer_to_account,
  DROP COLUMN IF EXISTS ocr_data,
  DROP COLUMN IF EXISTS slip_status;

-- Note: We keep verified_by, verified_at, admin_notes, rejection_reason, payment_id for auditing.
