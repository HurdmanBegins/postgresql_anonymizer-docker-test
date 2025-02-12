-- Installer PostgreSQL Anonymizer
CREATE EXTENSION IF NOT EXISTS anon CASCADE;
SELECT anon.init();

