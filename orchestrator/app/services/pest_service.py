from datetime import datetime, timezone


async def get_pest_advisory(
    crop: str,
    variety: str,
    sowing_date: str,
    language: str = "en",
    request_date: str | None = None,
):
    """
    Heuristic Pest Risk Engine for Udupi.
    Predicts risks based on crop stage, month, and local coastal conditions.
    """
    try:
        sowing = datetime.strptime(sowing_date, "%Y-%m-%d").date()
        target_date = (
            datetime.strptime(request_date, "%Y-%m-%d").date()
            if request_date
            else datetime.now(timezone.utc).date()
        )
        days_elapsed = (target_date - sowing).days
        month = target_date.month
    except (ValueError, TypeError):
        days_elapsed = 30
        month = 6

    risk_level = "LOW"
    pests = []

    # Udupi Specific Paddy Logic
    if crop.lower() == "paddy":
        # 1. Yellow Stem Borer (Kharif/Early stage)
        if 15 <= days_elapsed <= 45 and month in [6, 7, 11]:
            risk_level = "MEDIUM"
            pests.append(
                {
                    "name": (
                        "Yellow Stem Borer" if language == "en" else "ಹಳದಿ ಕುಡಿ ಕೊರಕ"
                    ),
                    "risk": "High" if language == "en" else "ಹೆಚ್ಚು",
                    "action": (
                        "Spray Chlorantraniliprole 0.4% G"
                        if language == "en"
                        else "ಕ್ಲೋರಂಟ್ರಾನಿಲಿಪ್ರೋಲ್ 0.4% G ಸಿಂಪಡಿಸಿ"
                    ),
                }
            )

        # 2. Gall Midge (Koleroga - high humidity)
        if month in [7, 8, 9]:
            risk_level = "HIGH"
            pests.append(
                {
                    "name": (
                        "Gall Midge (Silver Shoot)"
                        if language == "en"
                        else "ಹಿಪ್ಪುಳ (ಗಾಲ್ ಮಿಡ್ಜ್)"
                    ),
                    "risk": "Critical" if language == "en" else "ಗಂಭೀರ",
                    "action": (
                        "Use resistant varieties like MO-4 or Mahaveer"
                        if language == "en"
                        else "MO-4 ಅಥವಾ ಮಹಾವೀರ ಅಂತಹ ರೋಗ ನಿರೋಧಕ ತಳಿಗಳನ್ನು ಬಳಸಿ"
                    ),
                }
            )

    # Udupi Specific Arecanut Logic (Koleroga/Kole)
    elif "areca" in crop.lower():
        if month in [6, 7, 8]:
            risk_level = "HIGH"
            pests.append(
                {
                    "name": (
                        "Fruit Rot (Koleroga)" if language == "en" else "ಕೊಳೆ ರೋಗ (ಕೊಳರೋಗ)"
                    ),
                    "risk": "Very High" if language == "en" else "ಬಹಳ ಹೆಚ್ಚು",
                    "action": (
                        "Spray 1% Bordeaux mixture before monsoon"
                        if language == "en"
                        else "ಮಳೆಗಾಲದ ಮೊದಲು 1% ಬೋರ್ಡೋ ಮಿಶ್ರಣವನ್ನು ಸಿಂಪಡಿಸಿ"
                    ),
                }
            )

    from app.services.agronomy_knowledge import get_local_crop_advice

    kb_pests = get_local_crop_advice(crop, "pests", language)

    # Enrich heuristic hits with static control knowledge
    for p in pests:
        for kp in kb_pests:
            if kp.get("name") in p.get("name") or kp.get("kn_name") in p.get("name"):
                p["symptoms"] = kp.get(
                    "symptoms",
                    kp.get("kn_name") if language == "kn" else kp.get("name"),
                )
                p["control"] = kp.get(
                    "control",
                    kp.get("kn_control") if language == "kn" else kp.get("control"),
                )

    if not pests:
        msg = (
            "No critical pest warnings at this stage."
            if language == "en"
            else "ಈ ಹಂತದಲ್ಲಿ ಯಾವುದೇ ಗಂಭೀರ ಪೀಡೆ ಎಚ್ಚರಿಕೆಗಳಿಲ್ಲ."
        )
        return {
            "status": "Healthy" if language == "en" else "ಆರೋಗ್ಯಕರ",
            "risk_level": "LOW",
            "message": msg,
            "monitored_pests": kb_pests[
                :1
            ],  # Provide a 'scouting' baseline from Static KB
        }

    return {
        "status": "Monitor Required" if language == "en" else "ಪರಿಶೀಲನೆ ಅಗತ್ಯ",
        "risk_level": risk_level,
        "message": (
            "Localized risk detected for coastal humid conditions."
            if language == "en"
            else "ಕರಾವಳಿ ತೇವಾಂಶದ ಪರಿಸ್ಥಿತಿಗೆ ಅನುಗುಣವಾಗಿ ಸ್ಥಳೀಯ ಅಪಾಯ ಪತ್ತೆಯಾಗಿದೆ."
        ),
        "monitored_pests": pests,
    }
