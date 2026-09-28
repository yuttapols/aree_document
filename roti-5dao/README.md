# ร้านโรตี 5 ดาว — System Design

ระบบหน้าร้าน + สมาชิก + สะสมแต้ม + โปรโมชั่น สำหรับร้านโรตี 5 ดาว

## เอกสาร

| # | เอกสาร | เนื้อหา |
|---|--------|---------|
| 1 | [01-overview.md](docs/01-overview.md) | ภาพรวมระบบ, Actor, Tech stack, สถาปัตยกรรม, Business rules |
| 2 | [02-database.md](docs/02-database.md) | ER Diagram, รายละเอียดตาราง, Flyway strategy |
| 3 | [03-backend.md](docs/03-backend.md) | Spring Boot: โครงสร้าง package, common layer, API ทั้งหมด แยก Phase |
| 4 | [04-frontend.md](docs/04-frontend.md) | Angular: โครงสร้าง, Shared components, Routes, หน้าจอ แยก Phase |
| 5 | [05-phase-plan.md](docs/05-phase-plan.md) | แผน 4 Phase FE ↔ BE ที่สอดคล้องกัน + Definition of Done |

## Flyway migrations

อยู่ใน [db/migration](db/migration) — ให้คัดลอกไปไว้ที่ `backend/src/main/resources/db/migration`
ส่วนข้อมูลตัวอย่างสำหรับ dev อยู่ใน [db/seed](db/seed) (เปิดใช้เฉพาะ profile `dev`)

| Version | Phase | ไฟล์ |
|---------|-------|------|
| V1 | 1 | `V1__init_users_and_settings.sql` |
| V2 | 1 | `V2__catalog.sql` |
| V3 | 2 | `V3__product_options_and_images.sql` |
| V4 | 3 | `V4__payment_methods.sql` |
| V5 | 3 | `V5__orders_and_payments.sql` |
| V6 | 4 | `V6__points.sql` |
| V7 | 4 | `V7__promotions.sql` |
| V8 | 4 | `V8__dashboard_views.sql` |

## สรุป 4 Phase

| Phase | ธีม | Backend | Frontend |
|-------|-----|---------|----------|
| 1 | Foundation & Storefront | Project setup, JWT auth, สมัคร/login, API เมนูสาธารณะ | Project setup, Layout, Shared components, Landing, สมัคร/login |
| 2 | Catalog & Profile | CRUD หมวด/สินค้า/ตัวเลือก, อัปโหลดรูป, โปรไฟล์, จัดการผู้ใช้ | หลังบ้านจัดการเมนู, หน้าโปรไฟล์, จัดการพนักงาน |
| 3 | Ordering & Payment | ออเดอร์ (Walk-in/Online), ประเภทการจ่ายเงิน, สลิปโอน | ตะกร้า, Checkout, POS หน้าร้าน, คิวครัว, ติดตามออเดอร์ |
| 4 | Loyalty, Promotion & Dashboard | Point engine, Promotion engine, รายงาน | หน้าแต้ม, โปรโมชั่น, ใช้โค้ด/แลกแต้ม, Dashboard |
