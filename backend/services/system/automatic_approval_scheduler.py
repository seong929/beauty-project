"""Daily automatic purchase approvals WITHOUT database schema migrations.

The service's daily checkpoint is stored in a local JSON file (default:
backend/.automatic_approval_daily_state.json). A MySQL named lock serializes
scheduler workers that use the same database, and an atomic file replacement
persists completed/failed runs across process restarts on the same machine.

This is suitable for a single host/test setup. Multi-host deployments must use
shared durable coordination (e.g. a DB table or task scheduler) instead.
"""
import json
import logging
import os
import tempfile
import threading
from datetime import datetime, timedelta, timezone
from pathlib import Path

from database import get_connection
from services.system.automatic_approval_service import create_automatic_approvals

logger = logging.getLogger(__name__)
KST = timezone(timedelta(hours=9), name="KST")
LOCK_KEY = "cosmetic_auto_approvals_daily_v1"
POLL_SECONDS = 45
RETRY_MINUTES = 10


def _schedule_time():
    hour = int(os.getenv("AUTO_APPROVAL_RUN_HOUR", "3"))
    minute = int(os.getenv("AUTO_APPROVAL_RUN_MINUTE", "0"))
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise ValueError("AUTO_APPROVAL_RUN_HOUR/MINUTE must be valid KST times")
    return hour, minute


def _is_due(now: datetime, hour: int, minute: int) -> bool:
    return (now.hour, now.minute) >= (hour, minute)


def _state_path() -> Path:
    default = Path(__file__).resolve().parents[2] / ".automatic_approval_daily_state.json"
    return Path(os.getenv("AUTO_APPROVAL_STATE_FILE", str(default))).expanduser().resolve()


def _read_checkpoint() -> dict | None:
    path = _state_path()
    try:
        with path.open("r", encoding="utf-8") as stream:
            data = json.load(stream)
    except FileNotFoundError:
        return None
    # A damaged file must not silently reset daily history (fail closed).
    if not isinstance(data, dict) or not isinstance(data.get("run_date"), str):
        raise ValueError(f"Invalid automatic approval checkpoint: {path}")
    if data.get("status") not in {"RUNNING", "SUCCESS", "FAILED"}:
        raise ValueError(f"Invalid automatic approval checkpoint status: {path}")
    return data


def _save_checkpoint(data: dict) -> None:
    path = _state_path()
    # Don't create arbitrary directories as a side effect of the scheduler.
    # A writable backend directory is required; use AUTO_APPROVAL_STATE_FILE otherwise.
    temp_name = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", dir=path.parent,
            prefix=f".{path.name}.", suffix=".tmp", delete=False,
        ) as stream:
            temp_name = stream.name
            json.dump(data, stream, ensure_ascii=False, indent=2)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
    finally:
        if temp_name is not None:
            try:
                os.unlink(temp_name)
            except FileNotFoundError:
                pass


def _parse_local_naive(value):
    if not value:
        return None
    if isinstance(value, datetime):
        return value.replace(tzinfo=None)
    return datetime.fromisoformat(str(value)).replace(tzinfo=None)


def _should_run(row, now: datetime) -> bool:
    if row is None:
        return True
    if row["status"] == "SUCCESS":
        return False
    if row["status"] in ("FAILED", "RUNNING"):
        last = _parse_local_naive(row.get("finished_at") or row.get("started_at"))
        return last is None or (now.replace(tzinfo=None) - last >= timedelta(minutes=RETRY_MINUTES))
    return False


def run_daily_if_due(now: datetime | None = None) -> dict:
    """Run today's automatic approval batch only when due and not already done.

    Named locking is database-level; the JSON checkpoint survives local restarts.
    The service is already responsible for preventing duplicate pending approvals
    and active orders. Manual POST /run is intentionally independent of this log.
    """
    hour, minute = _schedule_time()
    now = now or datetime.now(KST)
    if now.tzinfo is None:
        raise ValueError("now must be timezone-aware")
    now = now.astimezone(KST)
    today = str(now.date())
    if not _is_due(now, hour, minute):
        return {"result": "NOT_DUE", "run_date": today}

    conn = get_connection()
    have_lock = False
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT GET_LOCK(%s, 0) AS acquired", (LOCK_KEY,))
            have_lock = cursor.fetchone()["acquired"] == 1
        if not have_lock:
            return {"result": "ALREADY_RUNNING", "run_date": today}

        previous = _read_checkpoint()
        # Only the same calendar day can block this day's run.
        today_previous = previous if previous and previous["run_date"] == today else None
        if not _should_run(today_previous, now):
            return {"result": "ALREADY_DONE_OR_COOLDOWN", "run_date": today}

        started_at = now.replace(tzinfo=None).isoformat(timespec="seconds")
        _save_checkpoint({
            "run_date": today, "status": "RUNNING", "started_at": started_at,
            "finished_at": None, "checked_count": 0,
            "created_count": 0, "error_count": 0,
        })
        try:
            result = create_automatic_approvals()
            if not isinstance(result, dict) or any(
                key not in result for key in ("checked_count", "created_count", "error_count")
            ):
                raise RuntimeError("Invalid automatic approval batch response")
            outcome = "FAILED" if int(result["error_count"]) else "SUCCESS"
            finished = datetime.now(KST).replace(tzinfo=None).isoformat(timespec="seconds")
            _save_checkpoint({
                "run_date": today, "status": outcome, "started_at": started_at,
                "finished_at": finished,
                "checked_count": int(result["checked_count"]),
                "created_count": int(result["created_count"]),
                "error_count": int(result["error_count"]),
                "summary": result,
            })
            logger.info("Daily automatic approval run %s: %s", today, outcome)
            return {"result": outcome, "run_date": today, **result}
        except Exception as exc:
            logger.exception("Daily automatic approvals failed")
            try:
                _save_checkpoint({
                    "run_date": today, "status": "FAILED", "started_at": started_at,
                    "finished_at": datetime.now(KST).replace(tzinfo=None).isoformat(timespec="seconds"),
                    "checked_count": 0, "created_count": 0, "error_count": 1,
                    "error": type(exc).__name__,
                })
            except Exception:
                logger.exception("Cannot persist failed automatic approval run")
            return {"result": "FAILED", "run_date": today, "error": type(exc).__name__}
    finally:
        if have_lock:
            try:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT RELEASE_LOCK(%s)", (LOCK_KEY,))
            except Exception:
                logger.exception("Cannot release automatic approval named lock")
        conn.close()


def start_daily_approval_scheduler() -> tuple[threading.Event, threading.Thread] | None:
    if os.getenv("AUTO_APPROVAL_SCHEDULER_ENABLED", "1") != "1":
        logger.info("Daily automatic approvals disabled by configuration")
        return None
    _schedule_time()
    stop_event = threading.Event()

    def worker():
        while not stop_event.is_set():
            try:
                run_daily_if_due()
            except Exception:
                logger.exception("Daily scheduler tick failed")
            stop_event.wait(POLL_SECONDS)

    thread = threading.Thread(target=worker, name="auto-approvals-daily", daemon=True)
    thread.start()
    return stop_event, thread


def stop_daily_approval_scheduler(handle) -> None:
    if handle is not None:
        event, thread = handle
        event.set()
        thread.join(timeout=2)


def read_daily_run_status() -> dict:
    """Status endpoint never touches a DB run table."""
    now = datetime.now(KST)
    hour, minute = _schedule_time()
    try:
        last_run = _read_checkpoint()
        error = None
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        logger.exception("Cannot read automatic approval checkpoint")
        last_run = None
        error = f"일일 실행 이력 파일 읽기 오류: {type(exc).__name__}"
    return {
        "scheduler_enabled": os.getenv("AUTO_APPROVAL_SCHEDULER_ENABLED", "1") == "1",
        "timezone": "Asia/Seoul",
        "scheduled_time": f"{hour:02d}:{minute:02d}",
        "server_now": now.isoformat(timespec="seconds"),
        "today": str(now.date()),
        "last_run": last_run,
        "state_storage": "local_json_file",
        "state_error": error,
    }
