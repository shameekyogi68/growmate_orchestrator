import asyncio


async def get_udupi_schemes(language: str = "en"):
    """
    Provides intelligence on government schemes specifically relevant to Udupi district.
    """
    await asyncio.sleep(0.1)

    schemes = [
        {
            "name": {"en": "Krishi Bhagya", "kn": "ಕೃಷಿ ಭಾಗ್ಯ"},
            "description": {
                "en": "Subsidy for farm ponds and sustainable irrigation in coastal regions.",
                "kn": "ಕರಾವಳಿ ಪ್ರದೇಶಗಳಲ್ಲಿ ಕೃಷಿ ಹೊಂಡ ಮತ್ತು ಸುಸ್ಥಿರ ನೀರಾವರಿಗಾಗಿ ಸಬ್ಸಿಡಿ.",
            },
            "eligibility": {
                "en": "Small and marginal farmers of Udupi district.",
                "kn": "ಉಡುಪಿ ಜಿಲ್ಲೆಯ ಸಣ್ಣ ಮತ್ತು ಅತಿಸಣ್ಣ ರೈತರು.",
            },
        },
        {
            "name": {"en": "Pashu Bhagya", "kn": "ಪಶು ಭಾಗ್ಯ"},
            "description": {
                "en": "Interest-free loans for cattle rearing and dairy farming units.",
                "kn": "ಜಾನುವಾರು ಸಾಕಾಣಿಕೆ ಮತ್ತು ಹೈನುಗಾರಿಕೆ ಘಟಕಗಳ ಸ್ಥಾಪನೆಗೆ ಬಡ್ಡಿ ರಹಿತ ಸಾಲ.",
            },
            "eligibility": {
                "en": "Farmers belonging to SC/ST and backward classes in Udupi.",
                "kn": "ಉಡುಪಿಯ SC/ST ಮತ್ತು ಹಿಂದುಳಿದ ವರ್ಗಗಳಿಗೆ ಸೇರಿದ ರೈತರು.",
            },
        },
        {
            "name": {"en": "Matsya Sampada", "kn": "ಮತ್ಸ್ಯ ಸಂಪದ"},
            "description": {
                "en": "Special focus on coastal aquaculture and fish processing units.",
                "kn": "ಕರಾವಳಿ ಮತ್ಸ್ಯ ಸಾಕಾಣಿಕೆ ಮತ್ತು ಮೀನು ಸಂಸ್ಕರಣಾ ಘಟಕಗಳಿಗೆ ವಿಶೇಷ ಆದ್ಯತೆ.",
            },
            "eligibility": {
                "en": "Coastal farmers and fishing communities of Udupi.",
                "kn": "ಉಡುಪಿಯ ಕರಾವಳಿ ರೈತರು ಮತ್ತು ಮೀನುಗಾರಿಕಾ ಸಮುದಾಯಗಳು.",
            },
        },
    ]

    localized_schemes = []
    for s in schemes:
        localized_schemes.append(
            {
                "name": s["name"].get(language, s["name"]["en"]),
                "description": s["description"].get(language, s["description"]["en"]),
                "eligibility": s["eligibility"].get(language, s["eligibility"]["en"]),
            }
        )

    return localized_schemes
