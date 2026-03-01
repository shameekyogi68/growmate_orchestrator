import asyncio
from typing import Dict, Any, Callable, Awaitable


class SingleFlight:
    """
    Prevents redundant, simultaneous execution of the same expensive operation.
    Useful for preventing 'Cache Stampedes'.
    """

    def __init__(self):
        self._locks: Dict[str, asyncio.Lock] = {}
        self._results: Dict[str, Any] = {}
        self._in_flight: Dict[str, asyncio.Future] = {}

    async def run(
        self, key: str, func: Callable[..., Awaitable[Any]], *args, **kwargs
    ) -> Any:
        # If this specific key is already in flight, wait for the existing future
        if key in self._in_flight:
            return await self._in_flight[key]

        # Otherwise, create a new future and start the work
        self._in_flight[key] = asyncio.get_running_loop().create_future()
        try:
            result = await func(*args, **kwargs)
            self._in_flight[key].set_result(result)
            return result
        except Exception as e:
            self._in_flight[key].set_exception(e)
            raise e
        finally:
            # Clean up after completion so subsequent calls can trigger new work
            self._in_flight.pop(key, None)


# Global instances for common operations
advisory_flight = SingleFlight()
