-- Multi-slip support and status consistency for payment verification
-- Safe migration for Supabase/Postgres

-- 1) Relationship: payment_slips -> invoices (for PostgREST joins and referential integrity)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'payment_slips_invoice_id_fkey'
  ) THEN
    ALTER TABLE public.payment_slips
      ADD CONSTRAINT payment_slips_invoice_id_fkey
      FOREIGN KEY (invoice_id)
      REFERENCES public.invoices (invoice_id)
      ON DELETE CASCADE;
  END IF;
END $$;

-- Helpful indexes (idempotent)
CREATE INDEX IF NOT EXISTS idx_payment_slips_invoice
  ON public.payment_slips (invoice_id);
CREATE INDEX IF NOT EXISTS idx_payment_slips_status
  ON public.payment_slips (slip_status);
CREATE INDEX IF NOT EXISTS idx_payment_slips_created
  ON public.payment_slips (created_at);

-- 2) Recalculate invoice status from payments
CREATE OR REPLACE FUNCTION public.recalc_invoice_payment_status(p_invoice_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total numeric;
  v_paid  numeric;
  v_due   date;
BEGIN
  SELECT total_amount, due_date
    INTO v_total, v_due
  FROM public.invoices
  WHERE invoice_id = p_invoice_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(payment_amount), 0)
    INTO v_paid
  FROM public.payments
  WHERE invoice_id = p_invoice_id
    AND payment_status = 'verified';

  UPDATE public.invoices
     SET paid_amount   = v_paid,
         invoice_status = CASE
           WHEN v_paid >= v_total THEN 'paid'
           WHEN v_paid > 0        THEN 'partial'
           WHEN CURRENT_DATE > v_due THEN 'overdue'
           ELSE 'pending'
         END,
         paid_date = CASE WHEN v_paid >= v_total THEN CURRENT_DATE ELSE NULL END,
         updated_at = now()
   WHERE invoice_id = p_invoice_id;
END $$;

-- 3) Keep invoices in sync whenever payments change
CREATE OR REPLACE FUNCTION public.tg_payments_recalc_invoice()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    PERFORM public.recalc_invoice_payment_status(NEW.invoice_id);
    IF TG_OP = 'UPDATE' AND NEW.invoice_id IS DISTINCT FROM OLD.invoice_id THEN
      PERFORM public.recalc_invoice_payment_status(OLD.invoice_id);
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    PERFORM public.recalc_invoice_payment_status(OLD.invoice_id);
  END IF;
  RETURN NULL;
END $$;

DROP TRIGGER IF EXISTS payments_recalc_invoice ON public.payments;
CREATE TRIGGER payments_recalc_invoice
AFTER INSERT OR UPDATE OR DELETE ON public.payments
FOR EACH ROW EXECUTE FUNCTION public.tg_payments_recalc_invoice();

-- 4) Guard rails for slips: verified must link to a payment
CREATE OR REPLACE FUNCTION public.tg_payment_slips_require_payment()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  -- Block verifying a slip for an already paid invoice
  IF NEW.slip_status = 'verified' THEN
    SELECT invoice_status INTO v_status
      FROM public.invoices WHERE invoice_id = NEW.invoice_id;
    IF v_status = 'paid' THEN
      RAISE EXCEPTION 'Cannot verify slip for an already paid invoice (%).', NEW.invoice_id;
    END IF;
  END IF;

  IF NEW.slip_status = 'verified' AND NEW.payment_id IS NULL THEN
    RAISE EXCEPTION 'Verified slip must have payment_id linked.';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS payment_slips_require_payment ON public.payment_slips;
CREATE TRIGGER payment_slips_require_payment
BEFORE INSERT OR UPDATE ON public.payment_slips
FOR EACH ROW EXECUTE FUNCTION public.tg_payment_slips_require_payment();

-- 5) When a slip is verified, mark other pending slips for the same invoice as duplicate
CREATE OR REPLACE FUNCTION public.tg_payment_slips_mark_duplicates()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.slip_status = 'verified' THEN
    UPDATE public.payment_slips
       SET slip_status = 'duplicate',
           updated_at  = now()
     WHERE invoice_id = NEW.invoice_id
       AND slip_id <> NEW.slip_id
       AND slip_status = 'pending';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS payment_slips_mark_duplicates ON public.payment_slips;
CREATE TRIGGER payment_slips_mark_duplicates
AFTER INSERT OR UPDATE OF slip_status ON public.payment_slips
FOR EACH ROW EXECUTE FUNCTION public.tg_payment_slips_mark_duplicates();

-- 6) If invoice is already fully paid, any new slip becomes duplicate automatically
CREATE OR REPLACE FUNCTION public.tg_payment_slips_auto_duplicate_on_paid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT invoice_status INTO v_status FROM public.invoices WHERE invoice_id = NEW.invoice_id;
  IF v_status = 'paid' THEN
    NEW.slip_status := 'duplicate';
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS payment_slips_auto_duplicate_on_paid ON public.payment_slips;
CREATE TRIGGER payment_slips_auto_duplicate_on_paid
BEFORE INSERT ON public.payment_slips
FOR EACH ROW EXECUTE FUNCTION public.tg_payment_slips_auto_duplicate_on_paid();
