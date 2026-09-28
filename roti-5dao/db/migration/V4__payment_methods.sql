-- =====================================================================
-- Phase 3 : ประเภทการจ่ายเงิน
-- =====================================================================

CREATE TABLE payment_method (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code               VARCHAR(30)  NOT NULL,
    name               VARCHAR(100) NOT NULL,
    requires_slip      BOOLEAN      NOT NULL DEFAULT FALSE,
    requires_reference BOOLEAN      NOT NULL DEFAULT FALSE,
    allow_online       BOOLEAN      NOT NULL DEFAULT FALSE,  -- ลูกค้าเลือกเองตอนสั่งออนไลน์ได้
    instruction        VARCHAR(1000),                        -- เช่น เลขบัญชี / วิธีโอน
    icon               VARCHAR(100),
    is_active          BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order         INT          NOT NULL DEFAULT 0,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by         VARCHAR(50),
    updated_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by         VARCHAR(50),
    version            BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT uq_payment_method_code UNIQUE (code)
);

INSERT INTO payment_method (code, name, requires_slip, requires_reference, allow_online, icon, sort_order, created_by) VALUES
    ('CASH',      'เงินสด',          FALSE, FALSE, FALSE, 'pi pi-money-bill',  1, 'flyway'),
    ('TRANSFER',  'โอนเงินธนาคาร',    TRUE,  FALSE, TRUE,  'pi pi-building-columns', 2, 'flyway'),
    ('PROMPTPAY', 'พร้อมเพย์ (QR)',   TRUE,  FALSE, TRUE,  'pi pi-qrcode',      3, 'flyway'),
    ('CARD',      'บัตรเครดิต/เดบิต', FALSE, TRUE,  FALSE, 'pi pi-credit-card', 4, 'flyway');
