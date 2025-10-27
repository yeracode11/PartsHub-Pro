#!/bin/bash

echo "🔧 Setting up user password on production database..."

# Connect to database and apply password
psql -h localhost -U eracode -d AutohubDB << EOF

-- Update existing user with password
UPDATE users 
SET password = '$2b$10$r8rsXwuFSUQn82Hq10f7gu.FjD.ISHt.sVE1LEvyBUKGlhxzETCUK',
    "updatedAt" = NOW()
WHERE email = 'ersul143@gmail.com';

-- Create organization if it doesn't exist
INSERT INTO organizations (
  id,
  name,
  "businessType",
  "isActive",
  "createdAt",
  "updatedAt"
)
VALUES (
  '41eb0f1f-332e-4865-a532-a5384d8155c3',
  'Моя Организация',
  'service',
  true,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Update user's organization
UPDATE users 
SET "organizationId" = '41eb0f1f-332e-4865-a532-a5384d8155c3'
WHERE email = 'ersul143@gmail.com';

EOF

echo "✅ Password setup complete!"
echo "📧 Email: ersul143@gmail.com"
echo "🔑 Password: admin123"

