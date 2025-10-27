#!/bin/bash

echo "🔧 Running database migration..."

# Add password column to users table
psql -h localhost -U eracode -d autohubdb << EOF
-- Add password column
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "password" character varying(255) NULL;

-- Make firebaseUid nullable
ALTER TABLE "users" ALTER COLUMN "firebaseUid" DROP NOT NULL;

-- Drop unique constraint
ALTER TABLE "users" DROP CONSTRAINT IF EXISTS "UQ_e621f267079194e5428e19af2f3";
EOF

echo "✅ Migration complete!"

