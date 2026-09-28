-- =====================================================================
-- Phase 2 : ตัวเลือกสินค้า (ท็อปปิ้ง/ความหวาน) + รูปเพิ่มเติม
-- =====================================================================

CREATE TABLE option_group (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    min_select  INT          NOT NULL DEFAULT 0,
    max_select  INT          NOT NULL DEFAULT 1,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    sort_order  INT          NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  VARCHAR(50),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    version     BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT ck_option_group_select CHECK (min_select >= 0 AND max_select >= min_select AND max_select >= 1)
);

CREATE TABLE option_item (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    option_group_id BIGINT        NOT NULL REFERENCES option_group (id) ON DELETE CASCADE,
    name            VARCHAR(100)  NOT NULL,
    extra_price     NUMERIC(10,2) NOT NULL DEFAULT 0,
    is_available    BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order      INT           NOT NULL DEFAULT 0,
    CONSTRAINT ck_option_item_price CHECK (extra_price >= 0)
);
CREATE INDEX ix_option_item_group ON option_item (option_group_id, sort_order);

CREATE TABLE product_option_group_map (
    product_id      BIGINT NOT NULL REFERENCES product (id) ON DELETE CASCADE,
    option_group_id BIGINT NOT NULL REFERENCES option_group (id) ON DELETE CASCADE,
    sort_order      INT    NOT NULL DEFAULT 0,
    PRIMARY KEY (product_id, option_group_id)
);

CREATE TABLE product_image (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id  BIGINT       NOT NULL REFERENCES product (id) ON DELETE CASCADE,
    url         VARCHAR(500) NOT NULL,
    sort_order  INT          NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX ix_product_image_product ON product_image (product_id, sort_order);
