import { MigrationInterface, QueryRunner } from 'typeorm';
import { slugify, VEHICLE_SEED } from '../vehicle-reference/vehicle-reference.seed';

export class VehicleReference1771800000000 implements MigrationInterface {
  name = 'VehicleReference1771800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "vehicle_makes" (
        "id" SERIAL NOT NULL,
        "name" character varying(80) NOT NULL,
        "slug" character varying(80) NOT NULL,
        "synonyms" jsonb NOT NULL DEFAULT '[]',
        "isActive" boolean NOT NULL DEFAULT true,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_vehicle_makes" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_vehicle_makes_slug" ON "vehicle_makes" ("slug")
    `);
    await queryRunner.query(`
      CREATE TABLE "vehicle_models" (
        "id" SERIAL NOT NULL,
        "makeId" integer NOT NULL,
        "name" character varying(80) NOT NULL,
        "slug" character varying(80) NOT NULL,
        "synonyms" jsonb NOT NULL DEFAULT '[]',
        "isActive" boolean NOT NULL DEFAULT true,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_vehicle_models" PRIMARY KEY ("id"),
        CONSTRAINT "FK_vehicle_models_make" FOREIGN KEY ("makeId")
          REFERENCES "vehicle_makes"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_vehicle_models_make_slug"
      ON "vehicle_models" ("makeId", "slug")
    `);
    await queryRunner.query(`
      CREATE TABLE "vehicle_generations" (
        "id" SERIAL NOT NULL,
        "modelId" integer NOT NULL,
        "name" character varying(80) NOT NULL,
        "slug" character varying(80) NOT NULL,
        "yearFrom" smallint,
        "yearTo" smallint,
        "synonyms" jsonb NOT NULL DEFAULT '[]',
        "isActive" boolean NOT NULL DEFAULT true,
        "sortOrder" integer NOT NULL DEFAULT 0,
        "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
        "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_vehicle_generations" PRIMARY KEY ("id"),
        CONSTRAINT "FK_vehicle_generations_model" FOREIGN KEY ("modelId")
          REFERENCES "vehicle_models"("id") ON DELETE RESTRICT
      )
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "UQ_vehicle_generations_model_slug"
      ON "vehicle_generations" ("modelId", "slug")
    `);

    let makeOrder = 0;
    for (const make of VEHICLE_SEED) {
      const makeRows: Array<{ id: number }> = await queryRunner.query(
        `INSERT INTO "vehicle_makes" ("name", "slug", "synonyms", "sortOrder")
         VALUES ($1, $2, $3::jsonb, $4) RETURNING "id"`,
        [make.name, slugify(make.name), JSON.stringify(make.synonyms ?? []), makeOrder++],
      );
      const makeId = makeRows[0].id;
      let modelOrder = 0;
      for (const model of make.models) {
        const modelRows: Array<{ id: number }> = await queryRunner.query(
          `INSERT INTO "vehicle_models" ("makeId", "name", "slug", "synonyms", "sortOrder")
           VALUES ($1, $2, $3, $4::jsonb, $5) RETURNING "id"`,
          [makeId, model.name, slugify(model.name), JSON.stringify(model.synonyms ?? []), modelOrder++],
        );
        const modelId = modelRows[0].id;
        let generationOrder = 0;
        for (const generation of model.generations ?? []) {
          await queryRunner.query(
            `INSERT INTO "vehicle_generations"
              ("modelId", "name", "slug", "yearFrom", "yearTo", "synonyms", "sortOrder")
             VALUES ($1, $2, $3, $4, $5, $6::jsonb, $7)`,
            [
              modelId,
              generation.name,
              slugify(generation.name),
              generation.yearFrom ?? null,
              generation.yearTo === undefined ? null : generation.yearTo,
              JSON.stringify(generation.synonyms ?? []),
              generationOrder++,
            ],
          );
        }
      }
    }

    await queryRunner.query(`
      ALTER TABLE "donor_vehicles"
        ADD COLUMN "makeId" integer,
        ADD COLUMN "modelId" integer,
        ADD COLUMN "generationId" integer
    `);
    await queryRunner.query(`
      ALTER TABLE "part_compatibility"
        ADD COLUMN "makeId" integer,
        ADD COLUMN "modelId" integer,
        ADD COLUMN "generationId" integer
    `);
    await this.linkText(queryRunner, 'donor_vehicles', 'brand', 'model', 'generation');
    await this.linkText(queryRunner, 'part_compatibility', 'make', 'model', 'generation');
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles"
        ADD CONSTRAINT "FK_donor_vehicles_make" FOREIGN KEY ("makeId")
          REFERENCES "vehicle_makes"("id") ON DELETE SET NULL,
        ADD CONSTRAINT "FK_donor_vehicles_model" FOREIGN KEY ("modelId")
          REFERENCES "vehicle_models"("id") ON DELETE SET NULL,
        ADD CONSTRAINT "FK_donor_vehicles_generation" FOREIGN KEY ("generationId")
          REFERENCES "vehicle_generations"("id") ON DELETE SET NULL
    `);
    await queryRunner.query(`
      ALTER TABLE "part_compatibility"
        ADD CONSTRAINT "FK_part_compatibility_make" FOREIGN KEY ("makeId")
          REFERENCES "vehicle_makes"("id") ON DELETE SET NULL,
        ADD CONSTRAINT "FK_part_compatibility_model" FOREIGN KEY ("modelId")
          REFERENCES "vehicle_models"("id") ON DELETE SET NULL,
        ADD CONSTRAINT "FK_part_compatibility_generation" FOREIGN KEY ("generationId")
          REFERENCES "vehicle_generations"("id") ON DELETE SET NULL
    `);
  }

  private async linkText(
    queryRunner: QueryRunner,
    table: string,
    makeCol: string,
    modelCol: string,
    generationCol: string,
  ) {
    await queryRunner.query(`
      UPDATE "${table}" row
      SET "makeId" = mk.id
      FROM "vehicle_makes" mk
      WHERE row."makeId" IS NULL
        AND (
          lower(row."${makeCol}") = lower(mk.name)
          OR lower(row."${makeCol}") = mk.slug
          OR EXISTS (
            SELECT 1 FROM jsonb_array_elements_text(mk.synonyms) s
            WHERE lower(s) = lower(row."${makeCol}")
          )
        )
    `);
    await queryRunner.query(`
      UPDATE "${table}" row
      SET "modelId" = mo.id
      FROM "vehicle_models" mo
      WHERE row."makeId" = mo."makeId"
        AND row."modelId" IS NULL
        AND (
          lower(row."${modelCol}") = lower(mo.name)
          OR lower(row."${modelCol}") = mo.slug
          OR EXISTS (
            SELECT 1 FROM jsonb_array_elements_text(mo.synonyms) s
            WHERE lower(s) = lower(row."${modelCol}")
          )
        )
    `);
    await queryRunner.query(`
      UPDATE "${table}" row
      SET "generationId" = gen.id
      FROM "vehicle_generations" gen
      WHERE row."modelId" = gen."modelId"
        AND row."${generationCol}" IS NOT NULL
        AND row."generationId" IS NULL
        AND (
          lower(row."${generationCol}") = lower(gen.name)
          OR lower(row."${generationCol}") = gen.slug
          OR EXISTS (
            SELECT 1 FROM jsonb_array_elements_text(gen.synonyms) s
            WHERE lower(s) = lower(row."${generationCol}")
          )
        )
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "part_compatibility"
        DROP CONSTRAINT IF EXISTS "FK_part_compatibility_generation",
        DROP CONSTRAINT IF EXISTS "FK_part_compatibility_model",
        DROP CONSTRAINT IF EXISTS "FK_part_compatibility_make",
        DROP COLUMN IF EXISTS "generationId",
        DROP COLUMN IF EXISTS "modelId",
        DROP COLUMN IF EXISTS "makeId"
    `);
    await queryRunner.query(`
      ALTER TABLE "donor_vehicles"
        DROP CONSTRAINT IF EXISTS "FK_donor_vehicles_generation",
        DROP CONSTRAINT IF EXISTS "FK_donor_vehicles_model",
        DROP CONSTRAINT IF EXISTS "FK_donor_vehicles_make",
        DROP COLUMN IF EXISTS "generationId",
        DROP COLUMN IF EXISTS "modelId",
        DROP COLUMN IF EXISTS "makeId"
    `);
    await queryRunner.query(`DROP TABLE IF EXISTS "vehicle_generations"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "vehicle_models"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "vehicle_makes"`);
  }
}
