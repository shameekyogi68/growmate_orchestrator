import asyncio


async def get_udupi_agri_news(language: str = "en"):
    """
    Fetches localized agricultural news and alerts for Karnataka and Udupi.
    """
    await asyncio.sleep(0.1)

    from typing import Any

    news_items: list[dict[str, Any]] = [
        {
            "priority": "MEDIUM",
            "title": {
                "en": "Udupi Mandi: Paddy MSP expected to increase.",
                "kn": "ಉಡುಪಿ ಮಂಡಿ: ಭತ್ತದ ಕನಿಷ್ಠ ಬೆಂಬಲ ಬೆಲೆ ಏರಿಕೆಯ ನಿರೀಕ್ಷೆ.",
            },
            "summary": {
                "en": "Reports suggest a 5% increase in MSP for Fine variety paddy in the upcoming week.",
                "kn": "ಮುಂದಿನ ವಾರದಲ್ಲಿ ಉತ್ತಮ ತಳಿಯ ಭತ್ತದ ಬೆಂಬಲ ಬೆಲೆಯಲ್ಲಿ 5% ಹೆಚ್ಚಳವಾಗುವ ಸೂಚನೆ ಇದೆ.",
            },
        },
        {
            "priority": "HIGH",
            "title": {
                "en": "District Alert: Fertilizer stock arriving in Brahmavar.",
                "kn": "ಜಿಲ್ಲಾ ಎಚ್ಚರಿಕೆ: ಬ್ರಹ್ಮಾವರಕ್ಕೆ ರಸಗೊಬ್ಬರ ದಾಸ್ತಾನು ಆಗಮನ.",
            },
            "summary": {
                "en": "Farmers are advised to contact local RSK centres for urea availability.",
                "kn": "ರೈತರು ಯೂರಿಯಾ ಲಭ್ಯತೆಗಾಗಿ ಸ್ಥಳೀಯ ರೈತ ಸಂಪರ್ಕ ಕೇಂದ್ರಗಳನ್ನು ಸಂಪರ್ಕಿಸಲು ಸೂಚಿಸಲಾಗಿದೆ.",
            },
        },
    ]

    localized_news = []
    for item in news_items:
        localized_news.append(
            {
                "priority": item["priority"],
                "title": item["title"].get(language, item["title"]["en"]),
                "summary": item["summary"].get(language, item["summary"]["en"]),
            }
        )

    return localized_news
