-- =====================================================================
-- Phase 4 : Promotions
-- =====================================================================

CREATE TABLE promotion (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code               VARCHAR(30),                 -- NULL = auto-apply
    name               VARCHAR(150)  NOT NULL,
    description        VARCHAR(1000),
    banner_url         VARCHAR(500),
    type               VARCHAR(20)   NOT NULL,
    discount_value     NUMERIC(10,2) NOT NULL DEFAULT 0,
    max_discount       NUMERIC(10,2),
    buy_qty            INT,
    get_qty            INT,
    min_order_amount   NUMERIC(10,2) NOT NULL DEFAULT 0,
    scope              VARCHAR(20)   NOT NULL DEFAULT 'ORDER',
    member_only        BOOLEAN       NOT NULL DEFAULT FALSE,
    channel            VARCHAR(20)   NOT NULL DEFAULT 'ALL',
    days_of_week       SMALLINT[],                  -- ISO: 1=จันทร์ ... 7=อาทิตย์, NULL = ทุกวัน
    start_at           TIMESTAMPTZ   NOT NULL,
    end_at             TIMESTAMPTZ   NOT NULL,
    usage_limit        INT,
    usage_per_customer INT,
    used_count         INT           NOT NULL DEFAULT 0,
    show_on_landing    BOOLEAN       NOT NULL DEFAULT TRUE,
    priority           INT           NOT NULL DEFAULT 0,
    is_active          BOOLEAN       NOT NULL DEFAULT TRUE,
    created_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by         VARCHAR(50),
    updated_at         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_by         VARCHAR(50),
    version            BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT ck_promotion_type    CHECK (type IN ('PERCENT', 'FIXED_AMOUNT', 'BUY_X_GET_Y', 'POINT_MULTIPLIER')),
    CONSTRAINT ck_promotion_scope   CHECK (scope IN ('ORDER', 'PRODUCT', 'CATEGORY')),
    CONSTRAINT ck_promotion_channel CHECK (channel IN ('ALL', 'WALK_IN', 'ONLINE')),
    CONSTRAINT ck_promotion_period  CHECK (end_at > start_at),
    CONSTRAINT ck_promotion_percent CHECK (type <> 'PERCENT' OR (discount_value > 0 AND discount_value <= 100)),
    CONSTRAINT ck_promotion_bxgy    CHECK (type <> 'BUY_X_GET_Y' OR (buy_qty IS NOT NULL AND get_qty IS NOT NULL AND buy_qty > 0 AND get_qty > 0)),
    CONSTRAINT ck_promotion_usage   CHECK (usage_limit IS NULL OR used_count <= usage_limit)
);

CREATE UNIQUE INDEX uq_promotion_code ON promotion (upper(code)) WHERE code IS NOT NULL;
CREATE INDEX ix_promotion_active ON promotion (start_at, end_at) WHERE is_active;

CREATE TABLE promotion_target (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_id BIGINT NOT NULL REFERENCES promotion (id) ON DELETE CASCADE,
    product_id   BIGINT REFERENCES product (id),
    category_id  BIGINT REFERENCES category (id),
    CONSTRAINT ck_promotion_target_one CHECK ((product_id IS NULL) <> (category_id IS NULL))
);
CREATE INDEX ix_promotion_target_promo ON promotion_target (promotion_id);

CREATE TABLE promotion_usage (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promotion_id    BIGINT        NOT NULL REFERENCES promotion (id),
    order_id        BIGINT        NOT NULL REFERENCES orders (id),
    customer_id     BIGINT        REFERENCES app_user (id),
    discount_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT uq_promotion_usage UNIQUE (promotion_id, order_id)
);
CREATE INDEX ix_promotion_usage_customer ON promotion_usage (promotion_id, customer_id);
