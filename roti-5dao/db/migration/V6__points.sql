-- =====================================================================
-- Phase 4 : Point ledger
-- =====================================================================

CREATE TABLE point_transaction (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id   BIGINT       NOT NULL REFERENCES app_user (id),
    order_id      BIGINT       REFERENCES orders (id),
    type          VARCHAR(20)  NOT NULL,
    points        INT          NOT NULL,   -- บวก = ได้, ลบ = ใช้/หมดอายุ/ดึงคืน
    balance_after INT          NOT NULL,
    remaining     INT,                     -- เฉพาะ EARN/ADJUST(+) : แต้มคงเหลือของก้อนนี้ (ตัดแบบ FIFO)
    expires_at    TIMESTAMPTZ,
    remark        VARCHAR(300),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by    VARCHAR(50),
    CONSTRAINT ck_point_tx_type    CHECK (type IN ('EARN', 'REDEEM', 'ADJUST', 'EXPIRE', 'REVERSE')),
    CONSTRAINT ck_point_tx_nonzero CHECK (points <> 0),
    CONSTRAINT ck_point_tx_balance CHECK (balance_after >= 0),
    CONSTRAINT ck_point_tx_remain  CHECK (remaining IS NULL OR (remaining >= 0 AND remaining <= points))
);

CREATE INDEX ix_point_tx_customer ON point_transaction (customer_id, created_at DESC);
CREATE INDEX ix_point_tx_order    ON point_transaction (order_id) WHERE order_id IS NOT NULL;
CREATE INDEX ix_point_tx_expiring ON point_transaction (expires_at) WHERE remaining > 0;

-- ป้องกันให้แต้มซ้ำจากออเดอร์เดียวกัน
CREATE UNIQUE INDEX uq_point_tx_order_earn ON point_transaction (order_id) WHERE type = 'EARN';
