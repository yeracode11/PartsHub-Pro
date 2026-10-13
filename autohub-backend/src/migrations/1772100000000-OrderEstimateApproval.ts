import { MigrationInterface, QueryRunner } from 'typeorm';

export class OrderEstimateApproval1772100000000 implements MigrationInterface {
  name = 'OrderEstimateApproval1772100000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
        ADD COLUMN "estimateApprovedAt" TIMESTAMP WITH TIME ZONE,
        ADD COLUMN "estimateApprovedTotal" numeric(10,2),
        ADD COLUMN "estimateApprovalMethod" character varying(20),
        ADD COLUMN "estimateApprovalNote" text,
        ADD COLUMN "estimateApprovedById" uuid
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "orders"
        DROP COLUMN "estimateApprovedById",
        DROP COLUMN "estimateApprovalNote",
        DROP COLUMN "estimateApprovalMethod",
        DROP COLUMN "estimateApprovedTotal",
        DROP COLUMN "estimateApprovedAt"
    `);
  }
}
