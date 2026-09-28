-- =====================================================================
-- DEV ONLY : ข้อมูลเมนูตัวอย่าง (Repeatable migration — รันใหม่เมื่อไฟล์เปลี่ยน)
-- เปิดใช้เฉพาะ profile dev: spring.flyway.locations=classpath:db/migration,classpath:db/seed
-- =====================================================================

INSERT INTO category (name, slug, icon, sort_order, created_by) VALUES
    ('โรตีหวาน',     'sweet-roti',   'pi pi-star',   1, 'seed'),
    ('โรตีคาว',      'savory-roti',  'pi pi-bolt',   2, 'seed'),
    ('มะตะบะ',       'mataba',       'pi pi-box',    3, 'seed'),
    ('เครื่องดื่ม',   'drinks',       'pi pi-filter', 4, 'seed')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO product (category_id, code, name, description, price, is_recommended, sort_order, created_by)
SELECT c.id, v.code, v.name, v.description, v.price, v.recommended, v.sort_order, 'seed'
FROM (VALUES
    ('sweet-roti',  'RT-CLASSIC',  'โรตีนมข้นน้ำตาล', 'โรตีกรอบ ราดนมข้นหวาน โรยน้ำตาล', 30.00, TRUE,  1),
    ('sweet-roti',  'RT-BANANA',   'โรตีกล้วยหอม',     'กล้วยหอมสด ห่อแป้งกรอบ',          45.00, TRUE,  2),
    ('sweet-roti',  'RT-EGG',      'โรตีไข่',          'ใส่ไข่ ราดนมข้น',                  40.00, FALSE, 3),
    ('sweet-roti',  'RT-CHOC',     'โรตีช็อกโกแลต',    'ซอสช็อกโกแลตเข้มข้น',             45.00, FALSE, 4),
    ('savory-roti', 'RT-CURRY',    'โรตีแกงกะหรี่ไก่', 'เสิร์ฟพร้อมแกงกะหรี่ไก่',          60.00, TRUE,  1),
    ('mataba',      'MT-CHICKEN',  'มะตะบะไก่',        'ไส้ไก่ผัดเครื่องเทศ พร้อมอาจาด',   70.00, FALSE, 1),
    ('mataba',      'MT-BEEF',     'มะตะบะเนื้อ',      'ไส้เนื้อ พร้อมอาจาด',              80.00, FALSE, 2),
    ('drinks',      'DK-THAITEA',  'ชาชัก',            'ชาชักสูตรร้าน',                    35.00, TRUE,  1),
    ('drinks',      'DK-MILO',     'ไมโลเย็น',         '',                                  35.00, FALSE, 2)
) AS v(slug, code, name, description, price, recommended, sort_order)
JOIN category c ON c.slug = v.slug
ON CONFLICT (code) DO NOTHING;

-- ตัวเลือก: ท็อปปิ้ง
INSERT INTO option_group (name, min_select, max_select, sort_order, created_by)
SELECT 'ท็อปปิ้งเพิ่ม', 0, 5, 1, 'seed'
WHERE NOT EXISTS (SELECT 1 FROM option_group WHERE name = 'ท็อปปิ้งเพิ่ม');

INSERT INTO option_item (option_group_id, name, extra_price, sort_order)
SELECT g.id, v.name, v.price, v.sort_order
FROM option_group g
CROSS JOIN (VALUES ('ไข่', 10.00, 1), ('กล้วย', 10.00, 2), ('นมข้นเพิ่ม', 5.00, 3), ('ช็อกโกแลต', 10.00, 4), ('ชีส', 15.00, 5))
     AS v(name, price, sort_order)
WHERE g.name = 'ท็อปปิ้งเพิ่ม'
  AND NOT EXISTS (SELECT 1 FROM option_item oi WHERE oi.option_group_id = g.id AND oi.name = v.name);

INSERT INTO product_option_group_map (product_id, option_group_id)
SELECT p.id, g.id
FROM product p
JOIN category c ON c.id = p.category_id AND c.slug = 'sweet-roti'
CROSS JOIN option_group g
WHERE g.name = 'ท็อปปิ้งเพิ่ม'
ON CONFLICT DO NOTHING;
