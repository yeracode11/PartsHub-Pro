import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddWorkStagesToOrders1769000000000
  implements MigrationInterface
{
  name = 'AddWorkStagesToOrders1769000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN "workStages" jsonb`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP COLUMN "workStages"`,
    );
  }
}
