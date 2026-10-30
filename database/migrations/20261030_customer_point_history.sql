-- 고객 결제 10% 적립·주문 취소 회수 내역. 기존 잔액과 과거 주문은 변경하지 않는다.
CREATE TABLE IF NOT EXISTS customer_point_history (
  point_id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  customer_id VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  order_id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  event_type ENUM('EARN','CANCEL') NOT NULL,
  points_delta BIGINT NOT NULL,
  balance_after INT UNSIGNED NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (point_id),
  UNIQUE KEY uq_customer_points_order_event (order_id, event_type),
  KEY ix_customer_points_history (customer_id, created_at),
  CONSTRAINT fk_customer_points_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
  CONSTRAINT fk_customer_points_order FOREIGN KEY (order_id) REFERENCES orders(order_id),
  CONSTRAINT chk_customer_points_delta CHECK (
    (event_type='EARN' AND points_delta>0) OR (event_type='CANCEL' AND points_delta<0)
  )
) ENGINE=InnoDB COMMENT='고객 포인트 적립·회수 내역';
