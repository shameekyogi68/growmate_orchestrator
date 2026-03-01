"""
GrowMate Static Agronomy Knowledge Base
Contains localized crop timelines, soil corrective measures, and pest control toolkits
specific to Udupi and Coastal Karnataka. (Fulfills Project Proposal Phase 2: Static Knowledge)
"""

CROP_KNOWLEDGE = {
    "Paddy": {
        "soil": {
            "suitable_ph": [5.5, 6.5],
            "corrective_measures": {
                "low_ph": "Apply 500kg of Agriculture Lime per acre during land preparation.",
                "deficiency_nitrogen": "Apply Urea (Top dressing) at 20th and 40th day.",
                "deficiency_phosphorus": "Apply DAP as a basal dose during puddling.",
            },
            "kn": {
                "low_ph": "ಜಮೀನು ತಯಾರಿಕೆಯ ಸಮಯದಲ್ಲಿ ಎಕರೆಗೆ 500 ಕೆಜಿ ಸುಣ್ಣವನ್ನು ಬಳಸಿ.",
                "deficiency_nitrogen": "ನಾಟಿಯಾದ 20 ಮತ್ತು 40ನೇ ದಿನಗಳಲ್ಲಿ ಯೂರಿಯಾವನ್ನು ಬಳಸಿ (ಮೇಲುಗೊಬ್ಬರ).",
                "deficiency_phosphorus": "ಗದ್ದೆ ಹದ ಮಾಡುವಾಗ ಡಿಎಪಿ (DAP) ಗೊಬ್ಬರವನ್ನು ಬಳಸಿ.",
            },
        },
        "pests": [
            {
                "name": "Brown Plant Hopper (BPH)",
                "symptoms": "Hopper burn, drying of leaves in circular patches.",
                "control": "Avoid excessive nitrogen, drain water, or use Pymetrozine.",
                "kn_name": "ಕಂದು ಬೆನ್ನು ಜಿಗಿ ಹುಳು",
                "kn_control": "ಅತಿಯಾದ ಸಾರಜನಕ ಬಳಕೆಯನ್ನು ತಪ್ಪಿಸಿ, ನೀರನ್ನು ಬಸಿದು ಹಾಕಿ ಅಥವಾ ಪೈಮೆಟ್ರೋಜೈನ್ ಬಳಸಿ.",
            },
            {
                "name": "Stem Borer",
                "symptoms": "Dead hearts (young plants), white ears (flowering stage).",
                "control": "Install pheromone traps or use Chlorantraniliprole.",
                "kn_name": "ಕಾಂಡ ಕೊರಕ",
                "kn_control": "ಪಿರಮೋನ್ ಟ್ರ್ಯಾಪ್‌ಗಳನ್ನು ಅಳವಡಿಸಿ ಅಥವಾ ಕ್ಲೋರಾಂಟ್ರಾನಿಲಿಪ್ರೋಲ್ ಬಳಸಿ.",
            },
        ],
    }
}


def get_local_crop_advice(crop: str, factor: str, language: str = "en"):
    """Fetches local agronomy data for a specific crop and factor (soil, pest, etc.)"""
    crop_data = CROP_KNOWLEDGE.get(crop)
    if not crop_data:
        crop_data = CROP_KNOWLEDGE["Paddy"]

    advice = crop_data.get(factor, {})

    if factor == "soil" and language == "kn":
        return advice.get("kn", advice)
    return advice
