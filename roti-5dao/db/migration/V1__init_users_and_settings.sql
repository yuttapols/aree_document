-- =====================================================================
-- Phase 1 : Users, Auth, Settings
-- =====================================================================

CREATE TABLE app_user (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    phone           VARCHAR(20)  NOT NULL,
    email           VARCHAR(150),
    password_hash   VARCHAR(100) NOT NULL,
    role            VARCHAR(20)  NOT NULL DEFAULT 'CUSTOMER',
    status          VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(50),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by      VARCHAR(50),
    version         BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT uq_app_user_phone UNIQUE (phone),
    CONSTRAINT ck_app_user_role   CHECK (role IN ('CUSTOMER', 'STAFF', 'ADMIN')),
    CONSTRAINT ck_app_user_status CHECK (status IN ('ACTIVE', 'SUSPENDED'))
);

-- email ไม่บังคับ แต่ถ้ามีต้องไม่ซ้ำ (ไม่สนตัวพิมพ์)
CREATE UNIQUE INDEX uq_app_user_email ON app_user (lower(email)) WHERE email IS NOT NULL;

CREATE SEQUENCE member_code_seq START 1;

CREATE TABLE customer_profile (
    user_id         BIGINT       PRIMARY KEY REFERENCES app_user (id) ON DELETE CASCADE,
    member_code     VARCHAR(20)  NOT NULL
                    DEFAULT ('R5D-' || lpad(nextval('member_code_seq')::text, 6, '0')),
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    nickname        VARCHAR(50),
    birth_date      DATE,
    gender          VARCHAR(10),
    avatar_url      VARCHAR(500),
    points_balance  INT          NOT NULL DEFAULT 0,
    lifetime_points INT          NOT NULL DEFAULT 0,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    created_by      VARCHAR(50),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_by      VARCHAR(50),
    version         BIGINT       NOT NULL DEFAULT 0,
    CONSTRAINT uq_customer_profile_member_code UNIQUE (member_code),
    CONSTRAINT ck_customer_profile_points CHECK (points_balance >= 0),
    CONSTRAINT ck_customer_profile_gender CHECK (gender IS NULL OR gender IN ('MALE', 'FEMALE', 'OTHER'))
);

CREATE TABLE refresh_token (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     BIGINT       NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
    token_hash  VARCHAR(128) NOT NULL,
    expires_at  TIMESTAMPTZ  NOT NULL,
    revoked_at  TIMESTAMPTZ,
    user_agent  VARCHAR(300),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);
CREATE INDEX ix_refresh_token_user ON refresh_token (user_id);

CREATE TABLE system_setting (
    setting_key   VARCHAR(100) PRIMARY KEY,
    setting_value VARCHAR(1000) NOT NULL,
    value_type    VARCHAR(20)   NOT NULL DEFAULT 'STRING',
    description   VARCHAR(300),
    updated_at    TIMESTAMPTZ   NOT NULL DEFAULT now(),
    updated_by    VARCHAR(50),
    CONSTRAINT ck_system_setting_type CHECK (value_type IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON'))
);

INSERT INTO system_setting (setting_key, setting_value, value_type, description) VALUES
    ('shop.name',                 'ร้านโรตี 5 ดาว', 'STRING', 'ชื่อร้าน'),
    ('shop.phone',                '',              'STRING', 'เบอร์ร้าน'),
    ('shop.open_time',            '16:00',         'STRING', 'เวลาเปิด'),
    ('shop.close_time',           '23:00',         'STRING', 'เวลาปิด'),
    ('shop.accept_online_order',  'true',          'BOOLEAN','เปิดรับออเดอร์ออนไลน์'),
    ('point.earn_baht_per_point', '25',            'NUMBER', 'ทุกกี่บาทได้ 1 แต้ม'),
    ('point.redeem_points_per_baht','10',          'NUMBER', 'กี่แต้มแลกได้ 1 บาท'),
    ('point.redeem_min_points',   '100',           'NUMBER', 'แลกขั้นต่ำ'),
    ('point.redeem_max_percent',  '50',            'NUMBER', 'ลดด้วยแต้มได้สูงสุด % ของยอด'),
    ('point.expire_days',         '365',           'NUMBER', 'อายุแต้ม (วัน)'),
    ('payment.promptpay_id',      '',              'STRING', 'เบอร์/เลขบัตร PromptPay'),
    ('payment.bank_account',      '',              'STRING', 'บัญชีสำหรับโอน');

-- หมายเหตุ: ไม่ seed บัญชี ADMIN ใน migration (ไม่เก็บรหัสผ่านใน git)
-- AdminBootstrapRunner จะสร้าง ADMIN คนแรกจาก env ROTI_ADMIN_PHONE / ROTI_ADMIN_PASSWORD ถ้ายังไม่มี ADMIN
