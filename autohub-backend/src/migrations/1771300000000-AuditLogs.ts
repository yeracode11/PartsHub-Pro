import { MigrationInterface, QueryRunner } from 'typeorm';

export class AuditLogs1771300000000 implements MigrationInterface {
  name = 'AuditLogs1771300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "audit_logs" (
        "id" BIGSERIAL NOT NULL,
        "organizationId" uuid NOT NULL,
        "userId" uuid,
        "entityType" character varying(50) NOT NULL,
        "entityId" character varying(64) NOT NULL,
        "action" character varying(30) NOT NULL,
        "changes" jsonb NOT NULL,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_audit_logs" PRIMARY KEY ("id"),
        CONSTRAINT "FK_audit_logs_organization" FOREIGN KEY ("organizationId")
          REFERENCES "organizations"("id") ON DELETE CASCADE
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "IDX_audit_logs_entity"
      ON "audit_logs" ("organizationId", "entityType", "entityId", "createdAt")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "audit_logs"`);
  }
}
