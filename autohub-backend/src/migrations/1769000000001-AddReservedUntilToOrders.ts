import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddReservedUntilToOrders1769000000001
  implements MigrationInterface
{
  name = 'AddReservedUntilToOrders1769000000001';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" ADD COLUMN "reservedUntil" timestamptz`,
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TABLE "orders" DROP COLUMN "reservedUntil"`,
    );
  }
}
