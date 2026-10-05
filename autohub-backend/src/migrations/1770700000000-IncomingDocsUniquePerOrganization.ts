import { MigrationInterface, QueryRunner } from 'typeorm';

export class IncomingDocsUniquePerOrganization1770700000000
  implements MigrationInterface
{
  name = 'IncomingDocsUniquePerOrganization1770700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$
      DECLARE
        r RECORD;
      BEGIN
        IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'incoming_docs') THEN
          -- Удаляем глобальные unique constraints на docNumber
          FOR r IN (
              SELECT c.conname
              FROM pg_constraint c
              JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
              WHERE c.conrelid = 'incoming_docs'::regclass
                AND c.contype = 'u'
                AND a.attname = 'docNumber'
                AND array_length(c.conkey, 1) = 1
          ) LOOP
              EXECUTE 'ALTER TABLE "incoming_docs" DROP CONSTRAINT IF EXISTS "' || r.conname || '"';
          END LOOP;

          -- Удаляем глобальные unique indexes на docNumber
          FOR r IN (
              SELECT i.relname
              FROM pg_index x
              JOIN pg_class c ON c.oid = x.indrelid
              JOIN pg_class i ON i.oid = x.indexrelid
              JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(x.indkey)
              WHERE c.relname = 'incoming_docs'
                AND x.indisunique
                AND a.attname = 'docNumber'
                AND array_length(x.indkey, 1) = 1
          ) LOOP
              EXECUTE 'DROP INDEX IF EXISTS "' || r.relname || '"';
          END LOOP;

          -- Создаем составной уникальный индекс (организация + номер накладной)
          EXECUTE 'CREATE UNIQUE INDEX IF NOT EXISTS "UQ_incoming_docs_org_doc_number" ON "incoming_docs" ("organizationId", "docNumber")';
        END IF;
      END $$;
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      DO $$
      BEGIN
        IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'incoming_docs') THEN
          EXECUTE 'DROP INDEX IF EXISTS "UQ_incoming_docs_org_doc_number"';
        END IF;
      END $$;
    `);
  }
}
