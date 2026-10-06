import { MigrationInterface, QueryRunner } from 'typeorm';

/** Добавляет роль `sto` в Postgres ENUM `users_role_enum`. */
export class AddStoUserRole1771100000000 implements MigrationInterface {
  name = 'AddStoUserRole1771100000000';

  public transaction = false;

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(
      `ALTER TYPE "public"."users_role_enum" ADD VALUE IF NOT EXISTS 'sto'`,
    );
  }

  public async down(): Promise<void> {
    // Удаление значения из ENUM в PostgreSQL требует пересоздания типа.
  }
}
