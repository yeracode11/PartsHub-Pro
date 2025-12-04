-- Создание таблицы складов
CREATE TABLE IF NOT EXISTS warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    address TEXT,
    phone VARCHAR(50),
    "contactPerson" VARCHAR(255),
    "isActive" BOOLEAN DEFAULT true,
    "organizationId" UUID NOT NULL,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("organizationId") REFERENCES organizations(id) ON DELETE CASCADE
);

-- Добавление поля warehouseId в таблицу items
ALTER TABLE items ADD COLUMN IF NOT EXISTS "warehouseId" UUID;
ALTER TABLE items ADD CONSTRAINT fk_items_warehouse 
    FOREIGN KEY ("warehouseId") REFERENCES warehouses(id) ON DELETE SET NULL;

-- Создание таблицы перемещений товаров
CREATE TABLE IF NOT EXISTS warehouse_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "organizationId" UUID NOT NULL,
    "fromWarehouseId" UUID NOT NULL,
    "toWarehouseId" UUID NOT NULL,
    "itemId" INTEGER NOT NULL,
    quantity INTEGER NOT NULL,
    status VARCHAR(50) DEFAULT 'draft',
    notes TEXT,
    "createdByUserId" UUID,
    "completedByUserId" UUID,
    "completedAt" TIMESTAMP,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("organizationId") REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY ("fromWarehouseId") REFERENCES warehouses(id) ON DELETE RESTRICT,
    FOREIGN KEY ("toWarehouseId") REFERENCES warehouses(id) ON DELETE RESTRICT,
    FOREIGN KEY ("itemId") REFERENCES items(id) ON DELETE RESTRICT,
    FOREIGN KEY ("createdByUserId") REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY ("completedByUserId") REFERENCES users(id) ON DELETE SET NULL
);

-- Индексы для производительности
CREATE INDEX IF NOT EXISTS idx_warehouses_organization ON warehouses("organizationId");
CREATE INDEX IF NOT EXISTS idx_items_warehouse ON items("warehouseId");
CREATE INDEX IF NOT EXISTS idx_transfers_organization ON warehouse_transfers("organizationId");
CREATE INDEX IF NOT EXISTS idx_transfers_warehouses ON warehouse_transfers("fromWarehouseId", "toWarehouseId");
CREATE INDEX IF NOT EXISTS idx_transfers_status ON warehouse_transfers(status);
