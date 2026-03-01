import random


async def get_mandi_arrivals(crop: str, language: str = "en"):
    """
    Simulates real-time market arrival data for Udupi APMCs.
    """
    markets = [
        {"name": "Brahmavar" if language == "en" else "ಬ್ರಹ್ಮಾವರ", "distance": "12km"},
        {"name": "Kundapur" if language == "en" else "ಕುಂದಾಪುರ", "distance": "28km"},
        {"name": "Udupi" if language == "en" else "ಉಡುಪಿ", "distance": "5km"},
    ]

    arrivals = []
    for m in markets:
        stock = random.randint(50, 500)
        status = "High" if stock > 300 else "Moderate"
        status_kn = "ಹೆಚ್ಚು" if stock > 300 else "ಸಾಧಾರಣ"

        arrivals.append(
            {
                "market": m["name"],
                "distance": m["distance"],
                "arrival_quantity": f"{stock} Quintals",
                "stock_status": status if language == "en" else status_kn,
            }
        )

    return {
        "crop": crop,
        "markets": arrivals,
        "summary": (
            f"Healthy stock levels in {len(markets)} local markets."
            if language == "en"
            else f"{len(markets)} ಸ್ಥಳೀಯ ಮಾರುಕಟ್ಟೆಗಳಲ್ಲಿ ಉತ್ತಮ ದಾಸ್ತಾನು ಮಟ್ಟವಿದೆ."
        ),
    }
