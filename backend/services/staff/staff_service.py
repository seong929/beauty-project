from database import get_connection

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