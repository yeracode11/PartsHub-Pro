import { MigrationInterface, QueryRunner } from "typeorm";

export class AddWarehouseCellToItems1735000000000 implements MigrationInterface {
    name = 'AddWarehouseCellToItems1735000000000'

    public async up(queryRunner: QueryRunner): Promise<void> {
        // Добавляем поле warehouseCell в таблицу items
        await queryRunner.query(`
            ALTER TABLE "items" 
            ADD COLUMN "warehouseCell" character varying(100) NULL
        `);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        // Удаляем поле warehouseCell из таблицы items
        await queryRunner.query(`
            ALTER TABLE "items" 
            DROP COLUMN "warehouseCell"
        `);
    }
}

