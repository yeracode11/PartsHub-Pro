import { MigrationInterface, QueryRunner } from "typeorm";

export class InitDatabase1761570945934 implements MigrationInterface {
    name = 'InitDatabase1761570945934'

    public async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`CREATE TYPE "public"."users_role_enum" AS ENUM('owner', 'manager', 'storekeeper', 'worker')`);
        await queryRunner.query(`CREATE TABLE "users" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "firebaseUid" character varying(255) NOT NULL, "email" character varying(255) NOT NULL, "name" character varying(255) NOT NULL, "role" "public"."users_role_enum" NOT NULL DEFAULT 'owner', "organizationId" uuid NOT NULL, "isActive" boolean NOT NULL DEFAULT true, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_e621f267079194e5428e19af2f3" UNIQUE ("firebaseUid"), CONSTRAINT "PK_a3ffb1c0c8416b9fc6f907b7433" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."organizations_businesstype_enum" AS ENUM('service', 'parts', 'carwash')`);
        await queryRunner.query(`CREATE TABLE "organizations" ("id" uuid NOT NULL DEFAULT uuid_generate_v4(), "name" character varying(255) NOT NULL, "businessType" "public"."organizations_businesstype_enum" NOT NULL DEFAULT 'service', "settings" jsonb, "isActive" boolean NOT NULL DEFAULT true, "phone" character varying(100), "address" character varying(255), "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_6b031fcd0863e3f6b44230163f9" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."message_templates_category_enum" AS ENUM('promo', 'reminder', 'notification', 'greeting', 'custom')`);
        await queryRunner.query(`CREATE TABLE "message_templates" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "name" character varying(100) NOT NULL, "content" text NOT NULL, "category" "public"."message_templates_category_enum" NOT NULL DEFAULT 'custom', "isActive" boolean NOT NULL DEFAULT true, "usageCount" integer NOT NULL DEFAULT '0', "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_9ac2bd9635be662d183f314947d" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "items" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "name" character varying(255) NOT NULL, "sku" character varying(100), "category" character varying(100), "price" numeric(10,2) NOT NULL, "quantity" integer NOT NULL DEFAULT '0', "condition" character varying(50), "description" text, "imageUrl" character varying(500), "images" jsonb, "synced" boolean NOT NULL DEFAULT false, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_ba5885359424c15ca6b9e79bcf6" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "order_items" ("id" SERIAL NOT NULL, "orderId" integer NOT NULL, "itemId" integer NOT NULL, "quantity" integer NOT NULL, "priceAtTime" numeric(10,2) NOT NULL, "subtotal" numeric(10,2) NOT NULL, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_005269d8574e6fac0493715c308" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."vehicles_fueltype_enum" AS ENUM('petrol', 'diesel', 'electric', 'hybrid', 'gas')`);
        await queryRunner.query(`CREATE TYPE "public"."vehicles_transmission_enum" AS ENUM('manual', 'automatic', 'robot', 'cvt')`);
        await queryRunner.query(`CREATE TABLE "vehicles" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "customerId" integer NOT NULL, "brand" character varying(50) NOT NULL, "model" character varying(50) NOT NULL, "year" integer NOT NULL, "color" character varying(50), "plateNumber" character varying(20) NOT NULL, "vin" character varying(17), "fuelType" "public"."vehicles_fueltype_enum" NOT NULL DEFAULT 'petrol', "transmission" "public"."vehicles_transmission_enum" NOT NULL DEFAULT 'manual', "engineVolume" character varying(20), "enginePower" integer, "currentMileage" integer NOT NULL DEFAULT '0', "lastServiceMileage" integer, "lastServiceDate" date, "nextServiceMileage" integer, "nextServiceDate" date, "notes" text, "photoUrl" character varying(255), "isActive" boolean NOT NULL DEFAULT true, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_66ea96381a7a7ceb35c72f36625" UNIQUE ("plateNumber"), CONSTRAINT "UQ_8288ce015b69c5856cf54e07a67" UNIQUE ("vin"), CONSTRAINT "PK_18d8646b59304dce4af3a9e35b6" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "orders" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "orderNumber" character varying(50) NOT NULL, "customerId" integer, "vehicleId" integer, "totalAmount" numeric(10,2) NOT NULL, "status" character varying(50) NOT NULL DEFAULT 'pending', "paymentStatus" character varying(50) NOT NULL DEFAULT 'pending', "notes" text, "synced" boolean NOT NULL DEFAULT false, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "UQ_2ca44e628fbdd05d20574abb5d3" UNIQUE ("organizationId", "orderNumber"), CONSTRAINT "PK_710e2d4957aa5878dfe94e4ac2f" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TABLE "customers" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "name" character varying(255) NOT NULL, "phone" character varying(50), "email" character varying(255), "carModel" character varying(100), "notes" text, "synced" boolean NOT NULL DEFAULT false, "createdAt" TIMESTAMP NOT NULL DEFAULT now(), "updatedAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_133ec679a801fab5e070f73d3ea" PRIMARY KEY ("id"))`);
        await queryRunner.query(`CREATE TYPE "public"."message_history_status_enum" AS ENUM('sent', 'failed', 'pending')`);
        await queryRunner.query(`CREATE TABLE "message_history" ("id" SERIAL NOT NULL, "organizationId" uuid NOT NULL, "sentBy" uuid NOT NULL, "customerId" integer, "phone" character varying(20) NOT NULL, "message" text NOT NULL, "status" "public"."message_history_status_enum" NOT NULL DEFAULT 'sent', "errorMessage" text, "isBulk" boolean NOT NULL DEFAULT false, "campaignName" character varying(100), "sentAt" TIMESTAMP NOT NULL DEFAULT now(), CONSTRAINT "PK_5b3bd70fbc92e976540d6ceb67c" PRIMARY KEY ("id"))`);
        await queryRunner.query(`ALTER TABLE "users" ADD CONSTRAINT "FK_f3d6aea8fcca58182b2e80ce979" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "message_templates" ADD CONSTRAINT "FK_1e306bbaed69d8d485a905605f7" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "items" ADD CONSTRAINT "FK_68bb72ce92f1bcab12c2019f99d" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "order_items" ADD CONSTRAINT "FK_f1d359a55923bb45b057fbdab0d" FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "order_items" ADD CONSTRAINT "FK_e253fbd572683bcc785a70cbca7" FOREIGN KEY ("itemId") REFERENCES "items"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "vehicles" ADD CONSTRAINT "FK_664beec1edf19bf68494a3def74" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "vehicles" ADD CONSTRAINT "FK_ddb00709ac9788b3ded9296f2a8" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_07ab27b1d7bf97892493f47d929" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_e5de51ca888d8b1f5ac25799dd1" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "orders" ADD CONSTRAINT "FK_19b96cf049d221b5731e4ed9b7d" FOREIGN KEY ("vehicleId") REFERENCES "vehicles"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "customers" ADD CONSTRAINT "FK_fac3145c49520eae6248715b26b" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "message_history" ADD CONSTRAINT "FK_239df32875ed35fbf6a2f04fa87" FOREIGN KEY ("organizationId") REFERENCES "organizations"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "message_history" ADD CONSTRAINT "FK_f1c8b2bd01a9c1f57b1a8abb1cf" FOREIGN KEY ("sentBy") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
        await queryRunner.query(`ALTER TABLE "message_history" ADD CONSTRAINT "FK_363f10506013aa24b49bd18f1e1" FOREIGN KEY ("customerId") REFERENCES "customers"("id") ON DELETE NO ACTION ON UPDATE NO ACTION`);
    }

    public async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "message_history" DROP CONSTRAINT "FK_363f10506013aa24b49bd18f1e1"`);
        await queryRunner.query(`ALTER TABLE "message_history" DROP CONSTRAINT "FK_f1c8b2bd01a9c1f57b1a8abb1cf"`);
        await queryRunner.query(`ALTER TABLE "message_history" DROP CONSTRAINT "FK_239df32875ed35fbf6a2f04fa87"`);
        await queryRunner.query(`ALTER TABLE "customers" DROP CONSTRAINT "FK_fac3145c49520eae6248715b26b"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT "FK_19b96cf049d221b5731e4ed9b7d"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT "FK_e5de51ca888d8b1f5ac25799dd1"`);
        await queryRunner.query(`ALTER TABLE "orders" DROP CONSTRAINT "FK_07ab27b1d7bf97892493f47d929"`);
        await queryRunner.query(`ALTER TABLE "vehicles" DROP CONSTRAINT "FK_ddb00709ac9788b3ded9296f2a8"`);
        await queryRunner.query(`ALTER TABLE "vehicles" DROP CONSTRAINT "FK_664beec1edf19bf68494a3def74"`);
        await queryRunner.query(`ALTER TABLE "order_items" DROP CONSTRAINT "FK_e253fbd572683bcc785a70cbca7"`);
        await queryRunner.query(`ALTER TABLE "order_items" DROP CONSTRAINT "FK_f1d359a55923bb45b057fbdab0d"`);
        await queryRunner.query(`ALTER TABLE "items" DROP CONSTRAINT "FK_68bb72ce92f1bcab12c2019f99d"`);
        await queryRunner.query(`ALTER TABLE "message_templates" DROP CONSTRAINT "FK_1e306bbaed69d8d485a905605f7"`);
        await queryRunner.query(`ALTER TABLE "users" DROP CONSTRAINT "FK_f3d6aea8fcca58182b2e80ce979"`);
        await queryRunner.query(`DROP TABLE "message_history"`);
        await queryRunner.query(`DROP TYPE "public"."message_history_status_enum"`);
        await queryRunner.query(`DROP TABLE "customers"`);
        await queryRunner.query(`DROP TABLE "orders"`);
        await queryRunner.query(`DROP TABLE "vehicles"`);
        await queryRunner.query(`DROP TYPE "public"."vehicles_transmission_enum"`);
        await queryRunner.query(`DROP TYPE "public"."vehicles_fueltype_enum"`);
        await queryRunner.query(`DROP TABLE "order_items"`);
        await queryRunner.query(`DROP TABLE "items"`);
        await queryRunner.query(`DROP TABLE "message_templates"`);
        await queryRunner.query(`DROP TYPE "public"."message_templates_category_enum"`);
        await queryRunner.query(`DROP TABLE "organizations"`);
        await queryRunner.query(`DROP TYPE "public"."organizations_businesstype_enum"`);
        await queryRunner.query(`DROP TABLE "users"`);
        await queryRunner.query(`DROP TYPE "public"."users_role_enum"`);
    }

}
