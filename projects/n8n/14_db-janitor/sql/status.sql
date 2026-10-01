-- What the guard saw at its last check, and the allowances that have not ended.
SELECT guard.status() || jsonb_build_object('allowances', (
  SELECT coalesce(jsonb_agg(jsonb_build_object('workflow_id', a.workflow_id, 'mb', a.mb,
                                               'from', a.starts, 'until', a.until)), '[]'::jsonb)
  FROM guard.allowance a WHERE a.until > now()));
