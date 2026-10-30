-- 기존 주문·고객 잔액·포인트 내역은 보존하고 사용·복원 유형을 추가한다.
ALTER TABLE orders
  ADD COLUMN used_points INT UNSIGNED NOT NULL DEFAULT 0 COMMENT '주문 결제에 사용한 포인트';

ALTER TABLE customer_point_history
  DROP CHECK chk_customer_points_delta,
  MODIFY COLUMN event_type ENUM('EARN','CANCEL','USE','RESTORE') NOT NULL,
  ADD CONSTRAINT chk_customer_points_delta CHECK (
    (event_type IN ('EARN','RESTORE') AND points_delta>0)
    OR (event_type IN ('CANCEL','USE') AND points_delta<0)
  );
