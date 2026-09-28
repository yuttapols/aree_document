-- =====================================================================
-- Phase 3 : ออเดอร์ + การชำระเงิน
-- =====================================================================

CREATE TABLE orders (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_no           VARCHAR(20)   NOT NULL,
    tracking_token     UUID          NOT NULL DEFAULT gen_random_uuid(),
    channel            VARCHAR(20)   NOT NULL,
    status             VARCHAR(20)   NOT NULL DEFAULT 'PENDING_PAYMENT',
    customer_id        BIGINT        REFERENCES app_user (id),   -- NULL = guest / walk-in ไม่สมัคร
    guest_name         VARCHAR(100),
    guest_phone        VARCHAR(20),
    queue_no           INT           NOT NULL,
    subtotal           NUMERIC(10,2) NOT NULL DEFAULT 0,
    promotion_discount NUMERIC(10,2) NOT NULL DEFAULT 0,
    point_discount     NUMERIC(10,2) NOT NULL DEFAULT 0,
    total_amount       NUMERIC(10,2) NOT NULL DEFAULT 0,
    points_redeemed    INT           NOT NULL DEFAULT 0,
    points_earned      INT           NOT NULL DEFAULT 0,
    note               TEXT,
    cashier_id         BIGINT        REFERENCES app_user (id),
    confirmed_at       TIMESTAMPTZ,
    completed_at       TIMESTAMPTZ,
    cancelled_at       TIMESTAMPTZ,
    cancel_reason      TEXT,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by         VARCHAR(50),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_by         VARCHAR(50),
    version            BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT uq_orders_order_no       UNIQUE (order_no),
    CONSTRAINT uq_orders_tracking_token UNIQUE (tracking_token),
    CONSTRAINT ck_orders_channel CHECK (channel IN ('WALK_IN', 'ONLINE')),
    CONSTRAINT ck_orders_status  CHECK (status IN ('PENDING_PAYMENT', 'CONFIRMED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED')),
    CONSTRAINT ck_orders_amounts CHECK (subtotal >= 0 AND promotion_discount >= 0 AND point_discount >= 0 AND total_amount >= 0),
    CONSTRAINT ck_orders_points  CHECK (points_redeemed >= 0 AND points_earned >= 0),
    -- ออเดอร์ออนไลน์ของ guest ต้องมีเบอร์ติดต่อ
    CONSTRAINT ck_orders_online_guest CHECK (channel <> 'ONLINE' OR customer_id IS NOT NULL OR guest_phone IS NOT NULL)
);

CREATE INDEX ix_orders_status_created ON orders (status, created_at);
CREATE INDEX ix_orders_customer       ON orders (customer_id, created_at DESC) WHERE customer_id IS NOT NULL;
CREATE INDEX ix_orders_created        ON orders (created_at);

-- running number ต่อวัน สำหรับ order_no และ queue_no (ใช้ UPSERT ... RETURNING ใน service)
CREATE TABLE daily_counter (
    counter_date DATE        NOT NULL,
    counter_name VARCHAR(30) NOT NULL,
    last_value   INT         NOT NULL DEFAULT 0,
    PRIMARY KEY (counter_date, counter_name)
);

CREATE TABLE order_item (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id      BIGINT        NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
    product_id    BIGINT        NOT NULL REFERENCES product (id),
    product_name  VARCHAR(150)  NOT NULL,   -- snapshot
    unit_price    NUMERIC(10,2) NOT NULL,   -- snapshot
    options_price NUMERIC(10,2) NOT NULL DEFAULT 0,
    quantity      INT           NOT NULL,
    line_total    NUMERIC(10,2) NOT NULL,   -- (unit_price + options_price) * quantity
    free_quantity INT           NOT NULL DEFAULT 0,  -- จาก BUY_X_GET_Y (Phase 4)
    note          VARCHAR(300),
    CONSTRAINT ck_order_item_qty CHECK (quantity > 0 AND free_quantity >= 0 AND free_quantity <= quantity)
);
CREATE INDEX ix_order_item_order   ON order_item (order_id);
CREATE INDEX ix_order_item_product ON order_item (product_id);

CREATE TABLE order_item_option (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_item_id     BIGINT        NOT NULL REFERENCES order_item (id) ON DELETE CASCADE,
    option_item_id    BIGINT        REFERENCES option_item (id) ON DELETE SET NULL,
    option_group_name VARCHAR(100)  NOT NULL,  -- snapshot
    option_name       VARCHAR(100)  NOT NULL,  -- snapshot
    extra_price       NUMERIC(10,2) NOT NULL DEFAULT 0
);
CREATE INDEX ix_order_item_option_item ON order_item_option (order_item_id);

CREATE TABLE payment (
    id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id          BIGINT        NOT NULL REFERENCES orders (id),
    payment_method_id BIGINT        NOT NULL REFERENCES payment_method (id),
    amount            NUMERIC(10,2) NOT NULL,
    cash_received     NUMERIC(10,2),
    change_amount     NUMERIC(10,2),
    reference_no      VARCHAR(100),
    slip_url          VARCHAR(500),
    status            VARCHAR(20)   NOT NULL DEFAULT 'PENDING',
    paid_at           TIMESTAMPTZ,
    verified_by       BIGINT        REFERENCES app_user (id),
    reject_reason     VARCHAR(300),
    created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by        VARCHAR(50),
    updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_by        VARCHAR(50),
    version           BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT ck_payment_status CHECK (status IN ('PENDING', 'PAID', 'REJECTED', 'REFUNDED')),
    CONSTRAINT ck_payment_amount CHECK (amount > 0)
);
CREATE INDEX ix_payment_order   ON payment (order_id);
CREATE INDEX ix_payment_pending ON payment (created_at) WHERE status = 'PENDING';
