import asyncio
import time
from enum import Enum
from typing import Callable, Any, Dict
from app.utils.logger import logger


class CircuitState(Enum):
    CLOSED = "closed"  # Normal operation
    OPEN = "open"  # Failure detected, service blocked
    HALF_OPEN = "half_open"  # Testing if service recovered


class CircuitBreaker:
    def __init__(self, name: str, threshold: int = 3, recovery_timeout: float = 30.0):
        self.name = name
        self.threshold = threshold
        self.recovery_timeout = recovery_timeout
        self.failure_count = 0
        self.state = CircuitState.CLOSED
        self.last_failure_time = 0
        self.last_success_time = 0

    def record_failure(self):
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.threshold:
            if self.state != CircuitState.OPEN:
                logger.error(
                    f"🚨 CIRCUIT BREAKER OPENED for service: {self.name} after {self.failure_count} failures"
                )
            self.state = CircuitState.OPEN

    def record_success(self):
        if self.state == CircuitState.HALF_OPEN:
            logger.info(
                f"✅ CIRCUIT BREAKER CLOSED for service: {self.name}. Recovery confirmed."
            )
        self.failure_count = 0
        self.state = CircuitState.CLOSED
        self.last_success_time = time.time()

    def can_execute(self) -> bool:
        if self.state == CircuitState.CLOSED:
            return True

        if self.state == CircuitState.OPEN:
            # Check if recovery timeout has passed
            if time.time() - self.last_failure_time > self.recovery_timeout:
                logger.warning(
                    f"🔄 CIRCUIT BREAKER HALF-OPEN for service: {self.name}. Attempting recovery..."
                )
                self.state = CircuitState.HALF_OPEN
                return True
            return False

        if self.state == CircuitState.HALF_OPEN:
            # Allow only one request to test the service
            return True

        return False


# Registry of circuit breakers per logical service
REGISTRY: Dict[str, CircuitBreaker] = {}


def get_breaker(name: str) -> CircuitBreaker:
    if name not in REGISTRY:
        REGISTRY[name] = CircuitBreaker(name)
    return REGISTRY[name]


async def shield_service(name: str, func: Callable, *args, **kwargs) -> Any:
    """Wraps a service call with a circuit breaker shield."""
    breaker = get_breaker(name)

    if not breaker.can_execute():
        logger.warning(f"🛡️ Shielding active: Skipping {name} (Circuit is OPEN)")
        return "circuit_open"

    try:
        # Note: func is expected to be an awaitable or a partial
        if asyncio.iscoroutine(func):
            result = await func
        else:
            result = await func(*args, **kwargs)

        breaker.record_success()
        return result
    except Exception as e:
        logger.error(f"💥 Service {name} failed: {e}")
        breaker.record_failure()
        return "failed"
