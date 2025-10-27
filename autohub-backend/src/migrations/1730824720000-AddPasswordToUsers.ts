import { MigrationInterface, QueryRunner } from "typeorm";

export class AddPasswordToUsers1730824720000 implements MigrationInterface {
    name = 'AddPasswordToUsers1730824720000'

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Add password column to users table (nullable for existing users)
        await queryRunner.query(`
            ALTER TABLE "users" 
            ADD COLUMN "password" character varying(255) NULL
        `);

        // Make firebaseUid nullable (since we're moving away from Firebase)
        await queryRunner.query(`
            ALTER TABLE "users" 
            ALTER COLUMN "firebaseUid" DROP NOT NULL
        `);

        // Drop unique constraint on firebaseUid since it can now be null
        await queryRunner.query(`
            ALTER TABLE "users" 
            DROP CONSTRAINT IF EXISTS "UQ_e621f267079194e5428e19af2f3"
        `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`
            ALTER TABLE "users" 
            DROP COLUMN "password"
        `);

        await queryRunner.query(`
            ALTER TABLE "users" 
            ALTER COLUMN "firebaseUid" SET NOT NULL
        `);
    }
}

