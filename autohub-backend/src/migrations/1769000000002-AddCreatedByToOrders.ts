import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCreatedByToOrders1769000000002
  implements MigrationInterface
{
  name = 'AddCreatedByToOrders1769000000002';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN "createdByUserId" uuid`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" ADD CONSTRAINT "FK_orders_createdByUserId" FOREIGN KEY ("createdByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP CONSTRAINT "FK_orders_createdByUserId"`,
    );
    await queryRunner.query(
      `ALTER TABLE "orders" DROP COLUMN "createdByUserId"`,
    );
  }
}
