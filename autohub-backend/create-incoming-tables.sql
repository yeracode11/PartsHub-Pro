-- Скрипт для создания таблиц incoming_docs и incoming_items
-- Запустите этот скрипт в psql, если таблицы не существуют

-- Создание enum типов
DO $$ BEGIN
    CREATE TYPE incoming_doc_status AS ENUM ('draft', 'done', 'cancelled');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE incoming_doc_type AS ENUM ('used_parts', 'new_parts', 'own_production');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Создание таблицы incoming_docs
CREATE TABLE IF NOT EXISTS incoming_docs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "organizationId" UUID NOT NULL,
    "docNumber" VARCHAR(50) UNIQUE NOT NULL,
    date DATE NOT NULL,
    "supplierId" UUID,
    "supplierName" VARCHAR(255),
    type incoming_doc_type NOT NULL DEFAULT 'new_parts',
    status incoming_doc_status NOT NULL DEFAULT 'draft',
    warehouse VARCHAR(255),
    notes TEXT,
    "docPhotos" JSONB,
    "createdById" UUID NOT NULL,
    "totalAmount" DECIMAL(12, 2) DEFAULT 0,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_organization FOREIGN KEY ("organizationId") REFERENCES organizations(id),
    CONSTRAINT fk_created_by FOREIGN KEY ("createdById") REFERENCES users(id),
    CONSTRAINT fk_supplier FOREIGN KEY ("supplierId") REFERENCES customers(id)
);

-- Создание таблицы incoming_items
CREATE TABLE IF NOT EXISTS incoming_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "docId" UUID NOT NULL,
    "itemId" INTEGER,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    "carBrand" VARCHAR(255),
    "carModel" VARCHAR(255),
    vin VARCHAR(100),
    condition VARCHAR(50),
    quantity INTEGER DEFAULT 1,
    "purchasePrice" DECIMAL(10, 2) NOT NULL,
    "warehouseCell" VARCHAR(100),
    photos JSONB,
    sku VARCHAR(100),
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_doc FOREIGN KEY ("docId") REFERENCES incoming_docs(id) ON DELETE CASCADE,
    CONSTRAINT fk_item FOREIGN KEY ("itemId") REFERENCES items(id)
);

-- Создание индексов для улучшения производительности
CREATE INDEX IF NOT EXISTS idx_incoming_docs_organization ON incoming_docs("organizationId");
CREATE INDEX IF NOT EXISTS idx_incoming_docs_status ON incoming_docs(status);
CREATE INDEX IF NOT EXISTS idx_incoming_docs_date ON incoming_docs(date);
CREATE INDEX IF NOT EXISTS idx_incoming_items_doc ON incoming_items("docId");
CREATE INDEX IF NOT EXISTS idx_incoming_items_item ON incoming_items("itemId");

