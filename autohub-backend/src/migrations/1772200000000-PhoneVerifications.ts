import { MigrationInterface, QueryRunner } from 'typeorm';

export class PhoneVerifications1772200000000 implements MigrationInterface {
  name = 'PhoneVerifications1772200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE IF NOT EXISTS "phone_verifications" (
        "id" uuid NOT NULL DEFAULT gen_random_uuid(),
        "phone" character varying(20) NOT NULL,
        "code" character varying(12) NOT NULL,
        "secretHash" character varying(64) NOT NULL,
        "purpose" character varying(20) NOT NULL,
        "status" character varying(20) NOT NULL DEFAULT 'pending',
        "mismatchCount" integer NOT NULL DEFAULT 0,
        "inboundMessageId" character varying(128),
        "expiresAt" TIMESTAMP WITH TIME ZONE NOT NULL,
        "verifiedAt" TIMESTAMP WITH TIME ZONE,
        "createdAt" TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
        CONSTRAINT "PK_phone_verifications_id" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_phone_verifications_phone" ON "phone_verifications" ("phone")`,
    );
    await queryRunner.query(
      `CREATE INDEX IF NOT EXISTS "IDX_phone_verifications_code" ON "phone_verifications" ("code")`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "phone_verifications"`);
  }
}
