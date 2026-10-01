-- Minimal copy of the n8n 2.x tables the guard reads (names and types as n8n creates them).
-- Test fixture only: it DROPS these tables. Used by guard.test.mjs against a throwaway database.
DROP TABLE IF EXISTS execution_data, execution_entity, binary_data, workflow_entity CASCADE;
CREATE TABLE workflow_entity (
  id varchar(36) PRIMARY KEY,
  name varchar(128) NOT NULL,
  active boolean NOT NULL DEFAULT false,
  nodes json NOT NULL DEFAULT '[]',
  connections json NOT NULL DEFAULT '{}',
  settings json,
  "staticData" json,
  "versionId" char(36),
  "activeVersionId" varchar(36),
  "triggerCount" integer NOT NULL DEFAULT 0,
  "isArchived" boolean NOT NULL DEFAULT false,
  "createdAt" timestamptz(3) NOT NULL DEFAULT now(),
  "updatedAt" timestamptz(3) NOT NULL DEFAULT now()
);
CREATE TABLE execution_entity (
  id serial PRIMARY KEY,
  finished boolean NOT NULL DEFAULT false,
  mode varchar NOT NULL,
  "retryOf" varchar,
  "retrySuccessId" varchar,
  "startedAt" timestamptz(3),
  "stoppedAt" timestamptz(3),
  "waitTill" timestamptz(3),
  status varchar NOT NULL,
  "workflowId" varchar(36) NOT NULL,
  "deletedAt" timestamptz(3),
  "createdAt" timestamptz(3) NOT NULL DEFAULT now()
);
CREATE TABLE execution_data (
  "executionId" integer PRIMARY KEY REFERENCES execution_entity(id) ON DELETE CASCADE,
  "workflowData" json NOT NULL,
  data text NOT NULL
);
CREATE TABLE binary_data (
  "fileId" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "sourceType" varchar(50) NOT NULL,
  "sourceId" varchar(255) NOT NULL,
  data bytea NOT NULL,
  "mimeType" varchar(255),
  "fileName" varchar(255),
  "fileSize" integer NOT NULL,
  "createdAt" timestamptz(3) NOT NULL DEFAULT now(),
  "updatedAt" timestamptz(3) NOT NULL DEFAULT now()
);
