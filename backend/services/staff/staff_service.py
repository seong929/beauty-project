from database import get_connection

#현재 진행중인 주문 내역을 페이지 단위로 가져오는 함수
def get_available_order_list_from_page(page : int, count : int, asc : bool):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            orderby = 'ASC' if asc else 'DESC'
            sql =   f"""
                    SELECT * FROM orders
                    WHERE order_status NOT IN ('DELIVERED', 'CANCELLED', 'RETURNED') 
                    ORDER BY order_seq {orderby}
                    LIMIT %s OFFSET %s
                    """
            cursor.execute(sql, (count, (page-1) * count))
            return cursor.fetchall()
    finally:
        conn.close()

#특정 주문 내역에 포함된 구매 상품들의 정보를 가져오는 함수
def get_items_from_order(order_id : str):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            sql =   """
                    SELECT
                        oi.order_item_id,
                        oi.purchase_quantity,
                        oi.purchase_unit_price,
                        pi.inventory_id,
                        pi.expires_on,
                        c.cosmetic_id,
                        c.cosmetic_name
                    FROM order_items AS oi
                    INNER JOIN product_inventory AS pi
                        ON oi.inventory_id = pi.inventory_id
                    INNER JOIN cosmetics AS c
                        ON pi.cosmetic_id = c.cosmetic_id
                    WHERE oi.order_id = %s
                    """

            cursor.execute(sql, (order_id,))
            return cursor.fetchall()
    finally:
        conn.close()