-- Enables Supabase Realtime (postgres_changes) on sos_events so the Admin
-- Dashboard's live SOS monitor (apps/admin-dashboard/components/SosMonitor.tsx)
-- gets pushed new events and status changes without polling. RLS still
-- applies to Realtime subscriptions — an operator only receives rows
-- their own sos_events_select policy would let them read.
alter publication supabase_realtime add table sos_events;
