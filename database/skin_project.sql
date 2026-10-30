-- Cosmetics management: readable string keys + scoped sequences + 1:1 inbound batches (2026-10-23)
-- Target: MySQL 8.0.16+ (CHECK constraints enforced)
-- New database schema; does NOT migrate existing tables/data.
-- All entity/history IDs are readable strings (no numeric PKs, no AUTO_INCREMENT).
-- ID values are allocated in FastAPI under transaction, NEVER from MAX(id)+1.
-- Relationship-to-table translation:
--   카테고리(relationship attributes) -> categories lookup + cosmetics.category_id
--   제조하다/보유하다/주문하다/생성하다 -> parent foreign keys
--   갱신하다 x6 -> six change-history tables, not an undifferentiated log
--   출고하다 -> stock_outbounds relationship with quantity/date
--   입고하다 -> inbound_history referencing stock + purchase order
--   발주하다 -> purchase_orders referencing approval + manufacturer
--   요청하다 -> approvals.cosmetic_id (explicit prior user requirement)
-- A single inbound history row corresponds to a single uniquely keyed inventory batch.

-- Human-readable key rules and examples (do NOT use display names as mutable foreign keys):
-- manufacturers.manufacturer_id   = mfr_<lowercase_ascii_slug>   e.g. mfr_example_beauty
-- categories.category_id         = cat_<lowercase_ascii_slug>   e.g. cat_skincare
-- carriers.carrier_id            = car_<lowercase_ascii_slug>   e.g. car_demo_express
-- cosmetics.cosmetic_id          = <manufacturer_id>_<category_id>_<name_seq>_<type_seq>
-- approvals.approval_id          = pa_<cosmetic_id>_<approval_seq>
-- purchase_orders ID            = <approval_id>_<purchase_order_seq>
-- inbound_history ID            = <purchase_order_id>_<inbound_seq>
-- product_inventory ID          = inv_<inbound_id>
-- Other history/event IDs        = <typed-prefix>_<application-assigned-seq>
--   e.g. rev_1, reg_1, dec_1, csh_1, ash_1, vol_1, prc_1, sls_1, cst_1, min_1, tgt_1
-- Note: seller/manufacturer/category IDs are immutable stable slugs. Change label, not ID.
-- Avoid reusing an ID after deletion; use transactional id_counters per scope.

SET NAMES utf8mb4;
CREATE DATABASE IF NOT EXISTS cosmetics_management
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE cosmetics_management;

-- 01. 고객
CREATE TABLE customers (
  customer_id    VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '회원 번호',
  login_id       VARCHAR(50) NOT NULL COMMENT '아이디',
  password_hash  VARCHAR(255) NOT NULL COMMENT '비밀번호 해시: 원문 저장 금지',
  customer_name  VARCHAR(100) NOT NULL COMMENT '이름',
  gender         ENUM('M','F','OTHER','UNDISCLOSED') NULL COMMENT '성별',
  email          VARCHAR(255) NOT NULL COMMENT '이메일',
  phone          VARCHAR(30) NOT NULL COMMENT '전화번호',
  address        VARCHAR(500) NULL COMMENT '주소',
  points_balance INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '보유 마일리지',
  PRIMARY KEY (customer_id),
  CONSTRAINT chk_customers_id CHECK (CHAR_LENGTH(TRIM(customer_id)) > 0),
  UNIQUE KEY uq_customers_login (login_id),
  UNIQUE KEY uq_customers_email (email)
) ENGINE=InnoDB COMMENT='고객';

-- 02. 직원
CREATE TABLE employees (
  employee_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  login_id      VARCHAR(50) NOT NULL COMMENT '아이디',
  password_hash VARCHAR(255) NOT NULL COMMENT '비밀번호 해시',
  employee_name VARCHAR(100) NOT NULL COMMENT '이름',
  phone         VARCHAR(30) NULL COMMENT '전화번호',
  job_title     VARCHAR(100) NULL COMMENT '직책',
  employee_role ENUM('STAFF','ADMIN') NOT NULL DEFAULT 'STAFF' COMMENT '현재 권한. 승진해도 employee_id 변경 금지',
  key_role ENUM('staff','manager') NOT NULL COMMENT 'ID 생성 당시의 역할. 변경 불가',
  employee_seq BIGINT UNSIGNED NOT NULL COMMENT '역할별 직원 순번',
  hired_on      DATE NOT NULL COMMENT '입사일',
  PRIMARY KEY (employee_id),
  UNIQUE KEY uq_employees_role_seq (key_role, employee_seq),
  CONSTRAINT chk_employees_seq CHECK (employee_seq > 0),
  CONSTRAINT chk_employees_key CHECK (employee_id = CONCAT('E_', key_role, '_', employee_seq)),
  UNIQUE KEY uq_employees_login (login_id)
) ENGINE=InnoDB COMMENT='직원';

-- 03. 제조사
CREATE TABLE manufacturers (
  manufacturer_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '제조사 식별자',
  manufacturer_name VARCHAR(150) NOT NULL COMMENT '제조사명',
  phone             VARCHAR(30) NULL COMMENT '연락처',
  PRIMARY KEY (manufacturer_id),
  CONSTRAINT chk_manufacturers_key CHECK (manufacturer_id REGEXP '^mfr_[a-z0-9]+(_[a-z0-9]+)*$'),
  UNIQUE KEY uq_manufacturers_name (manufacturer_name)
) ENGINE=InnoDB COMMENT='제조사';

-- 04. 카테고리: ERD에서는 관계의 속성이지만, 중복 이름과 코드 관리를 위해 정규화
CREATE TABLE categories (
  category_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '카테고리 식별자',
  category_name VARCHAR(100) NOT NULL COMMENT '카테고리명',
  PRIMARY KEY (category_id),
  CONSTRAINT chk_categories_key CHECK (category_id REGEXP '^cat_[a-z0-9]+(_[a-z0-9]+)*$'),
  UNIQUE KEY uq_categories_name (category_name)
) ENGINE=InnoDB COMMENT='카테고리 관계 속성의 정규화';

-- 05. 화장품 (현재 용량/가격 등의 변경 이력은 아래 각 갱신 관계 테이블에서 관리)
CREATE TABLE cosmetics (
  cosmetic_id     VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  cosmetic_name   VARCHAR(200) NOT NULL COMMENT '상품명',
  manufacturer_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '제조하다: 제조사 식별자',
  category_id     VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '카테고리 관계: 카테고리 식별자',
  cosmetic_name_seq INT UNSIGNED NOT NULL COMMENT '제조사+카테고리 내 이름 표시용 순번',
  cosmetic_type_seq INT UNSIGNED NOT NULL COMMENT '동일 이름 묶음의 종류 표시용 순번',
  PRIMARY KEY (cosmetic_id),
  UNIQUE KEY uq_cosmetic_components (manufacturer_id, category_id, cosmetic_name_seq, cosmetic_type_seq),
  CONSTRAINT chk_cosmetics_seqs CHECK (cosmetic_name_seq > 0 AND cosmetic_type_seq > 0),
  CONSTRAINT chk_cosmetics_key CHECK (cosmetic_id = CONCAT(manufacturer_id, '_', category_id, '_', cosmetic_name_seq, '_', cosmetic_type_seq)),
  KEY ix_cosmetics_manufacturer (manufacturer_id),
  KEY ix_cosmetics_category (category_id),
  CONSTRAINT fk_cosmetics_manufacturer FOREIGN KEY (manufacturer_id) REFERENCES manufacturers (manufacturer_id),
  CONSTRAINT fk_cosmetics_category FOREIGN KEY (category_id) REFERENCES categories (category_id)
) ENGINE=InnoDB COMMENT='화장품';

-- 06. 상품 재고: cosmetic_id is NOT UNIQUE; same cosmetic can have multiple batches.
CREATE TABLE product_inventory (
  inventory_id      VARCHAR(280) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '재고 번호',
  cosmetic_id       VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '보유하다: 상품 번호',
  stock_quantity    INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '재고 수량',
  received_on       DATE NOT NULL COMMENT '입고일',
  expires_on        DATE NULL COMMENT '사용기한',
  inventory_status  ENUM('MAINTAIN','HOLD','DISCARD') NOT NULL DEFAULT 'MAINTAIN'
                    COMMENT '재고 상태 유지/보류/폐기',
  sale_option       ENUM('NORMAL','NEAR_EXPIRY') NOT NULL DEFAULT 'NORMAL'
                    COMMENT '판매 옵션 일반/임박',
  PRIMARY KEY (inventory_id),
  CONSTRAINT chk_inventory_key CHECK (inventory_id REGEXP '^inv_pa_mfr_[a-z0-9_]+_cat_[a-z0-9_]+_[1-9][0-9]*_[1-9][0-9]*_[1-9][0-9]*_[1-9][0-9]*_[1-9][0-9]*$'),
  KEY ix_inventory_cosmetic (cosmetic_id),
  KEY ix_inventory_expiry (expires_on),
  CONSTRAINT fk_inventory_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT chk_inventory_expiry CHECK (expires_on IS NULL OR expires_on >= received_on)
) ENGINE=InnoDB COMMENT='상품 재고: 재고 단위별 수량, 사용기한, 상태';

-- 07. 주문
CREATE TABLE orders (
  order_id         VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '주문 번호',
  customer_id      VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '주문하다: 회원 번호',
  order_seq BIGINT UNSIGNED NOT NULL COMMENT '주문 전역 순번',
  order_status     ENUM('PENDING','PAID','PREPARING','SHIPPED','DELIVERED','CANCELLED','RETURNED')
                   NOT NULL DEFAULT 'PENDING' COMMENT '주문 상태',
  ordered_at       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '주문 일시',
  shipping_address VARCHAR(500) NOT NULL COMMENT '배송지 주소',
  PRIMARY KEY (order_id),
  UNIQUE KEY uq_orders_seq (order_seq),
  CONSTRAINT chk_orders_seq CHECK (order_seq > 0),
  CONSTRAINT chk_orders_key CHECK (order_id = CONCAT('ord_', order_seq)),
  KEY ix_orders_customer (customer_id),
  CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB COMMENT='주문';

-- 08. 배송업체
CREATE TABLE carriers (
  carrier_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '배송업체 식별자',
  carrier_name VARCHAR(150) NOT NULL COMMENT '배송업체명',
  phone        VARCHAR(30) NULL COMMENT '전화번호',
  PRIMARY KEY (carrier_id),
  CONSTRAINT chk_carriers_key CHECK (carrier_id REGEXP '^car_[a-z0-9]+(_[a-z0-9]+)*$'),
  UNIQUE KEY uq_carriers_name (carrier_name)
) ENGINE=InnoDB COMMENT='배송업체';

-- 09. 배송 정보: 하나의 주문에 여러 배송 건을 허용(분할 배송)
CREATE TABLE delivery_information (
  delivery_id     VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '배송 번호',
  order_id        VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '생성하다: 주문 번호',
  delivery_seq INT UNSIGNED NOT NULL COMMENT '주문별 배송 순번',
  carrier_id      VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '배송하다: 배송업체 식별자',
  shipped_at      DATETIME NULL COMMENT '출발 일시',
  arrived_at      DATETIME NULL COMMENT '도착 일시',
  delivery_status ENUM('READY','IN_TRANSIT','DELIVERED','FAILED','RETURNING')
                  NOT NULL DEFAULT 'READY' COMMENT '배송 상태',
  PRIMARY KEY (delivery_id),
  UNIQUE KEY uq_delivery_order_seq (order_id, delivery_seq),
  CONSTRAINT chk_delivery_seq CHECK (delivery_seq > 0),
  CONSTRAINT chk_delivery_key CHECK (delivery_id = CONCAT('dlv_', order_id, '_', delivery_seq)),
  KEY ix_delivery_order (order_id),
  KEY ix_delivery_carrier (carrier_id),
  CONSTRAINT fk_delivery_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_delivery_carrier FOREIGN KEY (carrier_id) REFERENCES carriers (carrier_id),
  CONSTRAINT chk_delivery_chronology CHECK (arrived_at IS NULL OR shipped_at IS NULL OR arrived_at >= shipped_at)
) ENGINE=InnoDB COMMENT='배송 정보';

-- 10. 품의: 화장품과 직접 외래키 연결 (이전 추가 요구 반영)
CREATE TABLE approvals (
  approval_id      VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '품의 번호',
  cosmetic_id      VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '요청하다: 화장품 번호',
  approval_seq INT UNSIGNED NOT NULL COMMENT '화장품별 품의 순번',
  target_stock_snapshot INT UNSIGNED NOT NULL COMMENT '품의 시점 목표 재고',
  current_stock_snapshot INT UNSIGNED NOT NULL COMMENT '품의 시점 현재 재고(판매 가능 수량)',
  requested_quantity INT UNSIGNED NOT NULL COMMENT '목표 재고 - 현재 재고 수량',
  approval_content VARCHAR(500) NOT NULL COMMENT '품의 내용',
  requested_on     DATE NOT NULL COMMENT '품의 날짜',
  PRIMARY KEY (approval_id),
  UNIQUE KEY uq_approvals_cosmetic_seq (cosmetic_id, approval_seq),
  CONSTRAINT chk_approvals_seq CHECK (approval_seq > 0),
  CONSTRAINT chk_approvals_key CHECK (approval_id = CONCAT('pa_', cosmetic_id, '_', approval_seq)),
  CONSTRAINT chk_approvals_deficit CHECK (target_stock_snapshot > current_stock_snapshot AND requested_quantity = target_stock_snapshot - current_stock_snapshot),
  KEY ix_approvals_cosmetic (cosmetic_id),
  CONSTRAINT fk_approvals_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id)
) ENGINE=InnoDB COMMENT='품의: 화장품 요청';

-- 11. 발주하다: 제조사/품의와 연결하는 관계 테이블
CREATE TABLE purchase_orders (
  purchase_order_id VARCHAR(230) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '발주 번호',
  approval_id       VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '품의 번호',
  purchase_order_seq INT UNSIGNED NOT NULL COMMENT '품의별 발주 순번',
  manufacturer_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '제조사 식별자',
  ordered_on        DATE NOT NULL COMMENT '발주 날짜',
  order_quantity    INT UNSIGNED NOT NULL COMMENT '발주 수량',
  purchase_status   ENUM('REQUESTED','ORDERED','PARTIALLY_RECEIVED','RECEIVED','CANCELLED')
                    NOT NULL DEFAULT 'REQUESTED' COMMENT '발주 상태',
  unit_supply_price DECIMAL(12,2) UNSIGNED NOT NULL COMMENT '공급 단가',
  order_total_amount DECIMAL(14,2) UNSIGNED NOT NULL COMMENT '발주 총금액',
  PRIMARY KEY (purchase_order_id),
  UNIQUE KEY uq_purchase_orders_approval_seq (approval_id, purchase_order_seq),
  CONSTRAINT chk_po_seq CHECK (purchase_order_seq > 0),
  CONSTRAINT chk_po_key CHECK (purchase_order_id = CONCAT(approval_id, '_', purchase_order_seq)),
  KEY ix_purchase_orders_approval (approval_id),
  KEY ix_purchase_orders_manufacturer (manufacturer_id),
  CONSTRAINT fk_purchase_orders_approval FOREIGN KEY (approval_id) REFERENCES approvals (approval_id),
  CONSTRAINT fk_purchase_orders_manufacturer FOREIGN KEY (manufacturer_id) REFERENCES manufacturers (manufacturer_id),
  CONSTRAINT chk_purchase_order_quantity CHECK (order_quantity > 0)
) ENGINE=InnoDB COMMENT='발주하다: 품의-제조사 관계';

-- 12. 입고이력: 상품 재고 + 발주하다(발주) 모두 추적
CREATE TABLE inbound_history (
  inbound_id        VARCHAR(260) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '입고 이력 번호',
  inventory_id      VARCHAR(280) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '입고하다: 재고 번호',
  purchase_order_id VARCHAR(230) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '발주하다: 발주 번호',
  inbound_seq INT UNSIGNED NOT NULL COMMENT '발주별 입고 순번',
  inbound_quantity  INT UNSIGNED NOT NULL COMMENT '입고 수량',
  inbound_on        DATE NOT NULL COMMENT '입고 날짜',
  PRIMARY KEY (inbound_id),
  UNIQUE KEY uq_inbound_po_seq (purchase_order_id, inbound_seq),
  UNIQUE KEY uq_inbound_inventory (inventory_id), -- 1 receipt : 1 inventory batch
  CONSTRAINT chk_inbound_seq CHECK (inbound_seq > 0),
  CONSTRAINT chk_inbound_key CHECK (inbound_id = CONCAT(purchase_order_id, '_', inbound_seq)),
  CONSTRAINT chk_inbound_inventory_key CHECK (inventory_id = CONCAT('inv_', inbound_id)),
  KEY ix_inbound_inventory (inventory_id),
  KEY ix_inbound_purchase_order (purchase_order_id),
  CONSTRAINT fk_inbound_inventory FOREIGN KEY (inventory_id) REFERENCES product_inventory (inventory_id),
  CONSTRAINT fk_inbound_purchase_order FOREIGN KEY (purchase_order_id) REFERENCES purchase_orders (purchase_order_id),
  CONSTRAINT chk_inbound_quantity CHECK (inbound_quantity > 0)
) ENGINE=InnoDB COMMENT='입고이력: 재고-발주 연결, 분할 입고 가능';

-- 13. 구매하다: 주문과 특정 재고 단위 연결
CREATE TABLE order_items (
  order_item_id       VARCHAR(72) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '주문 상품 번호',
  order_id            VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '주문 번호',
  order_item_seq INT UNSIGNED NOT NULL COMMENT '주문별 항목 순번; 동일 재고를 수량으로 구매',
  inventory_id        VARCHAR(280) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 재고 번호',
  purchase_quantity   INT UNSIGNED NOT NULL COMMENT '구매 수량',
  purchase_unit_price DECIMAL(12,2) UNSIGNED NOT NULL COMMENT '구매 당시 단가',
  sale_option         ENUM('NORMAL','NEAR_EXPIRY') NOT NULL COMMENT '구매 당시 판매 옵션 일반/임박',
  earned_points       INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '적립 마일리지',
  used_points         INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '사용 마일리지',
  PRIMARY KEY (order_item_id),
  UNIQUE KEY uq_order_items_order_seq (order_id, order_item_seq),
  UNIQUE KEY uq_order_items_order_inventory (order_id, inventory_id), -- 1 row for batch, multiple units via purchase_quantity
  CONSTRAINT chk_order_items_seq CHECK (order_item_seq > 0),
  CONSTRAINT chk_order_items_key CHECK (order_item_id = CONCAT(order_id, '_', order_item_seq)),
  KEY ix_order_items_order (order_id),
  KEY ix_order_items_inventory (inventory_id),
  CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
  CONSTRAINT fk_order_items_inventory FOREIGN KEY (inventory_id) REFERENCES product_inventory (inventory_id),
  CONSTRAINT chk_order_items_quantity CHECK (purchase_quantity > 0)
) ENGINE=InnoDB COMMENT='구매하다: 주문-상품 재고 관계';

-- 14. 장바구니에 담다: 고객과 화장품 N:M
CREATE TABLE cart_items (
  customer_id VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '회원 번호',
  cosmetic_id VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '화장품 번호',
  PRIMARY KEY (customer_id, cosmetic_id),
  KEY ix_cart_cosmetic (cosmetic_id),
  CONSTRAINT fk_cart_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
  CONSTRAINT fk_cart_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id)
) ENGINE=InnoDB COMMENT='장바구니에 담다';

-- 15. 리뷰하다: 고객-화장품 관계, 리뷰 번호(예: rev_1) 포함
CREATE TABLE reviews (
  review_id      VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '리뷰 번호(예: rev_1)',
  customer_id    VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '회원 번호',
  cosmetic_id    VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  review_content TEXT NOT NULL COMMENT '리뷰 내용',
  rating         TINYINT UNSIGNED NOT NULL COMMENT '평점',
  reviewed_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '리뷰 작성',
  PRIMARY KEY (review_id),
  CONSTRAINT chk_reviews_key CHECK (review_id REGEXP '^rev_[1-9][0-9]*$'),
  UNIQUE KEY uq_reviews_customer_cosmetic (customer_id, cosmetic_id),
  KEY ix_reviews_cosmetic (cosmetic_id),
  CONSTRAINT fk_reviews_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
  CONSTRAINT fk_reviews_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT chk_reviews_rating CHECK (rating BETWEEN 1 AND 5)
) ENGINE=InnoDB COMMENT='리뷰하다 관계';

-- 16. 고객 계정 상태 갱신하다(관계 속성: 날짜/계정 상태)
CREATE TABLE customer_account_status_history (
  status_history_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '갱신 이력 번호(예: csh_1)',
  customer_id       VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL COMMENT '회원 번호',
  changed_on        DATE NOT NULL COMMENT '날짜',
  account_status    ENUM('ACTIVE','WITHDRAWN') NOT NULL COMMENT '계정 상태 활성/탈퇴',
  PRIMARY KEY (status_history_id),
  CONSTRAINT chk_customer_account_status_history_key CHECK (status_history_id REGEXP '^csh_[1-9][0-9]*$'),
  KEY ix_customer_status_latest (customer_id, changed_on),
  CONSTRAINT fk_customer_status_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
) ENGINE=InnoDB COMMENT='상태 갱신하다: 고객 계정 변경 이력';

-- 17. 출고하다: 상품 재고-배송 정보 관계(관계 속성 수량/날짜)
CREATE TABLE stock_outbounds (
  inventory_id      VARCHAR(280) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 재고 번호',
  delivery_id       VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '배송 번호',
  outbound_quantity INT UNSIGNED NOT NULL COMMENT '출고 수량',
  outbound_on       DATE NOT NULL COMMENT '출고 날짜',
  PRIMARY KEY (inventory_id, delivery_id),
  KEY ix_outbounds_delivery (delivery_id),
  CONSTRAINT fk_outbounds_inventory FOREIGN KEY (inventory_id) REFERENCES product_inventory (inventory_id),
  CONSTRAINT fk_outbounds_delivery FOREIGN KEY (delivery_id) REFERENCES delivery_information (delivery_id),
  CONSTRAINT chk_outbounds_quantity CHECK (outbound_quantity > 0)
) ENGINE=InnoDB COMMENT='출고하다: 출고 수량과 날짜는 관계 속성';

-- 18. 반품 신청 (구매 단위를 참조하여 반품 수량/주문 확인 가능)
CREATE TABLE return_requests (
  return_id                  VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '반품 번호',
  order_item_id              VARCHAR(72) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '대상 구매 항목',
  return_seq INT UNSIGNED NOT NULL COMMENT '구매항목별 반품 순번',
  requested_on               DATE NOT NULL COMMENT '반품 신청일',
  approved_on                DATE NULL COMMENT '반품 승인 처리일 (과거 미기록 데이터는 NULL)',
  return_reason              VARCHAR(500) NOT NULL COMMENT '반품 사유',
  return_quantity            INT UNSIGNED NOT NULL COMMENT '반품 수량',
  return_status              ENUM('REQUESTED','APPROVED','REJECTED','COLLECTING','INSPECTING','COMPLETED')
                             NOT NULL DEFAULT 'REQUESTED' COMMENT '반품 처리 상태',
  refund_status              ENUM('PENDING','PROCESSING','COMPLETED','FAILED')
                             NOT NULL DEFAULT 'PENDING' COMMENT '환불 상태',
  pickup_status              ENUM('WAITING','SCHEDULED','COLLECTED','FAILED')
                             NOT NULL DEFAULT 'WAITING' COMMENT '반품 수거 상태',
  pickup_requested_on        DATE NULL COMMENT '수거 요청일',
  pickup_completed_on        DATE NULL COMMENT '수거 완료일',
  headquarters_received_on   DATE NULL COMMENT '본사 반품 수령일',
  inspection_result          VARCHAR(500) NULL COMMENT '검수 결과',
  inspection_completed_on    DATE NULL COMMENT '반품 검수 완료 처리일 (과거 미기록 데이터는 NULL)',
  PRIMARY KEY (return_id),
  UNIQUE KEY uq_returns_item_seq (order_item_id, return_seq),
  CONSTRAINT chk_returns_seq CHECK (return_seq > 0),
  CONSTRAINT chk_returns_key CHECK (return_id = CONCAT('ret_', order_item_id, '_', return_seq)),
  KEY ix_returns_order_item (order_item_id),
  CONSTRAINT fk_returns_order_item FOREIGN KEY (order_item_id) REFERENCES order_items (order_item_id),
  CONSTRAINT chk_return_quantity CHECK (return_quantity > 0),
  CONSTRAINT chk_return_pickup_dates CHECK (
    pickup_completed_on IS NULL OR pickup_requested_on IS NULL OR pickup_completed_on >= pickup_requested_on
  )
) ENGINE=InnoDB COMMENT='반품 신청';

-- 19. 수거하다: 반품 신청-배송업체 관계
CREATE TABLE return_pickups (
  return_id  VARCHAR(100) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '반품 번호',
  carrier_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '배송업체 식별자',
  PRIMARY KEY (return_id, carrier_id),
  KEY ix_return_pickups_carrier (carrier_id),
  CONSTRAINT fk_pickups_return FOREIGN KEY (return_id) REFERENCES return_requests (return_id),
  CONSTRAINT fk_pickups_carrier FOREIGN KEY (carrier_id) REFERENCES carriers (carrier_id)
) ENGINE=InnoDB COMMENT='수거하다';

-- 20. 직원-품의 결재하다: 결재 번호/상태/일시
CREATE TABLE approval_decisions (
  decision_id     VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '결재 번호',
  employee_id     VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  approval_id     VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '품의 번호',
  decision_status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING' COMMENT '결재 상태',
  decided_at      DATETIME NULL COMMENT '결재 일시',
  PRIMARY KEY (decision_id),
  CONSTRAINT chk_approval_decisions_key CHECK (decision_id REGEXP '^dec_[1-9][0-9]*$'),
  KEY ix_decisions_employee (employee_id),
  KEY ix_decisions_approval (approval_id),
  CONSTRAINT fk_decisions_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id),
  CONSTRAINT fk_decisions_approval FOREIGN KEY (approval_id) REFERENCES approvals (approval_id)
) ENGINE=InnoDB COMMENT='결재하다: 직원-품의 관계';

-- 21. 품의 상태변경 관계: 품의 상태의 이력
CREATE TABLE approval_status_history (
  status_history_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상태변경 이력 번호',
  approval_id       VARCHAR(200) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '품의 번호',
  approval_status   ENUM('REQUESTED','APPROVED','REJECTED','CANCELLED') NOT NULL COMMENT '품의 상태',
  changed_at        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '상태 변경 시각',
  PRIMARY KEY (status_history_id),
  CONSTRAINT chk_approval_status_history_key CHECK (status_history_id REGEXP '^ash_[1-9][0-9]*$'),
  KEY ix_approval_status_latest (approval_id, changed_at),
  CONSTRAINT fk_approval_status_approval FOREIGN KEY (approval_id) REFERENCES approvals (approval_id)
) ENGINE=InnoDB COMMENT='품의 상태변경 관계';

-- 22. 등록하다: 직원-화장품 관계
CREATE TABLE product_registrations (
  registration_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '등록 번호',
  employee_id     VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  cosmetic_id     VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  registered_on   DATE NOT NULL COMMENT '등록 날짜',
  PRIMARY KEY (registration_id),
  CONSTRAINT chk_product_registrations_key CHECK (registration_id REGEXP '^reg_[1-9][0-9]*$'),
  KEY ix_registrations_employee (employee_id),
  KEY ix_registrations_cosmetic (cosmetic_id),
  CONSTRAINT fk_registrations_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id),
  CONSTRAINT fk_registrations_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id)
) ENGINE=InnoDB COMMENT='등록하다: 직원-화장품 관계';

-- Below six tables directly represent the six distinct '갱신하다' relationship diamonds.
-- Each value is the value AFTER the change; query the latest changed_on/id for the current value.

-- 23. 용량을 갱신하다
CREATE TABLE cosmetic_volume_history (
  change_id   VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on  DATE NOT NULL COMMENT '날짜',
  volume_text VARCHAR(50) NOT NULL COMMENT '갱신한 용량',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_volume_history_key CHECK (change_id REGEXP '^vol_[1-9][0-9]*$'),
  KEY ix_volume_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_volume_employee (employee_id),
  CONSTRAINT fk_volume_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_volume_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='용량을 갱신하다 관계';

-- 24. 가격을 갱신하다
CREATE TABLE cosmetic_price_history (
  change_id   VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on  DATE NOT NULL COMMENT '날짜',
  sale_price  DECIMAL(12,2) UNSIGNED NOT NULL COMMENT '갱신한 판매 가격',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_price_history_key CHECK (change_id REGEXP '^prc_[1-9][0-9]*$'),
  KEY ix_price_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_price_employee (employee_id),
  CONSTRAINT fk_price_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_price_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='가격을 갱신하다 관계';

-- 25. 판매 상태를 갱신하다
CREATE TABLE cosmetic_sale_status_history (
  change_id   VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on  DATE NOT NULL COMMENT '날짜',
  sale_status ENUM('ON_SALE','DISCONTINUED') NOT NULL COMMENT '판매/단종',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_sale_status_history_key CHECK (change_id REGEXP '^sls_[1-9][0-9]*$'),
  KEY ix_sale_status_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_sale_status_employee (employee_id),
  CONSTRAINT fk_sale_status_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_sale_status_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='판매 상태를 갱신하다 관계';

-- 26. 원가를 갱신하다
CREATE TABLE cosmetic_cost_history (
  change_id    VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id  VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id  VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on   DATE NOT NULL COMMENT '날짜',
  unit_cost    DECIMAL(12,2) UNSIGNED NOT NULL COMMENT '갱신한 원가',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_cost_history_key CHECK (change_id REGEXP '^cst_[1-9][0-9]*$'),
  KEY ix_cost_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_cost_employee (employee_id),
  CONSTRAINT fk_cost_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_cost_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='원가를 갱신하다 관계';

-- 27. 최소 재고량을 갱신하다
CREATE TABLE cosmetic_min_stock_history (
  change_id     VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id   VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id   VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on    DATE NOT NULL COMMENT '날짜',
  min_stock_qty INT UNSIGNED NOT NULL COMMENT '갱신한 최소 재고량',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_min_stock_history_key CHECK (change_id REGEXP '^min_[1-9][0-9]*$'),
  KEY ix_min_stock_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_min_stock_employee (employee_id),
  CONSTRAINT fk_min_stock_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_min_stock_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='최소 재고량을 갱신하다 관계';

-- 28. 목표 재고량을 갱신하다
CREATE TABLE cosmetic_target_stock_history (
  change_id       VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '이력 번호',
  cosmetic_id     VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '상품 번호',
  employee_id     VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL COMMENT '직원 번호',
  changed_on      DATE NOT NULL COMMENT '날짜',
  target_stock_qty INT UNSIGNED NOT NULL COMMENT '갱신한 목표 재고량',
  PRIMARY KEY (change_id),
  CONSTRAINT chk_cosmetic_target_stock_history_key CHECK (change_id REGEXP '^tgt_[1-9][0-9]*$'),
  KEY ix_target_stock_cosmetic_date (cosmetic_id, changed_on),
  KEY ix_target_stock_employee (employee_id),
  CONSTRAINT fk_target_stock_cosmetic FOREIGN KEY (cosmetic_id) REFERENCES cosmetics (cosmetic_id),
  CONSTRAINT fk_target_stock_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
) ENGINE=InnoDB COMMENT='목표 재고량을 갱신하다 관계';

-- Business rules enforced by FastAPI (cannot be fully checked by row-local SQL CHECK):
--   1. Create an AUTO approval only when latest sale status is ON_SALE
--      AND target_stock - SUM(sellable inventory stock_quantity) > 0.
--      Do not raise duplicate open approvals for the same shortage.
--   2. A receipt creates exactly one NEW product_inventory row, then one inbound_history
--      row referencing it. Their cosmetic and dates must match the parent PO/receipt.
--      UNIQUE(inbound_history.inventory_id) enforces at most one receipt per stock row;
--      the application transaction ensures that every created stock row has a receipt.
--   3. order_items.purchase_quantity can be >1; check stock availability under row lock
--      and decrement inventory.stock_quantity in the SAME transaction.
--   4. Set (employee key_role) only at account creation; promotions change employee_role
--      but never change employee_id.
--   5. Append history rows and determine latest by changed_on/changed-at and sequence.

-- Auxiliary infrastructure table (not an ERD business entity).
-- Allocate per-scope sequences under an application-managed DB transaction.
CREATE TABLE id_counters (
  scope_name VARCHAR(320) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  last_value BIGINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (scope_name)
) ENGINE=InnoDB COMMENT='범위별 순번 할당기: 직원/화장품/품의/발주/입고 등';
