-- ============================================================
-- Migration 004: Sync, Audit & Analytics
-- Sync Metadata, Audit Logs, Grade Change Triggers
-- ============================================================

-- ============================================================
-- 1. SYNC_METADATA - Device sync telemetry for heatmaps
-- ============================================================
CREATE TABLE public.sync_metadata (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    device_id       TEXT,
    device_info     JSONB,                                 -- OS version, app version, etc.
    current_strand  public.als_strand,
    approx_lat      DECIMAL(10,7),                         -- Approximate GPS latitude
    approx_lng      DECIMAL(10,7),                         -- Approximate GPS longitude
    records_pushed  INTEGER NOT NULL DEFAULT 0,
    records_pulled  INTEGER NOT NULL DEFAULT 0,
    sync_duration_ms INTEGER,
    schema_version  INTEGER NOT NULL DEFAULT 1,            -- Client schema version for migration check
    last_sync_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.sync_metadata IS 'Device sync telemetry for connectivity heatmaps and schema version tracking';

-- Index for heatmap queries (location-based aggregation)
CREATE INDEX idx_sync_metadata_location ON public.sync_metadata (approx_lat, approx_lng);
CREATE INDEX idx_sync_metadata_user ON public.sync_metadata (user_id, last_sync_at DESC);

-- ============================================================
-- 2. AUDIT_LOGS - Immutable write log
-- ============================================================
CREATE TABLE public.audit_logs (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    actor_id        UUID REFERENCES public.profiles(id),
    action          TEXT NOT NULL,                          -- 'INSERT', 'UPDATE', 'DELETE'
    table_name      TEXT NOT NULL,
    record_id       UUID,                                  -- The affected row's ID
    old_data        JSONB,                                 -- Previous state (for UPDATE/DELETE)
    new_data        JSONB,                                 -- New state (for INSERT/UPDATE)
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Audit logs are INSERT-ONLY. No updates or deletes allowed.
COMMENT ON TABLE public.audit_logs IS 'Immutable audit trail for all sensitive data changes - INSERT only';

-- Index for querying audits by actor and table
CREATE INDEX idx_audit_logs_actor ON public.audit_logs (actor_id, created_at DESC);
CREATE INDEX idx_audit_logs_table ON public.audit_logs (table_name, created_at DESC);
CREATE INDEX idx_audit_logs_record ON public.audit_logs (record_id);

-- ============================================================
-- 3. GRADE CHANGE AUDIT TRIGGER
-- Automatically logs every score/grade modification
-- ============================================================
CREATE OR REPLACE FUNCTION public.audit_grade_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO public.audit_logs (
            actor_id, action, table_name, record_id, old_data, new_data, ip_address
        ) VALUES (
            auth.uid(),
            'UPDATE',
            TG_TABLE_NAME,
            NEW.id,
            to_jsonb(OLD),
            to_jsonb(NEW),
            inet_client_addr()
        );
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_logs (
            actor_id, action, table_name, record_id, new_data, ip_address
        ) VALUES (
            auth.uid(),
            'INSERT',
            TG_TABLE_NAME,
            NEW.id,
            to_jsonb(NEW),
            inet_client_addr()
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_logs (
            actor_id, action, table_name, record_id, old_data, ip_address
        ) VALUES (
            auth.uid(),
            'DELETE',
            TG_TABLE_NAME,
            OLD.id,
            to_jsonb(OLD),
            inet_client_addr()
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Apply audit triggers to sensitive tables
CREATE TRIGGER audit_scores_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.scores
    FOR EACH ROW EXECUTE FUNCTION public.audit_grade_changes();

CREATE TRIGGER audit_submissions_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.submissions
    FOR EACH ROW EXECUTE FUNCTION public.audit_grade_changes();

CREATE TRIGGER audit_module_progress_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.module_progress
    FOR EACH ROW EXECUTE FUNCTION public.audit_grade_changes();

CREATE TRIGGER audit_attendance_changes
    AFTER INSERT OR UPDATE OR DELETE ON public.attendance
    FOR EACH ROW EXECUTE FUNCTION public.audit_grade_changes();

CREATE TRIGGER audit_profiles_changes
    AFTER UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.audit_grade_changes();

-- ============================================================
-- 4. PREVENT AUDIT LOG TAMPERING
-- Block UPDATE and DELETE on audit_logs
-- ============================================================
CREATE OR REPLACE FUNCTION public.prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Audit logs are immutable. UPDATE and DELETE operations are not permitted.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_audit_logs_update
    BEFORE UPDATE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_modification();

CREATE TRIGGER prevent_audit_logs_delete
    BEFORE DELETE ON public.audit_logs
    FOR EACH ROW EXECUTE FUNCTION public.prevent_audit_modification();
