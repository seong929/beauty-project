"""Loopback-only development endpoints, independent of the test API flag.

The actual daily scheduler calls service directly.

No staff identity is used to *create* an automatic approval. The existing
approval_decisions row still names an administrator as future approver.
"""
from fastapi import APIRouter, HTTPException, Query, Request
from database import get_connection
from services.system.automatic_approval_service import create_automatic_approvals
from services.system.automatic_approval_scheduler import read_daily_run_status

router = APIRouter(prefix="/system/automatic-approvals", tags=["시스템 자동 품의 (개발용)"])


def _require_local_test(request: Request) -> None:
    host = request.client.host if request.client else ""
    if host not in ("127.0.0.1", "::1"):
        raise HTTPException(status_code=403, detail="로컬 개발 환경에서만 허용됩니다.")


@router.get("", summary="등록된 품의 목록 (개발용)")
def list_approvals(request: Request, page: int = Query(1, ge=1), count: int = Query(20, ge=1, le=100)):
    _require_local_test(request)
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) AS total FROM approvals")
            total = int(cursor.fetchone()["total"])
            cursor.execute(
                """SELECT a.approval_id, a.cosmetic_id, c.cosmetic_name, a.approval_seq,
                          a.target_stock_snapshot, a.current_stock_snapshot,
                          a.requested_quantity, a.approval_content, a.requested_on,
                          (SELECT h.approval_status FROM approval_status_history h
                           WHERE h.approval_id=a.approval_id
                           ORDER BY h.changed_at DESC,
                             CAST(SUBSTRING(h.status_history_id, 5) AS UNSIGNED) DESC
                           LIMIT 1) AS approval_status
                   FROM approvals a
                   JOIN cosmetics c ON c.cosmetic_id=a.cosmetic_id
                   ORDER BY a.requested_on DESC, a.approval_id DESC
                   LIMIT %s OFFSET %s""",
                (count, (page - 1) * count),
            )
            items = cursor.fetchall()
        return {"page": page, "count": count, "total": total, "items": items}
    finally:
        conn.close()


@router.get("/status", summary="자동 품의 스케줄러 상태 (개발용)")
def daily_status(request: Request):
    _require_local_test(request)
    return read_daily_run_status()


@router.post("/run", summary="자동 품의 수동 테스트 실행 (개발용)")
def run_automatic_approvals(request: Request):
    _require_local_test(request)
    # No staff auth; never expose this state-changing endpoint publicly.
    return create_automatic_approvals()
