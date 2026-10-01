-- Caps the write-ahead log. It lives on the same volume as the data, and the Postgres default
-- (max_wal_size = 1GB) is larger than a small volume.
-- Applied by reload, no restart. Undo: ALTER SYSTEM RESET max_wal_size; ALTER SYSTEM RESET min_wal_size;
-- then SELECT pg_reload_conf();
-- Run with psql (scripts/db-guard.sh tune-wal): it sends one statement at a time, which
-- ALTER SYSTEM requires.
ALTER SYSTEM SET max_wal_size = '64MB';
ALTER SYSTEM SET min_wal_size = '32MB';
SELECT pg_reload_conf();
SELECT jsonb_agg(jsonb_build_object('name', name, 'setting', setting, 'applied', applied))
FROM pg_file_settings WHERE name LIKE '%wal_size';
