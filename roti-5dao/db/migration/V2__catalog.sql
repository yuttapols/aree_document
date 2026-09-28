-- =====================================================================
-- Phase 1 : Catalog (หมวดหมู่ + สินค้า)
-- =====================================================================

CREATE TABLE category (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    slug        VARCHAR(100) NOT NULL,
    description VARCHAR(500),
    icon        VARCHAR(100),
    sort_order  INT          NOT NULL DEFAULT 0,
    is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by  VARCHAR(50),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by  VARCHAR(50),
    version     BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT uq_category_slug UNIQUE (slug)
);

CREATE TABLE product (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id    BIGINT        NOT NULL REFERENCES category (id),
    code           VARCHAR(30)   NOT NULL,
    name           VARCHAR(150)  NOT NULL,
    description    VARCHAR(1000),
    price          NUMERIC(10,2) NOT NULL,
    image_url      VARCHAR(500),
    is_available   BOOLEAN       NOT NULL DEFAULT TRUE,
    is_recommended BOOLEAN       NOT NULL DEFAULT FALSE,
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE,
    sort_order     INT           NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    created_by     VARCHAR(50),
    updated_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_by     VARCHAR(50),
    version        BIGINT        NOT NULL DEFAULT 0,
    CONSTRAINT uq_product_code UNIQUE (code),
    CONSTRAINT ck_product_price CHECK (price >= 0)
);

CREATE INDEX ix_product_category ON product (category_id, is_active, sort_order);
CREATE INDEX ix_product_recommended ON product (is_recommended) WHERE is_active AND is_recommended;
