# 03 — Backend Design (Spring Boot)

## 1. โครงสร้างโปรเจกต์ (package-by-feature)

```
backend/
├── build.gradle.kts            # หรือ pom.xml
├── src/main/java/com/roti5dao/
│   ├── Roti5DaoApplication.java
│   ├── common/                         # ★ ใช้ร่วมทุก module
│   │   ├── config/                     # JacksonConfig, OpenApiConfig, CorsConfig, JpaAuditConfig, ClockConfig
│   │   ├── security/                   # SecurityConfig, JwtService, JwtAuthFilter, CurrentUser, @CurrentUserId
│   │   ├── entity/                     # BaseEntity, AuditableEntity
│   │   ├── web/                        # ApiResponse<T>, PageResponse<T>, PageQuery, GlobalExceptionHandler
│   │   ├── exception/                  # BusinessException, NotFoundException, ErrorCode (enum)
│   │   ├── storage/                    # FileStorageService (interface), LocalFileStorage, S3FileStorage
│   │   ├── setting/                    # SystemSettingService (cache), SettingKey
│   │   ├── sequence/                   # DailyCounterService → order_no, queue_no
│   │   └── util/                       # MoneyUtils, PhoneUtils, DateTimeUtils
│   ├── auth/                           # Phase 1
│   ├── user/                           # Phase 1–2 (profile, staff)
│   ├── catalog/                        # Phase 1–2 (category, product, option)
│   ├── payment/                        # Phase 3 (payment_method, payment)
│   ├── order/                          # Phase 3
│   ├── point/                          # Phase 4
│   ├── promotion/                      # Phase 4
│   └── dashboard/                      # Phase 4
└── src/main/resources/
    ├── application.yml / application-dev.yml / application-prod.yml
    └── db/migration, db/seed
```

แต่ละ feature module มีโครงสร้างเดียวกัน:

```
catalog/
├── api/            # Controllers: PublicCatalogController, AdminProductController
├── dto/            # record: ProductResponse, ProductUpsertRequest, ...
├── entity/         # Product, Category (extends AuditableEntity)
├── repository/     # Spring Data JPA
├── mapper/         # MapStruct: ProductMapper
└── service/        # ProductService (interface ที่ module อื่นเรียกได้) + impl
```

**กติกา**: module อื่นเรียกผ่าน `service` เท่านั้น ห้าม inject repository ข้าม module (เช่น `order` เรียก `ProductQueryService.getForOrder(ids)` ไม่ใช่ `ProductRepository`)

## 2. Common Layer (ทำใน Phase 1 ใช้ถึง Phase 4)

### 2.1 Response มาตรฐาน

```java
public record ApiResponse<T>(boolean success, T data, ApiError error, Instant timestamp) {
    public static <T> ApiResponse<T> ok(T data) { ... }
    public static ApiResponse<Void> fail(ErrorCode code, String message, List<FieldError> fields) { ... }
}
public record ApiError(String code, String message, List<FieldError> fields) {}
public record PageResponse<T>(List<T> items, int page, int size, long totalItems, int totalPages) {
    public static <E, T> PageResponse<T> of(Page<E> page, Function<E, T> mapper) { ... }
}
```

```json
{ "success": false, "data": null,
  "error": { "code": "POINT_INSUFFICIENT", "message": "แต้มไม่พอ", "fields": [] },
  "timestamp": "2026-09-25T10:00:00Z" }
```

### 2.2 ErrorCode (enum รวม — FE ใช้ map ข้อความ)

| Code | HTTP | Phase |
|------|------|-------|
| `VALIDATION_ERROR` | 400 | 1 |
| `UNAUTHORIZED`, `TOKEN_EXPIRED`, `INVALID_CREDENTIALS` | 401 | 1 |
| `FORBIDDEN` | 403 | 1 |
| `NOT_FOUND` | 404 | 1 |
| `PHONE_ALREADY_USED`, `EMAIL_ALREADY_USED` | 409 | 1 |
| `CONCURRENT_UPDATE` (OptimisticLock) | 409 | 1 |
| `PRODUCT_UNAVAILABLE`, `OPTION_INVALID` | 422 | 3 |
| `ORDER_INVALID_STATUS`, `PAYMENT_AMOUNT_MISMATCH`, `SLIP_REQUIRED` | 422 | 3 |
| `POINT_INSUFFICIENT`, `POINT_BELOW_MIN`, `POINT_EXCEED_LIMIT` | 422 | 4 |
| `PROMOTION_NOT_FOUND`, `PROMOTION_EXPIRED`, `PROMOTION_NOT_ELIGIBLE`, `PROMOTION_LIMIT_REACHED` | 422 | 4 |

### 2.3 Entity base

```java
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class AuditableEntity {
    @CreatedDate  Instant createdAt;
    @CreatedBy    String  createdBy;
    @LastModifiedDate Instant updatedAt;
    @LastModifiedBy   String  updatedBy;
    @Version      Long    version;
}
```

### 2.4 Shared services

| Service | หน้าที่ | ใช้ที่ |
|---------|---------|--------|
| `FileStorageService` | `store(MultipartFile, folder) → url`, ตรวจชนิด/ขนาดไฟล์ | product image, avatar, slip, promotion banner |
| `SystemSettingService` | อ่านค่า setting + cache (Caffeine), `getInt(SettingKey)` | point, shop info, payment |
| `DailyCounterService` | `next(date, "ORDER")` ด้วย `INSERT ... ON CONFLICT DO UPDATE ... RETURNING` | order_no, queue_no |
| `CurrentUser` | ดึง userId/role จาก SecurityContext | ทุก controller `/me/**` |
| `Clock` bean | ทดสอบเวลาได้ (โปร/แต้มหมดอายุ) | promotion, point |

### 2.5 Security

- `JwtAuthFilter` อ่าน `Authorization: Bearer` → set `Authentication`
- Access token 15 นาที (claims: `sub=userId`, `role`), Refresh token 14 วัน เก็บ SHA-256 hash ใน `refresh_token`, **rotate ทุกครั้งที่ refresh**
- Refresh token ส่งเป็น **HttpOnly Secure cookie** (path `/api/v1/auth`) — ปลอดภัยกว่าเก็บใน localStorage
- Rule:

```java
http.authorizeHttpRequests(a -> a
    .requestMatchers("/api/v1/auth/**", "/api/v1/public/**", "/files/**", "/v3/api-docs/**", "/swagger-ui/**").permitAll()
    .requestMatchers("/api/v1/me/**").authenticated()
    .requestMatchers("/api/v1/admin/**").hasAnyRole("STAFF", "ADMIN")
    .anyRequest().authenticated());
// endpoint ที่เฉพาะ ADMIN ใช้ @PreAuthorize("hasRole('ADMIN')")
```

- Rate limit (Bucket4j) ที่ `/auth/login`, `/auth/register`, `/public/orders`

## 3. API แยกตาม Phase

> ทุก path ขึ้นต้น `/api/v1` · 🌐 = public · 👤 = login แล้ว · 🧑‍🍳 = STAFF/ADMIN · 👑 = ADMIN

### Phase 1 — Foundation, Auth, Public Catalog

| Method | Path | สิทธิ์ | คำอธิบาย |
|--------|------|--------|----------|
| POST | `/auth/register` | 🌐 | สมัครสมาชิก (phone, password, nickname, email?) → สร้าง `app_user` + `customer_profile` |
| POST | `/auth/login` | 🌐 | `{ username (phone/email), password }` → access token + refresh cookie |
| POST | `/auth/refresh` | 🌐 (cookie) | ออก token ใหม่ |
| POST | `/auth/logout` | 👤 | revoke refresh token |
| GET | `/me` | 👤 | ข้อมูลผู้ใช้ปัจจุบัน (id, role, nickname, memberCode, pointsBalance) |
| GET | `/public/shop-info` | 🌐 | ชื่อร้าน เวลาเปิด-ปิด เปิดรับออนไลน์ไหม |
| GET | `/public/categories` | 🌐 | หมวดที่ active เรียงตาม sort_order |
| GET | `/public/products?categoryId=&keyword=&recommended=` | 🌐 | รายการสินค้า |
| GET | `/public/products/{id}` | 🌐 | รายละเอียดสินค้า (+ option groups ตั้งแต่ Phase 2) |
| GET | `/public/menu` | 🌐 | หมวด + สินค้าในหมวด (ยิงครั้งเดียวสำหรับ landing) |

**งานอื่นใน Phase 1**: project skeleton, common layer ทั้งหมด, Flyway V1–V2 + seed, `AdminBootstrapRunner`, OpenAPI, Docker Compose, CI (build + test Testcontainers)

### Phase 2 — Catalog Management, Profile, Users

| Method | Path | สิทธิ์ | คำอธิบาย |
|--------|------|--------|----------|
| GET/PUT | `/me/profile` | 👤 | ดู/แก้โปรไฟล์ |
| POST | `/me/profile/avatar` | 👤 | อัปโหลดรูป (multipart) |
| PUT | `/me/password` | 👤 | เปลี่ยนรหัสผ่าน (revoke refresh token อื่นทั้งหมด) |
| GET/POST | `/admin/categories` | 👑 | list / create |
| PUT/DELETE | `/admin/categories/{id}` | 👑 | update / soft delete |
| PATCH | `/admin/categories/sort` | 👑 | จัดลำดับ `[{id, sortOrder}]` |
| GET | `/admin/products?page=&size=&categoryId=&keyword=&active=` | 🧑‍🍳 | list แบบ paging |
| POST/PUT/DELETE | `/admin/products[/{id}]` | 👑 | CRUD |
| PATCH | `/admin/products/{id}/availability` | 🧑‍🍳 | ของหมด/มีของ (พนักงานกดได้) |
| POST | `/admin/products/{id}/images` | 👑 | อัปโหลดรูป |
| GET/POST/PUT/DELETE | `/admin/option-groups[/{id}]` | 👑 | จัดการกลุ่มตัวเลือก + items (nested) |
| PUT | `/admin/products/{id}/option-groups` | 👑 | ผูก option group กับสินค้า |
| GET | `/admin/customers?keyword=` | 🧑‍🍳 | ค้นหาสมาชิก |
| GET | `/admin/customers/lookup?phone=` | 🧑‍🍳 | ค้นด้วยเบอร์ (ใช้ที่ POS) |
| POST | `/admin/customers/quick-register` | 🧑‍🍳 | สมัครให้ลูกค้าหน้าร้าน |
| GET/POST/PUT | `/admin/staff[/{id}]` | 👑 | จัดการพนักงาน |
| GET/PUT | `/admin/settings` | 👑 | ตั้งค่าร้าน |
| POST | `/files` → GET `/files/**` | 👤 / 🌐 | อัปโหลด/เสิร์ฟไฟล์ (FileStorageService) |

### Phase 3 — Ordering & Payment

| Method | Path | สิทธิ์ | คำอธิบาย |
|--------|------|--------|----------|
| GET | `/public/payment-methods?channel=ONLINE` | 🌐 | ช่องทางที่ลูกค้าเลือกได้ + instruction/QR |
| POST | `/public/orders/quote` | 🌐 | คำนวณราคาจากตะกร้า (ไม่บันทึก) — FE ใช้แสดงยอด |
| POST | `/public/orders` | 🌐/👤 | สร้างออเดอร์ ONLINE (guest ต้องส่ง name+phone, login แล้วผูก customer อัตโนมัติ) |
| GET | `/public/orders/track/{trackingToken}` | 🌐 | ติดตามสถานะ + เลขคิว |
| POST | `/public/orders/track/{trackingToken}/payments` | 🌐 | แนบสลิป (multipart) |
| GET | `/me/orders?page=` | 👤 | ประวัติออเดอร์ |
| GET | `/me/orders/{orderNo}` | 👤 | รายละเอียด |
| GET/POST/PUT | `/admin/payment-methods[/{id}]` | 👑 | จัดการประเภทการจ่ายเงิน |
| POST | `/admin/orders` | 🧑‍🍳 | POS: เปิดบิล WALK_IN (+ `customerPhone?`) |
| POST | `/admin/orders/{id}/payments` | 🧑‍🍳 | รับเงิน (CASH: cashReceived → คำนวณเงินทอน) |
| PATCH | `/admin/payments/{id}/verify` | 🧑‍🍳 | `{approve: true/false, rejectReason}` ตรวจสลิป |
| GET | `/admin/payments?status=PENDING` | 🧑‍🍳 | รายการรอตรวจสลิป |
| GET | `/admin/orders?status=&channel=&date=&page=` | 🧑‍🍳 | รายการออเดอร์ |
| GET | `/admin/orders/board` | 🧑‍🍳 | คิวครัว (CONFIRMED/PREPARING/READY วันนี้) |
| PATCH | `/admin/orders/{id}/status` | 🧑‍🍳 | เปลี่ยนสถานะตาม state machine |
| POST | `/admin/orders/{id}/cancel` | 🧑‍🍳 | ยกเลิก (+ reason) |
| GET | `/admin/orders/{id}/receipt` | 🧑‍🍳 | ข้อมูลใบเสร็จสำหรับพิมพ์ |

**ออกแบบภายใน order module**

```
OrderService.create(CreateOrderCommand)
  └─ PricingService.calculate(cart, customer, channel, promoCode, redeemPoints)   ← Phase 3 มีแค่ SubtotalStep
        └─ List<PricingStep> (เรียงตาม @Order)
             1. SubtotalStep         (Phase 3)  ราคาสินค้า + option, ตรวจ available
             2. PromotionStep        (Phase 4)  เรียก PromotionService.evaluate()
             3. PointRedeemStep      (Phase 4)  เรียก PointService.previewRedeem()
             4. PointEarnPreviewStep (Phase 4)  คำนวณแต้มที่จะได้ (รวม multiplier)
  └─ OrderStatusMachine.transition(order, target)   ← กำหนด transition ที่อนุญาตไว้ที่เดียว
  └─ publish OrderCompletedEvent / OrderCancelledEvent  (Spring ApplicationEvent)
```

> Phase 3 วาง `PricingStep` interface + event ไว้ก่อน → Phase 4 เพิ่ม step/listener ใหม่ **โดยไม่ต้องแก้ OrderService**

- ใช้ `quote` และ `create` ผ่าน `PricingService` ตัวเดียวกัน → ราคาที่ FE แสดงตรงกับที่บันทึกเสมอ (BE คำนวณใหม่ทุกครั้ง ไม่เชื่อราคาจาก FE)
- การยืนยันชำระเงิน: เมื่อ `sum(payment PAID) >= total_amount` → order `CONFIRMED`
- Realtime คิวครัว: Phase 3 ใช้ polling 5 วินาที (ง่าย) → อัปเกรดเป็น SSE `/admin/orders/stream` ได้ภายหลัง

### Phase 4 — Points, Promotions, Dashboard

| Method | Path | สิทธิ์ | คำอธิบาย |
|--------|------|--------|----------|
| GET | `/me/points` | 👤 | ยอดคงเหลือ + แต้มใกล้หมดอายุ (30 วัน) |
| GET | `/me/points/transactions?page=` | 👤 | ประวัติแต้ม |
| GET | `/public/promotions` | 🌐 | โปรที่ `show_on_landing` และยังไม่หมดอายุ |
| GET | `/public/promotions/{id}` | 🌐 | รายละเอียด |
| POST | `/public/promotions/validate` | 🌐/👤 | ตรวจโค้ดกับตะกร้า (หรือใช้ผ่าน `/orders/quote` field `promoCode`) |
| GET/POST/PUT/DELETE | `/admin/promotions[/{id}]` | 👑 | CRUD + targets |
| GET | `/admin/promotions/{id}/usages` | 👑 | ประวัติการใช้ |
| POST | `/admin/customers/{id}/points/adjust` | 👑 | ปรับแต้ม (+/−, remark บังคับ) |
| GET | `/admin/customers/{id}/points/transactions` | 🧑‍🍳 | ดูประวัติแต้มลูกค้า |
| GET | `/admin/dashboard/summary?from=&to=` | 👑 | ยอดขาย, จำนวนออเดอร์, ค่าเฉลี่ยต่อบิล, สมาชิกใหม่, แต้มที่ออก/ใช้ |
| GET | `/admin/dashboard/sales-trend?from=&to=&groupBy=DAY\|WEEK\|MONTH` | 👑 | กราฟยอดขาย |
| GET | `/admin/dashboard/top-products?from=&to=&limit=10` | 👑 | สินค้าขายดี |
| GET | `/admin/dashboard/payment-methods?from=&to=` | 👑 | สัดส่วนช่องทางจ่ายเงิน |
| GET | `/admin/dashboard/hourly?date=` | 👑 | ช่วงเวลาขายดี |
| GET | `/admin/dashboard/today` | 🧑‍🍳 | สรุปวันนี้ (สำหรับหน้าแรกพนักงาน) |

(Quote/Create order จาก Phase 3 เพิ่ม field `promoCode`, `redeemPoints` และ response เพิ่ม `promotionDiscount`, `pointDiscount`, `pointsToEarn`, `appliedPromotions[]`)

**Point module**
- `PointService.earn(orderId)` — listener ของ `OrderCompletedEvent`: `floor(total / earnBahtPerPoint) × multiplier` → insert EARN (`remaining = points`, `expires_at = now + expireDays`), อัปเดต `points_balance` / `lifetime_points` (optimistic lock)
- `PointService.redeem(customerId, orderId, points)` — ตัดจากก้อน EARN ที่ใกล้หมดอายุก่อน (FIFO ด้วย `remaining`)
- `PointService.reverse(orderId)` — listener ของ `OrderCancelledEvent`: คืนแต้มที่แลก + ดึงแต้มที่ได้
- `PointExpiryJob` — `@Scheduled(cron = "0 5 0 * * *", zone = "Asia/Bangkok")` สร้าง EXPIRE สำหรับก้อนที่หมดอายุ (ใช้ ShedLock ถ้ารันหลาย instance)

**Promotion module**
- `PromotionService.evaluate(PricingContext)` → หาโปรที่ใช้ได้ (active, ช่วงเวลา, วัน, channel, member_only, min amount, limit) → เลือกตัวที่ให้ส่วนลดมากสุด / priority สูงสุด + ซ้อน `POINT_MULTIPLIER`
- Strategy pattern: `DiscountCalculator` ต่อ type (`PercentCalculator`, `FixedAmountCalculator`, `BuyXGetYCalculator`, `PointMultiplierCalculator`)
- ตอนสร้างออเดอร์: `UPDATE promotion SET used_count = used_count + 1 WHERE id = ? AND (usage_limit IS NULL OR used_count < usage_limit)` → ถ้า 0 row = `PROMOTION_LIMIT_REACHED`

**Dashboard module** — query จาก view V8 ผ่าน `JdbcClient` (read-only, ไม่ต้องใช้ entity)

## 4. Testing ต่อ Phase

| ประเภท | เครื่องมือ | ขอบเขต |
|--------|-----------|--------|
| Unit | JUnit 5 + Mockito | PricingService, calculators, OrderStatusMachine, PointService |
| Slice | `@WebMvcTest` | Validation, security rule ต่อ endpoint |
| Integration | `@SpringBootTest` + Testcontainers PostgreSQL | Flyway migrate + repository + flow ออเดอร์→จ่าย→แต้ม |
| Contract | OpenAPI snapshot | FE generate client จาก `/v3/api-docs` |
