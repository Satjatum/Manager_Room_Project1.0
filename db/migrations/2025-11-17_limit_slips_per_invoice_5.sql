-- Limit to at most 5 payment_slips per invoice_id (idempotent)

CREATE OR REPLACE FUNCTION public.tg_limit_slips_per_invoice()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_count integer;
BEGIN
  -- Serialize concurrent inserts/updates per invoice using row lock on invoices
  PERFORM 1 FROM public.invoices WHERE invoice_id = NEW.invoice_id FOR UPDATE;

  IF TG_OP = 'INSERT' THEN
    SELECT COUNT(*) INTO v_count FROM public.payment_slips WHERE invoice_id = NEW.invoice_id;
    IF v_count >= 5 THEN
      RAISE EXCEPTION 'ERR_MAX_5_SLIPS: invoice % already has % slips', NEW.invoice_id, v_count
        USING ERRCODE = '23514'; -- check_violation
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.invoice_id IS DISTINCT FROM OLD.invoice_id THEN
      SELECT COUNT(*) INTO v_count FROM public.payment_slips WHERE invoice_id = NEW.invoice_id;
      IF v_count >= 5 THEN
        RAISE EXCEPTION 'ERR_MAX_5_SLIPS: invoice % already has % slips', NEW.invoice_id, v_count
          USING ERRCODE = '23514'; -- check_violation
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS limit_slips_per_invoice ON public.payment_slips;
CREATE TRIGGER limit_slips_per_invoice
BEFORE INSERT OR UPDATE ON public.payment_slips
FOR EACH ROW EXECUTE FUNCTION public.tg_limit_slips_per_invoice();
