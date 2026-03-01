import logging
import sys
import contextvars

# Context variable for per-request ID isolation, accessible globally
request_id_ctx: contextvars.ContextVar[str] = contextvars.ContextVar(
    "request_id", default="global"
)

# Global record factory to ensure %(request_id)s is always available
old_factory = logging.getLogRecordFactory()


def record_factory(*args, **kwargs):
    record = old_factory(*args, **kwargs)
    record.request_id = request_id_ctx.get()
    return record


logging.setLogRecordFactory(record_factory)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - [RID: %(request_id)s] - %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)

logger = logging.getLogger("growmate")
