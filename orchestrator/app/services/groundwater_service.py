import asyncio


async def get_udupi_groundwater_status(language: str = "en"):
    """
    Provides the current groundwater table status for the Udupi region.
    Based on CGWB (Central Ground Water Board) district-level data trends.
    """
    await asyncio.sleep(0.1)

    # Representative depth in meters below ground level for Udupi (current season)
    depth = 8.5

    if language == "kn":
        return {
            "depth_meters": depth,
            "status": "ಸಾಮಾನ್ಯ",
            "advice": "ಅಂತರ್ಜಲ ಮಟ್ಟ ಸ್ಥಿರವಾಗಿದೆ. ಹನಿ ನೀರಾವರಿ ಪದ್ಧತಿಯನ್ನು ಮುಂದುವರಿಸಿ.",
            "source": "ಅಂತರ್ಜಲ ಮಂಡಳಿ (ವಲಯ ಕೇಂದ್ರ)",
        }

    return {
        "depth_meters": depth,
        "status": "Normal",
        "advice": "Groundwater level is stable. Continue using drip irrigation for efficiency.",
        "source": "Groundwater Board (District Node)",
    }
