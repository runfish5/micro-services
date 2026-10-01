-- Read-only. Facts about the Postgres server that the growth guard relies on.
-- Makes no assumption about the table or column names of n8n itself.
-- Needs a superuser or a member of pg_monitor (pg_ls_waldir, pg_file_settings).
SELECT jsonb_build_object(
  'role', (
    SELECT jsonb_build_object(
      'user', current_user,
      'superuser', r.rolsuper,
      'pg_monitor', pg_has_role(current_user, 'pg_monitor', 'member'),
      'database', current_database(),
      'timezone', current_setting('TimeZone'),
      'version', version(),
      'now', now())
    FROM pg_roles r WHERE r.rolname = current_user),
  -- What Postgres itself can see of the volume. Compare with the volume figure of the host, taken
  -- at the same moment: the difference is filesystem overhead, logs and temp files.
  'sizes', jsonb_build_object(
    'all_databases_bytes', (SELECT sum(pg_database_size(oid)) FROM pg_database),
    'wal_bytes', (SELECT coalesce(sum(size), 0) FROM pg_ls_waldir()),
    'wal_files', (SELECT count(*) FROM pg_ls_waldir())),
  'databases', (SELECT jsonb_object_agg(datname, pg_database_size(oid)) FROM pg_database),
  'settings', (
    SELECT jsonb_object_agg(name, concat_ws(' ', setting, unit, '[' || source || ']'))
    FROM pg_settings
    WHERE name IN ('max_wal_size', 'min_wal_size', 'wal_keep_size', 'max_slot_wal_keep_size',
                   'wal_level', 'archive_mode', 'checkpoint_timeout', 'wal_compression',
                   'logging_collector', 'log_directory', 'autovacuum', 'max_connections',
                   'shared_buffers', 'statement_timeout', 'temp_file_limit', 'data_directory')),
  'file_settings', (
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'name', name, 'setting', setting, 'file', sourcefile, 'applied', applied)), '[]'::jsonb)
    FROM pg_file_settings WHERE name LIKE '%wal_size'),
  'replication_slots', (SELECT count(*) FROM pg_replication_slots),
  'wal_stats', (SELECT jsonb_build_object('wal_bytes', wal_bytes, 'stats_reset', stats_reset) FROM pg_stat_wal),
  'temp_files', (
    SELECT jsonb_build_object('files', temp_files, 'bytes', temp_bytes)
    FROM pg_stat_database WHERE datname = current_database()),
  'tables', (
    SELECT jsonb_agg(t ORDER BY t.total_bytes DESC)
    FROM (
      SELECT n.nspname AS schema, c.relname AS name,
             pg_total_relation_size(c.oid) AS total_bytes,
             pg_relation_size(c.oid) AS heap_bytes,
             s.n_live_tup AS live_rows, s.n_dead_tup AS dead_rows,
             s.last_autovacuum
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_stat_user_tables s ON s.relid = c.oid
      WHERE c.relkind = 'r'
        AND n.nspname NOT IN ('pg_catalog', 'information_schema')
        AND pg_total_relation_size(c.oid) > 65536) t),
  'columns', (
    SELECT jsonb_object_agg(table_name, cols)
    FROM (
      SELECT table_name, jsonb_agg(column_name || ':' || data_type ORDER BY ordinal_position) AS cols
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name IN ('execution_entity', 'execution_data', 'binary_data',
                           'workflow_entity', 'execution_annotations')
      GROUP BY table_name) c),
  'indexes', (
    SELECT jsonb_agg(indexdef)
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND tablename IN ('execution_entity', 'execution_data', 'binary_data')),
  'guard_schema_exists', to_regnamespace('guard') IS NOT NULL
) AS facts;
