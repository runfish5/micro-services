-- One check. Called by service/guard-loop.sh with the psql variable cfg (a JSON object).
-- Two things are added to the config here, so nobody has to maintain them by hand:
--   allowances  the rows of guard.allowance that have not ended (scripts/db-guard.sh allow)
--   protected   every workflow with an Error Trigger: the error handler is never switched off
SELECT guard.tick(
  c.cfg
  || jsonb_build_object('allowances', coalesce(c.cfg -> 'allowances', '[]'::jsonb) || (
       SELECT coalesce(jsonb_agg(jsonb_build_object(
                'workflow_id', a.workflow_id, 'mb', a.mb, 'from', a.starts, 'until', a.until)), '[]'::jsonb)
       FROM guard.allowance a WHERE a.until > now()))
  || jsonb_build_object('protected', coalesce(c.cfg -> 'protected', '[]'::jsonb) || (
       SELECT coalesce(jsonb_agg(w.id), '[]'::jsonb)
       FROM workflow_entity w WHERE w.nodes::text LIKE '%n8n-nodes-base.errorTrigger%'))
)
FROM (SELECT :'cfg'::jsonb AS cfg) c;
