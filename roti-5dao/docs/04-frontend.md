# 04 — Frontend Design (Angular + PrimeNG + Tailwind)

## 1. หลักการ

- **Standalone components ทั้งหมด** (ไม่มี NgModule), **Signals** สำหรับ state, **zoneless change detection**, control flow `@if / @for / @defer`
- Lazy load ทุก feature ด้วย `loadChildren` / `loadComponent`
- 3 ชั้น: `core` (singleton, โหลดครั้งเดียว) → `shared` (ใช้ซ้ำ, ไม่รู้จัก feature) → `features` (หน้าจอจริง)
- **Smart / Dumb**: page component (smart) ดึงข้อมูลผ่าน service/store → ส่งให้ shared component (dumb) ผ่าน `input()` / `output()`
- PrimeNG สำหรับ component ซับซ้อน (Table, Dialog, Select, DatePicker, FileUpload, Toast, Chart) + Tailwind สำหรับ layout/spacing
- Model/type ของ API **generate จาก OpenAPI** (`openapi-generator` หรือ `ng-openapi-gen`) → FE/BE ไม่เพี้ยนกัน

## 2. โครงสร้างโฟลเดอร์

```
frontend/src/app/
├── app.config.ts                 # provideZonelessChangeDetection, provideRouter, provideHttpClient(withInterceptors), providePrimeNG
├── app.routes.ts
├── core/                         # ★ singleton
│   ├── api/                      # generated client + ApiResponse<T> unwrap
│   ├── auth/
│   │   ├── auth.store.ts         # signal: currentUser, isLoggedIn, role
│   │   ├── auth.service.ts       # login/register/refresh/logout
│   │   ├── auth.interceptor.ts   # แนบ Bearer, 401 → refresh แล้ว retry 1 ครั้ง
│   │   └── guards.ts             # authGuard, guestOnlyGuard, roleGuard(...roles)
│   ├── http/
│   │   ├── error.interceptor.ts  # map error.code → ข้อความไทย → Toast
│   │   └── loading.interceptor.ts# global loading signal
│   ├── i18n/error-messages.ts    # ErrorCode → ข้อความภาษาไทย
│   ├── layout/
│   │   ├── public-layout/        # Header (โลโก้, เมนู, ตะกร้า, ปุ่มสมาชิก) + Footer
│   │   └── backoffice-layout/    # Sidebar ตาม role + Topbar
│   └── services/
│       ├── shop-info.store.ts    # ข้อมูลร้าน, เปิด/ปิด
│       └── cart.store.ts         # ตะกร้า (signal + persist localStorage) — Phase 3
├── shared/                       # ★ ใช้ซ้ำหลายที่ (ดูข้อ 3)
│   ├── components/
│   ├── pipes/
│   ├── directives/
│   ├── validators/
│   └── models/
└── features/
    ├── landing/                  # Phase 1
    ├── auth/                     # Phase 1  (login, register)
    ├── profile/                  # Phase 2  (+ my-orders Phase 3, points Phase 4)
    ├── admin-catalog/            # Phase 2  (categories, products, option-groups)
    ├── admin-users/              # Phase 2  (customers, staff, settings)
    ├── ordering/                 # Phase 3  (product-detail dialog, cart, checkout, track)
    ├── pos/                      # Phase 3
    ├── kitchen-board/            # Phase 3
    ├── admin-orders/             # Phase 3  (orders, payment verify, payment methods)
    ├── promotions/               # Phase 4  (public list/detail)
    ├── admin-promotions/         # Phase 4
    └── dashboard/                # Phase 4
```

## 3. Shared Components (หัวใจของการ reuse)

| Component / Util | ใช้ที่ | Phase | หมายเหตุ |
|------------------|--------|-------|----------|
| `app-page-header` | ทุกหน้าหลังบ้าน, โปรไฟล์ | 1 | title, subtitle, breadcrumb, slot ปุ่ม action |
| `app-empty-state` | list ทุกหน้า | 1 | icon + ข้อความ + ปุ่ม |
| `app-loading-skeleton` | landing, table, card | 1 | `variant: card \| table \| list` |
| `app-product-card` | Landing, POS, Promotion detail | 1 | `product`, `mode: 'customer' \| 'pos'`, output `add` |
| `app-category-tabs` | Landing, POS | 1 | chip/tabs เลือกหมวด (scroll แนวนอนบนมือถือ) |
| `app-search-box` | Landing, POS, admin list | 1 | debounce 300ms, output `search` |
| `app-form-field` | ทุกฟอร์ม | 1 | label + control + แสดง error อัตโนมัติจาก `FormControl` |
| `app-password-input` | register, login, change password | 1 | ครอบ `p-password` + strength |
| `app-phone-input` | register, POS lookup, checkout guest | 1 | mask `0XX-XXX-XXXX` |
| `money` pipe | ทุกที่ที่แสดงราคา | 1 | `฿1,234.00` |
| `thaiDate` pipe | ออเดอร์, แต้ม, โปร | 1 | พ.ศ. + เวลาไทย |
| `app-image-upload` | สินค้า, avatar, สลิป, banner โปร | 2 | preview, จำกัดขนาด, crop (optional) |
| `app-data-table` | ทุกหน้า list หลังบ้าน | 2 | ครอบ `p-table` lazy paging → emit `PageQuery`, column config, slot action |
| `app-confirm.service` | ลบ, ยกเลิกออเดอร์, ปรับแต้ม | 2 | ครอบ `ConfirmationService` ข้อความไทย |
| `app-status-tag` | order status, payment status, active/inactive, promotion status | 2 | map status → สี/ข้อความ ที่เดียว |
| `app-avatar` | header, โปรไฟล์, รายการลูกค้า | 2 | fallback ตัวอักษรแรก |
| `app-qty-stepper` | cart, POS, product dialog | 3 | − / จำนวน / + |
| `app-option-selector` | product dialog (ลูกค้า), POS | 3 | render option_group ตาม min/max (radio/checkbox) |
| `app-order-summary` | cart, checkout, POS, order detail, receipt | 3 | รายการ + subtotal/ส่วนลด/total (Phase 4 เพิ่มบรรทัดโปร/แต้ม) |
| `app-payment-method-picker` | checkout, POS | 3 | การ์ดเลือกช่องทาง + instruction + QR PromptPay |
| `app-cash-calculator` | POS | 3 | ปุ่มธนบัตร 20/50/100/500/1000 → เงินทอน |
| `app-order-timeline` | track order, order detail | 3 | ใช้ `p-timeline` ตาม status |
| `app-member-lookup` | POS, checkout (staff) | 3 | ใส่เบอร์/สแกน member code → แสดงชื่อ+แต้ม |
| `app-point-badge` | header, profile, POS member lookup | 4 | แสดงแต้มคงเหลือ |
| `app-promo-banner` / `app-promo-card` | landing carousel, หน้าโปร | 4 | |
| `app-promo-code-input` | checkout, POS | 4 | apply/remove + แสดง error |
| `app-point-redeem` | checkout, POS | 4 | slider/input แต้มที่จะใช้ ตามกติกา min/max |
| `app-stat-card` | dashboard, หน้าวันนี้ของพนักงาน | 4 | ตัวเลข + เปรียบเทียบช่วงก่อน |
| `app-date-range-filter` | dashboard, orders, promotion usage | 4 | preset วันนี้/7 วัน/เดือนนี้ |
| `app-chart-card` | dashboard | 4 | ครอบ `p-chart` |

**Base class / util ใช้ซ้ำ**
- `createCrudStore<T>()` — signal store สำหรับหน้า list+form หลังบ้าน (items, loading, query, total, load(), save(), remove()) ใช้กับ category, product, option group, payment method, promotion, staff
- `BaseFormDialog` pattern — dialog ฟอร์ม create/edit ตัวเดียวกัน (`mode: 'create' | 'edit'`)
- `thaiValidators` — `phone`, `passwordStrength`, `match('password')`

## 4. Routes

```ts
export const routes: Routes = [
  { path: '', component: PublicLayout, children: [
      { path: '', loadComponent: () => import('./features/landing/landing.page') },                  // P1
      { path: 'menu/:categorySlug', loadComponent: ... },                                            // P1
      { path: 'login', canActivate: [guestOnlyGuard], loadComponent: ... },                          // P1
      { path: 'register', canActivate: [guestOnlyGuard], loadComponent: ... },                       // P1
      { path: 'profile', canActivate: [authGuard], loadChildren: () => import('./features/profile/routes') }, // P2–4
      { path: 'cart', loadComponent: ... },                                                           // P3
      { path: 'checkout', loadComponent: ... },                                                       // P3
      { path: 'track/:token', loadComponent: ... },                                                   // P3
      { path: 'promotions', loadChildren: ... },                                                      // P4
  ]},
  { path: 'backoffice', component: BackofficeLayout, canActivate: [roleGuard('STAFF', 'ADMIN')], children: [
      { path: '', redirectTo: 'today', pathMatch: 'full' },
      { path: 'today', loadComponent: ... },                                    // P3 (สรุปวันนี้เพิ่ม stat ใน P4)
      { path: 'pos', loadComponent: ... },                                      // P3
      { path: 'kitchen', loadComponent: ... },                                  // P3
      { path: 'orders', loadChildren: ... },                                    // P3
      { path: 'payments/pending', loadComponent: ... },                         // P3
      { path: 'customers', loadChildren: ... },                                 // P2
      { path: 'catalog', canActivate: [roleGuard('ADMIN')], loadChildren: ... },          // P2
      { path: 'staff', canActivate: [roleGuard('ADMIN')], loadChildren: ... },            // P2
      { path: 'settings', canActivate: [roleGuard('ADMIN')], loadChildren: ... },         // P2 (+payment methods P3)
      { path: 'promotions', canActivate: [roleGuard('ADMIN')], loadChildren: ... },       // P4
      { path: 'dashboard', canActivate: [roleGuard('ADMIN')], loadComponent: ... },       // P4
  ]},
  { path: '**', loadComponent: () => import('./shared/components/not-found') },
];
```

## 5. หน้าจอแต่ละ Phase

### Phase 1 — Foundation & Storefront
| หน้า | รายละเอียด | API |
|------|-----------|-----|
| **Landing** | Hero (ชื่อร้าน/เวลาเปิด), เมนูแนะนำ, แท็บหมวดหมู่, grid สินค้า, ค้นหา, ปุ่ม "สมัครสมาชิกรับแต้ม" (ไม่บังคับ) | `/public/menu`, `/public/shop-info` |
| **Login** | เบอร์/อีเมล + รหัสผ่าน, redirect ตาม role (CUSTOMER → `/`, STAFF/ADMIN → `/backoffice`) | `/auth/login` |
| **Register** | ชื่อเล่น, เบอร์, อีเมล (optional), รหัสผ่าน, ยืนยันรหัสผ่าน, ยอมรับเงื่อนไข PDPA | `/auth/register` |
| Layouts | PublicLayout (responsive, mobile-first), BackofficeLayout (placeholder) | `/me` |

Setup: Angular CLI, Tailwind v4 + `tailwindcss-primeui`, PrimeNG theme preset สีแบรนด์ (ส้มทอง/น้ำตาลโรตี), ESLint + Prettier, interceptors, guards, generated API client, env config, Dockerfile (nginx)

### Phase 2 — Catalog & Profile
| หน้า | รายละเอียด |
|------|-----------|
| Profile | ดู/แก้ข้อมูล, อัปโหลด avatar, เปลี่ยนรหัสผ่าน, แสดง member code เป็น QR |
| Backoffice › Categories | ตาราง + drag จัดลำดับ + dialog ฟอร์ม |
| Backoffice › Products | ตาราง paging/filter, ฟอร์มสินค้า (รูป, ราคา, หมวด, แนะนำ, ผูก option group), toggle ของหมด |
| Backoffice › Option Groups | กลุ่ม + รายการตัวเลือก (inline edit) |
| Backoffice › Customers | ค้นหา, ดูข้อมูลสมาชิก, Quick register |
| Backoffice › Staff | เพิ่ม/ระงับพนักงาน, reset password |
| Backoffice › Settings | ข้อมูลร้าน, เวลาเปิด-ปิด |
| Landing (อัปเดต) | Product detail dialog แสดง option groups |

### Phase 3 — Ordering & Payment
| หน้า | รายละเอียด |
|------|-----------|
| Product dialog + Cart | เลือก option/จำนวน/หมายเหตุ → CartStore; หน้าตะกร้าเรียก `/orders/quote` ทุกครั้งที่เปลี่ยน |
| Checkout | ถ้าไม่ login: กรอกชื่อ+เบอร์ (หรือกด login/สมัครเพื่อรับแต้ม), เลือกช่องทางจ่าย, แนบสลิปหรือจ่ายที่ร้าน |
| Track order | สถานะ + เลขคิว + timeline, แนบสลิปภายหลังได้, polling ทุก 10 วินาที |
| Profile › My orders | ประวัติ + รายละเอียด |
| **POS** | ซ้าย: category-tabs + product grid (reuse `app-product-card mode=pos`), ขวา: บิล (`app-order-summary`), `app-member-lookup`, `app-payment-method-picker`, `app-cash-calculator`, พิมพ์ใบเสร็จ |
| Kitchen board | Kanban 3 คอลัมน์ CONFIRMED → PREPARING → READY, ปุ่มเลื่อนสถานะ, เสียงแจ้งเตือนออเดอร์ใหม่ |
| Orders | ตาราง filter วัน/สถานะ/ช่องทาง, รายละเอียด, ยกเลิก |
| Pending payments | ดูรูปสลิป เทียบยอด → อนุมัติ/ปฏิเสธ |
| Settings › Payment methods | เปิด/ปิด, instruction, PromptPay ID |
| Backoffice › Today | จำนวนออเดอร์วันนี้, รอตรวจสลิป, คิวค้าง |

### Phase 4 — Loyalty, Promotion & Dashboard
| หน้า | รายละเอียด |
|------|-----------|
| Profile › Points | ยอดคงเหลือ, แต้มใกล้หมดอายุ, ประวัติ (EARN/REDEEM/EXPIRE) |
| Header | `app-point-badge` |
| Landing (อัปเดต) | Promotion carousel, badge "โปร" บน product card |
| Promotions | รายการ/รายละเอียดโปร |
| Checkout / POS (อัปเดต) | `app-promo-code-input`, `app-point-redeem`, แสดงแต้มที่จะได้รับ |
| Backoffice › Promotions | CRUD, เลือก type → ฟอร์มเปลี่ยนตาม type, เลือกสินค้า/หมวดเป้าหมาย, วันในสัปดาห์, ประวัติการใช้ |
| Backoffice › Customers (อัปเดต) | ประวัติแต้ม + ปรับแต้ม |
| **Dashboard** | stat cards (ยอดขาย, ออเดอร์, ค่าเฉลี่ย/บิล, สมาชิกใหม่), กราฟยอดขาย, top products, สัดส่วนช่องทางจ่าย, ช่วงเวลาขายดี, walk-in vs online, member vs guest |

## 6. State Management

| Store | ชนิด | เก็บ |
|-------|------|------|
| `AuthStore` | signal (core) | user, access token (memory เท่านั้น), role |
| `ShopInfoStore` | signal (core) | ข้อมูลร้าน โหลดครั้งเดียว |
| `CartStore` | signal (core) + localStorage | items, `computed` totalQty, quote result |
| `PosStore` | signal (feature-level provider) | บิลปัจจุบัน, member ที่เลือก, (P4) promo/points |
| Feature list stores | `createCrudStore<T>()` | ต่อหน้า |

> Access token เก็บใน memory, refresh token อยู่ใน HttpOnly cookie → ตอนเปิดเว็บใหม่ `APP_INITIALIZER` เรียก `/auth/refresh` เพื่อกู้ session

## 7. Theming

```css
/* styles.css */
@import "tailwindcss";
@plugin "tailwindcss-primeui";
@layer theme, base, primeng, components, utilities;
```

```ts
// app.config.ts
providePrimeNG({
  theme: { preset: Roti5DaoPreset,           // definePreset(Aura, { semantic: { primary: amber palette } })
           options: { cssLayer: { name: 'primeng', order: 'theme, base, primeng' }, darkModeSelector: '.app-dark' } },
  translation: thLocale,                     // ภาษาไทยสำหรับ DatePicker, Table ฯลฯ
})
```

Font: **Noto Sans Thai** / **IBM Plex Sans Thai**
