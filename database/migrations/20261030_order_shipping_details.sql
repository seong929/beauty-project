-- 주문별 배송 정보를 회원 기본 정보와 독립적으로 보관한다. 기존 주문 주소는 유지한다.
ALTER TABLE orders
  ADD COLUMN shipping_recipient VARCHAR(100) NULL COMMENT '주문 수령인',
  ADD COLUMN shipping_phone VARCHAR(30) NULL COMMENT '주문 수령인 연락처',
  ADD COLUMN delivery_request VARCHAR(200) NOT NULL DEFAULT '' COMMENT '배송 요청사항';

UPDATE orders AS o JOIN customers AS c ON c.customer_id = o.customer_id
SET o.shipping_recipient = COALESCE(o.shipping_recipient, c.customer_name),
    o.shipping_phone = COALESCE(o.shipping_phone, c.phone)
WHERE o.shipping_recipient IS NULL OR o.shipping_phone IS NULL;
