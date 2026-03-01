from app.services.alert_service import generate_alerts


def fuse_advisory(raw_results: dict, language: str = "en"):
    rainfall = raw_results.get("rainfall")
    pest = raw_results.get("pest")

    # 1. Generate Alerts (pass full raw_results for cross-validation)
    alerts = generate_alerts(raw_results, language=language)

    # 2. Determine Highest Risk & Inject UI metadata
    highest_risk = "LOW"
    main_icon = "check_circle"
    main_color = "#10B981"  # Green

    for alert in alerts:
        # Map sub-service icons/colors if not already set (fallback logic)
        if not alert.get("icon"):
            alert["icon"] = (
                "warning_amber"
                if alert["priority_level"] == "MEDIUM"
                else "error_outline"
            )
        if not alert.get("color_code"):
            alert["color_code"] = (
                "#F59E0B" if alert["priority_level"] == "MEDIUM" else "#EF4444"
            )

        if alert["priority_level"] == "HIGH":
            highest_risk = "HIGH"
            main_icon = alert.get("icon", "report_problem")
            main_color = "#EF4444"  # Red
        elif alert["priority_level"] == "MEDIUM" and highest_risk != "HIGH":
            highest_risk = "MEDIUM"
            main_icon = "warning"
            main_color = "#F59E0B"  # Orange

    # 3. Bilingual Main Status
    if language == "kn":
        msg = (
            "ಪರಿಸ್ಥಿತಿಗಳು ಗಂಭೀರವಾಗಿವೆ. ದಯವಿಟ್ಟು ಎಚ್ಚರಿಕೆಗಳನ್ನು ಪರಿಶೀಲಿಸಿ."
            if highest_risk == "HIGH"
            else "ಪರಿಸ್ಥಿತಿಗಳು ಅನುಕೂಲಕರವಾಗಿವೆ."
        )
    else:
        msg = (
            "Conditions are critical. Please check alerts."
            if highest_risk == "HIGH"
            else "Conditions are favorable."
        )

    main_status = {
        "risk_level": highest_risk,
        "message": msg,
        "icon": main_icon,
        "color_code": main_color,
        "status_label": "High Risk" if highest_risk == "HIGH" else ("Caution" if highest_risk == "MEDIUM" else "Safe")
    }
    if language == "kn":
        main_status["status_label"] = "ಅಪಾಯ" if highest_risk == "HIGH" else ("ಎಚ್ಚರಿಕೆ" if highest_risk == "MEDIUM" else "ಸುರಕ್ಷಿತ")

    # 4. Handle Recommendations (Flatten if dictionary/seasonal format)
    raw_recs = raw_results.get("recommendations")
    final_recs = []
    if isinstance(raw_recs, list):
        final_recs = raw_recs
    elif isinstance(raw_recs, dict):
        # Flatten all seasons into one list for the advisory view
        for season_list in raw_recs.values():
            if isinstance(season_list, list):
                final_recs.extend(season_list)

    confidence_score = 1.0
    for key, result in raw_results.items():
        if isinstance(result, dict) and result.get("status") == "DEGRADED":
            confidence_score = min(confidence_score, float(result.get("confidence_score", 0.9)))

    return {
        "confidence_score": round(confidence_score, 2),
        "main_status": main_status,
        "rainfall": rainfall if isinstance(rainfall, dict) else {},
        "soil": (
            raw_results.get("soil") if isinstance(raw_results.get("soil"), dict) else {}
        ),
        "pest": pest if isinstance(pest, dict) else {},
        "crop_calendar": (
            raw_results.get("calendar")
            if isinstance(raw_results.get("calendar"), dict)
            else {}
        ),
        "market_prices": (
            raw_results.get("market")
            if isinstance(raw_results.get("market"), dict)
            else {}
        ),
        "weather": (
            raw_results.get("weather")
            if isinstance(raw_results.get("weather"), dict)
            else {}
        ),
        "udupi_intelligence": {
            "satellite_monitoring": (
                raw_results.get("ndvi")
                if isinstance(raw_results.get("ndvi"), dict)
                else {}
            ),
            "government_schemes": (
                raw_results.get("schemes")
                if isinstance(raw_results.get("schemes"), list)
                else []
            ),
            "agri_news": (
                raw_results.get("news")
                if isinstance(raw_results.get("news"), list)
                else []
            ),
            "groundwater_status": (
                raw_results.get("groundwater")
                if isinstance(raw_results.get("groundwater"), dict)
                else {}
            ),
            "market_arrivals": (
                raw_results.get("mandi")
                if isinstance(raw_results.get("mandi"), dict)
                else {}
            ),
            "seed_verification": (
                raw_results.get("seed_check")
                if isinstance(raw_results.get("seed_check"), dict)
                else {}
            ),
            "community_node": (
                raw_results.get("community")
                if isinstance(raw_results.get("community"), dict)
                else {}
            ),
            "market_pivot": (
                raw_results.get("market_pivot")
                if isinstance(raw_results.get("market_pivot"), dict)
                else {}
            ),
        },
        "recommendations": final_recs,
        "alerts": alerts,
        "ui_config": {
            "theme": "premium_glass",
            "header_blur": True,
            "primary_gradient": [main_color, "#1F2937"],
            "dashboard_vfx": True
        }
    }
