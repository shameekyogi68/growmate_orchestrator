import asyncio
from app.utils.logger import logger
import time

from app.utils.resilience import shield_service


async def execute_parallel(services: dict, timeout: float = 5.0):
    keys = list(services.keys())

    start_time = time.time()

    # Shielded tasks: each task is wrapped with a circuit breaker
    shielded_tasks = [shield_service(key, task) for key, task in services.items()]

    results = await asyncio.gather(
        *(asyncio.wait_for(task, timeout=timeout) for task in shielded_tasks),
        return_exceptions=True,
    )

    execution_time = time.time() - start_time
    logger.info(f"Parallel execution (shielded) completed in {execution_time:.3f}s")

    final_output = {}
    for i, key in enumerate(keys):
        res = results[i]
        if isinstance(res, Exception):
            logger.warning(f"Service {key} timed out or crashed hard: {res}")
            final_output[key] = "unavailable"
        elif res in ["failed", "circuit_open"]:
            final_output[key] = "unavailable"
        else:
            final_output[key] = res

    return final_output
