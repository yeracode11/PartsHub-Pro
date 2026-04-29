import { MigrationInterface, QueryRunner } from 'typeorm';

/**
 * Добавляет значение `superadmin` в Postgres ENUM `users_role_enum`.
 * Откат удаления значения из ENUM в PostgreSQL нетривиален — down() пустой.
 */
export class AddSuperadminUserRole1770100000000 implements MigrationInterface {
  name = 'AddSuperadminUserRole1770100000000';

  /** ALTER TYPE … ADD VALUE не всегда допустим внутри транзакции на старых PG. */
  public transaction = false;

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."users_role_enum" ADD VALUE IF NOT EXISTS 'superadmin'`,
    );
  }

  public async down(): Promise<void> {
    // Удаление значения из ENUM в PostgreSQL требует пересоздания типа — не делаем автоматически.
  }
}
