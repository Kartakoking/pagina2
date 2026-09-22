-- ==============================================================================
-- Esquema de Base de Datos Supabase (PostgreSQL) para la Gestión de Préstamos
-- Compatible con pagina2/index.html
-- ==============================================================================

-- 1. Habilitar extensión para generar UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------
-- TABLA: clients 
-- Almacena la información de los clientes, su aval y sus 3 referencias.
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    phone TEXT,
    address TEXT,
    
    -- Datos del Aval (Fiador)
    aval_name TEXT,
    aval_phone TEXT,
    aval_address TEXT,
    
    -- Referencia 1
    ref1_name TEXT,
    ref1_phone TEXT,
    ref1_address TEXT,
    
    -- Referencia 2
    ref2_name TEXT,
    ref2_phone TEXT,
    ref2_address TEXT,
    
    -- Referencia 3
    ref3_name TEXT,
    ref3_phone TEXT,
    ref3_address TEXT,
    
    -- URLs de las imágenes almacenadas en Supabase Storage
    photo_url TEXT,
    light_bill_url TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- --------------------------------------------------------
-- TABLA: loans 
-- Almacena los créditos asignados a los clientes.
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS loans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    folio_number SERIAL, -- Número de folio autoincrementable (#001, #002...)
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    start_date DATE NOT NULL,
    
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paid', 'renewed')),
    
    -- Para renovaciones (apunta al préstamo que reemplazó)
    previous_loan_id UUID REFERENCES loans(id) ON DELETE SET NULL,
    renewed_at DATE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- --------------------------------------------------------
-- TABLA: payments
-- Almacena las 16 semanas de pago programadas para cada préstamo.
-- --------------------------------------------------------
CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    loan_id UUID NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
    
    week_number INTEGER NOT NULL CHECK (week_number BETWEEN 1 AND 16),
    scheduled_date DATE NOT NULL,
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid')),
    paid_at TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Garantiza que solo exista un registro de pago por semana por cada préstamo
    UNIQUE(loan_id, week_number)
);

-- --------------------------------------------------------
-- ÍNDICES para mejorar rendimiento de consultas
-- --------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_loans_client_id ON loans(client_id);
CREATE INDEX IF NOT EXISTS idx_loans_status ON loans(status);
CREATE INDEX IF NOT EXISTS idx_payments_loan_id ON payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);

-- --------------------------------------------------------
-- POLÍTICAS DE SEGURIDAD Y PERMISOS RLS
-- --------------------------------------------------------
ALTER TABLE clients DISABLE ROW LEVEL SECURITY;
ALTER TABLE loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE payments DISABLE ROW LEVEL SECURITY;

-- ==============================================================================
-- STORAGE BUCKETS: Almacenamiento para foto del cliente y recibo de luz
-- ==============================================================================

-- Crear el bucket público si no existe
INSERT INTO storage.buckets (id, name, public) 
VALUES ('clients_media', 'clients_media', true)
ON CONFLICT (id) DO NOTHING;

-- Permitir lectura y escritura pública en el bucket (elimina anteriores si existen para evitar duplicados)
DROP POLICY IF EXISTS "Acceso de lectura pública" ON storage.objects;
DROP POLICY IF EXISTS "Acceso de subida pública" ON storage.objects;
DROP POLICY IF EXISTS "Acceso de actualización pública" ON storage.objects;

CREATE POLICY "Acceso de lectura pública" 
ON storage.objects FOR SELECT 
USING ( bucket_id = 'clients_media' );

CREATE POLICY "Acceso de subida pública" 
ON storage.objects FOR INSERT 
WITH CHECK ( bucket_id = 'clients_media' );

CREATE POLICY "Acceso de actualización pública" 
ON storage.objects FOR UPDATE 
USING ( bucket_id = 'clients_media' );
