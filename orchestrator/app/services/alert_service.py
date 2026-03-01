def generate_alerts(raw_results: dict, language: str = "en"):
    alerts = []

    rainfall_data = raw_results.get("rainfall", {})
    pest_data = raw_results.get("pest", {})
    soil_data = raw_results.get("soil", {})
    weather_data = raw_results.get("weather", {})

    # --- 1. RAINFALL ALERTS ---
    main_status = (
        rainfall_data.get("main_status", {}) if isinstance(rainfall_data, dict) else {}
    )
    rainfall_priority = main_status.get("priority", "LOW")

    if rainfall_priority == "HIGH":
        if language == "kn":
            msg = (
                f"ಹೆಚ್ಚಿನ ಮಳೆ/ಹವಾಮಾನ ಅಪಾಯ: {main_status.get('message', 'ಜಾಗರೂಕರಾಗಿರಿ')}"
            )
        else:
            msg = f"High Weather Risk: {main_status.get('message', 'Take precautions')}"

        alerts.append(
            {
                "priority_level": "HIGH",
                "should_notify": True,
                "source": "rainfall",
                "message": msg,
            }
        )

    # --- 2. PEST x WEATHER FUSION ---
    # Escalate pest risk if high humidity or rain detected
    pest_risk = (
        pest_data.get("risk_level", "LOW") if isinstance(pest_data, dict) else "LOW"
    )

    # Hyper-defensive extraction
    weather_cond = ""
    humidity = 0
    if isinstance(weather_data, dict):
        weather_cond = weather_data.get("condition", "").lower()
        humidity = weather_data.get("humidity", 0)

    is_conducive = "rain" in weather_cond or humidity > 80

    if pest_risk == "MEDIUM" and is_conducive:
        pest_risk = "HIGH"
        if language == "kn":
            fusion_msg = "ಹೆಚ್ಚಿನ ಆರ್ದ್ರತೆಯಿಂದಾಗಿ ಕೀಟಗಳ ಅಪಾಯ ಹೆಚ್ಚಾಗಿದೆ."
        else:
            fusion_msg = (
                "Pest risk escalated to HIGH due to high humidity/rain forecast."
            )

        alerts.append(
            {
                "priority_level": "HIGH",
                "should_notify": True,
                "source": "fusion_intelligence",
                "message": fusion_msg,
            }
        )

    if pest_risk == "HIGH" and isinstance(pest_data, dict):
        if language == "kn":
            msg = f"ಕೀಟದ ಅಪಾಯ: {pest_data.get('pest_name', 'ಕೀಟಗಳು')} ಪತ್ತೆಯಾಗಿದೆ."
        else:
            msg = f"Pest Risk: {pest_data.get('pest_name', 'pests')} detected."

        alerts.append(
            {
                "priority_level": "HIGH",
                "should_notify": True,
                "source": "pest",
                "message": msg,
            }
        )

    # --- 3. SOIL x WEATHER FUSION (Irrigation & Fertilizer Conflict) ---
    # Only run if both Rainfall/Soil and Weather data are available
    if isinstance(rainfall_data, dict) and isinstance(weather_data, dict):
        rainfall_soil = rainfall_data.get("soil_status", {})
        needs_water = rainfall_soil.get("irrigation_needed", False)
        expects_rain = "rain" in weather_cond or "ಮಳೆ" in weather_cond

        if needs_water and expects_rain:
            if language == "kn":
                msg = "ನೀರಾವರಿ ವಿಳಂಬಿಸಿ: ಮಳೆ ಮುನ್ಸೂಚನೆ ಇದೆ. ನೀರನ್ನು ಉಳಿಸಿ."
            else:
                msg = "Delayed Irrigation: Rain is forecasted. Save water and avoid waterlogging."
            alerts.append(
                {
                    "priority_level": "MEDIUM",
                    "should_notify": True,
                    "source": "fusion_intelligence",
                    "message": msg,
                }
            )

        # Fertilizer Washout Protection
        soil_recommend = (
            soil_data.get("soil_correction_recommendations", {})
            if isinstance(soil_data, dict)
            else {}
        )
        has_fertilizer = len(soil_recommend.get("recommended_fertilizer", [])) > 0
        is_heavy_rain = "heavy rain" in weather_cond or "ಭಾರಿ ಮಳೆ" in weather_cond

        if has_fertilizer and is_heavy_rain:
            if language == "kn":
                msg = "ಗೊಬ್ಬರ ಹಾಕುವುದನ್ನು ವಿಳಂಬಿಸಿ: ಭಾರಿ ಮಳೆಯಿಂದಾಗಿ ಗೊಬ್ಬರ ತೊಳೆದು ಹೋಗಬಹುದು."
            else:
                msg = "Delay Fertilization: Heavy rain forecast may cause nutrient washout."
            alerts.append(
                {
                    "priority_level": "HIGH",
                    "should_notify": True,
                    "source": "fusion_intelligence",
                    "message": msg,
                }
            )

    # --- 4. PEST x WEATHER FUSION (Drift Protection) ---
    wind_speed = (
        weather_data.get("wind_speed", 0) if isinstance(weather_data, dict) else 0
    )
    has_spray = False
    if isinstance(pest_data, dict):
        for p in pest_data.get("monitored_pests", []):
            if "spray" in p.get("action", "").lower() or "ಸಿಂಪಡಿಸಿ" in p.get(
                "action", ""
            ):
                has_spray = True
                break

    if has_spray and wind_speed > 20:
        if language == "kn":
            msg = (
                "ಸಿಂಪಡಿಸುವುದನ್ನು ತಪ್ಪಿಸಿ: ಗಾಳಿಯ ವೇಗ ಹೆಚ್ಚಾಗಿದೆ, ಔಷಧಿಯು ವ್ಯರ್ಥವಾಗಬಹುದು."
            )
        else:
            msg = "Avoid Spraying: High wind speed detected (>20km/h). Spraying will be ineffective and lead to drift."
        alerts.append(
            {
                "priority_level": "MEDIUM",
                "should_notify": True,
                "source": "fusion_intelligence",
                "message": msg,
            }
        )

    # --- 5. FARMER SAFETY (UV & Heat) ---
    uv_index = weather_data.get("uv_index", 0) if isinstance(weather_data, dict) else 0
    temp = weather_data.get("temperature", 0) if isinstance(weather_data, dict) else 0

    if uv_index > 7 or temp > 35:
        if language == "kn":
            msg = "ರೈತರ ಸುರಕ್ಷಿತೆ: ಬಿಸಿಲು ಹೆಚ್ಚಾಗಿದೆ. ತಲೆಗೆ ಟೋಪಿ ಬಳಸಿ ಮತ್ತು ಹೆಚ್ಚಿನ ನೀರು ಕುಡಿಯಿರಿ."
        else:
            msg = f"Farmer Safety: High {'Heat' if temp > 35 else 'UV'} detected. Wear a hat, stay hydrated, and take breaks in shade."
        alerts.append(
            {
                "priority_level": "MEDIUM",
                "should_notify": True,
                "source": "farmer_wellness",
                "message": msg,
            }
        )

    # --- 6. SATELLITE GROWTH MONITORING (NDVI x Calendar) ---
    ndvi_data = raw_results.get("ndvi", {})
    calendar_data = raw_results.get("calendar", {})

    if isinstance(ndvi_data, dict) and isinstance(calendar_data, dict):
        ndvi_score = ndvi_data.get("health_index", 0)
        # Extract current phase from calendar progress
        current_phase = (
            calendar_data.get("progress", {}).get("current_phase", "").lower()
        )

        # If phase is High Growth (Vegetative) but NDVI is low (< 0.5)
        if current_phase == "vegetative" and ndvi_score < 0.5:
            if language == "kn":
                msg = "ಬೆಳವಣಿಗೆ ಕುಂಠಿತ ಎಚ್ಚರಿಕೆ: ಉಪಗ್ರಹ ಮಾಹಿತಿಯು ನಿರೀಕ್ಷಿತಕ್ಕಿಂತ ಕಡಿಮೆ ಹಸಿರನ್ನು ತೋರಿಸುತ್ತಿದೆ. ದಯವಿಟ್ಟು ಪೋಷಕಾಂಶಗಳ ಕೊರತೆಯನ್ನು ಪರಿಶೀಲಿಸಿ."
            else:
                msg = "Growth Retardation Alert: Satellite data shows lower-than-expected greenness for this growth stage. Please check for nutrient deficiency or hidden stress."

            alerts.append(
                {
                    "priority_level": "MEDIUM",
                    "should_notify": True,
                    "source": "fusion_intelligence",
                    "message": msg,
                }
            )

    # -------------------------------------------------------------------------
    # Rule 7: Extreme Event Detection (Cyclone/Flood/Storm)
    # -------------------------------------------------------------------------
    weather = raw_results.get("weather", {})
    conditions = weather.get("conditions", "").lower()
    extreme_keywords = ["cyclone", "flood", "storm", "hurricane", "tornado"]

    if any(k in conditions for k in extreme_keywords):
        alerts.append(
            {
                "priority_level": "HIGH",
                "should_notify": True,
                "source": "IMD Weather Watch",
                "message": (
                    "URGENT: Extreme weather detected! Drain field water immediately and move equipment to high ground."
                    if language == "en"
                    else "ತುರ್ತು: ತೀವ್ರ ಹವಾಮಾನ ಪತ್ತೆಯಾಗಿದೆ! ಹೊಲದ ನೀರನ್ನು ತಕ್ಷಣವೇ ಹರಿಸಿರಿ ಮತ್ತು ಉಪಕರಣಗಳನ್ನು ಎತ್ತರದ ಪ್ರದೇಶಕ್ಕೆ ಸರಿಸಿ."
                ),
                "icon": "cyclone",
                "color_code": "#EF4444",
            }
        )

    # -------------------------------------------------------------------------
    # Rule 8: Price Crash Alert
    # -------------------------------------------------------------------------
    market = raw_results.get("market", {})
    price_status = market.get("price_status", "")
    if "Crash" in price_status or "falling" in price_status.lower():
        alerts.append(
            {
                "priority_level": "MEDIUM",
                "should_notify": True,
                "source": "Mandi IQ",
                "message": (
                    "Market alert: Sudden price drop detected. Consider holding your produce in storage."
                    if language == "en"
                    else "ಮಾರುಕಟ್ಟೆ ಎಚ್ಚರಿಕೆ: ಬೆಲೆಗಳಲ್ಲಿ ಹಠಾತ್ ಕುಸಿತ ಪತ್ತೆಯಾಗಿದೆ. ನಿಮ್ಮ ಬೆಳೆಯನ್ನು ಸಂಗ್ರಹಿಸಿಡಲು ಪರಿಗಣಿಸಿ."
                ),
                "icon": "trending_down",
                "color_code": "#F59E0B",
            }
        )

    # -------------------------------------------------------------------------
    # Rule 9: Harvest Window Race (Weather Window Closing)
    # -------------------------------------------------------------------------
    # Only relevant for crops in late stage (e.g. > 90 days)
    # Check if next 48h is clear but next 3-7 days have 'Heavy Rain'
    rainfall_intel = raw_results.get("rainfall", {}).get("intelligence", {})
    rain_forecast = raw_results.get("rainfall", {}).get("forecast", [])

    # Simulate identifying late stage from calendar if provided
    is_late_stage = "harvest" in str(raw_results.get("calendar", "")).lower()

    if is_late_stage and len(rain_forecast) >= 5:
        next_48h_rain = any("Heavy" in str(d.get("status")) for d in rain_forecast[:2])
        future_heavy_rain = any(
            "Heavy" in str(d.get("status")) for d in rain_forecast[2:7]
        )

        if not next_48h_rain and future_heavy_rain:
            alerts.append(
                {
                    "priority_level": "HIGH",
                    "should_notify": True,
                    "source": "Weather Window Guard",
                    "message": (
                        "URGENT Harvest Window: 3-day heavy rain predicted in 48h. Harvest immediately to save your crop!"
                        if language == "en"
                        else "ತುರ್ತು ಕೊಯ್ಲು ಸಮಯ: 48 ಗಂಟೆಗಳಲ್ಲಿ 3 ದಿನಗಳ ಭಾರಿ ಮಳೆ ಮುನ್ಸೂಚನೆ ಇದೆ. ನಿಮ್ಮ ಬೆಳೆಯನ್ನು ಉಳಿಸಲು ತಕ್ಷಣವೇ ಕೊಯ್ಲು ಮಾಡಿ!"
                    ),
                    "icon": "speed",
                    "color_code": "#FACC15",  # Yellow/Warning
                }
            )

    # -------------------------------------------------------------------------
    # Rule 10: Insurance Trigger (30-day Drought Detection)
    # -------------------------------------------------------------------------
    rain_status = rainfall_intel.get("rainfall_status", "")
    if "Deficit" in rain_status or "Stress" in rain_status:
        alerts.append(
            {
                "priority_level": "MEDIUM",
                "should_notify": False,  # Just a dashboard flag, not a push notify
                "source": "Insurance Sentinel",
                "message": (
                    "30-day moisture deficit detected. Weather Evidence Report generated for PM-FBY Insurance claim."
                    if language == "en"
                    else "30 ದಿನಗಳ ತೇವಾಂಶದ ಕೊರತೆ ಪತ್ತೆಯಾಗಿದೆ. PM-FBY ವಿಮಾ ಕ್ಲೈಮ್‌ಗಾಗಿ ಹವಾಮಾನ ಪುರಾವೆ ವರದಿಯನ್ನು ಸಿದ್ಧಪಡಿಸಲಾಗಿದೆ."
                ),
                "icon": "assignment",
                "color_code": "#6366F1",  # Indigo
                "action": "download_insurance_report",
            }
        )

    # -------------------------------------------------------------------------
    # Rule 11: Input Scarcity (Inventory Alert)
    # -------------------------------------------------------------------------
    # Simulate a check against local cooperative stock levels
    # (In a real system, this would be an external API call)
    scarcity_simulation = ["Urea", "Potash"]  # Simulate these as Out of Stock

    calendar_tasks = str(raw_results.get("calendar", "")).lower()
    for item in scarcity_simulation:
        if item.lower() in calendar_tasks:
            alerts.append(
                {
                    "priority_level": "MEDIUM",
                    "should_notify": True,
                    "source": "Cooperative Watch",
                    "message": (
                        f"Inventory Alert: {item} is currently out of stock at your local node. Use Organic Compost or Neem Cake as a temporary alternative."
                        if language == "en"
                        else f"ದಾಸ್ತಾನು ಎಚ್ಚರಿಕೆ: ನಿಮ್ಮ ಸ್ಥಳೀಯ ಕೇಂದ್ರದಲ್ಲಿ {item} ಸದ್ಯಕ್ಕೆ ಸ್ಟಾಕ್ ಇಲ್ಲ. ತಾತ್ಕಾಲಿಕ ಪರ್ಯಾಯವಾಗಿ ಸಾವಯವ ಗೊಬ್ಬರ ಅಥವಾ ಬೇವಿನ ಹಿಂಡಿಯನ್ನು ಬಳಸಿ."
                    ),
                    "icon": "inventory_2",
                    "color_code": "#10B981",  # Emerald
                }
            )

    # -------------------------------------------------------------------------
    # Rule 12: Deadline Sentinel (Calendar Enforcement)
    # -------------------------------------------------------------------------
    # Detect if a critical task is expiring based on crop age
    calendar_res = raw_results.get("calendar", {})
    if isinstance(calendar_res, dict):
        calendar_meta = calendar_res.get("context", {})
        crop_age_days = calendar_meta.get("days_since_sowing", 0)
        days_in_week = crop_age_days % 7

        # If it's the 6th or 7th day of the current week, warn about expiring tasks
        if days_in_week >= 5:
            progress = calendar_res.get("progress", {})
            upcoming = progress.get("upcoming_operation", "")
            if upcoming and "See" not in upcoming:
                alerts.append(
                    {
                        "priority_level": "HIGH",
                        "should_notify": True,
                        "source": "Deadline Sentinel",
                        "message": (
                            f"CRITICAL: Only {7 - days_in_week} days left for this week's task: {upcoming}. Complete now to avoid yield loss."
                            if language == "en"
                            else f"ನಿರ್ಣಾಯಕ: ಈ ವಾರದ ಕಾರ್ಯಕ್ಕೆ ಕೇವಲ {7 - days_in_week} ದಿನ ಬಾಕಿ ಇದೆ: {upcoming}. ಇಳುವರಿ ನಷ್ಟ ತಪ್ಪಿಸಲು ಈಗಲೇ ಪೂರ್ಣಗೊಳಿಸಿ."
                        ),
                        "icon": "event_busy",
                        "color_code": "#EF4444",
                    }
                )

    # -------------------------------------------------------------------------
    # Rule 13: Weather-Blocked Task Sentinel
    # -------------------------------------------------------------------------
    # If a task is coming up and rain is forecast for the NEXT 48h, push for immediate action
    if isinstance(calendar_res, dict):
        upcoming_task = (
            calendar_res.get("progress", {}).get("upcoming_operation", "").lower()
        )
        needs_dry = any(
            k in upcoming_task
            for k in [
                "spray",
                "fertilizer",
                "urea",
                "pesticide",
                "ಸಿಂಪಡಿಸಿ",
                "ಗೊಬ್ಬರ",
                "water",
                "irrigation",
                "ನೀರಾವರಿ",
            ]
        )

        rain_forecast = raw_results.get("rainfall", {}).get("forecast", [])
        rain_tomorrow = any("Heavy" in str(d.get("status")) for d in rain_forecast[:2])

        if needs_dry and rain_tomorrow:
            alerts.append(
                {
                    "priority_level": "HIGH",
                    "should_notify": True,
                    "source": "Weather-Task Sync",
                    "message": (
                        f"WEATHER ALERT: Final chance to complete {upcoming_task} before heavy rain starts. Apply TODAY!"
                        if language == "en"
                        else f"ಹವಾಮಾನ ಎಚ್ಚರಿಕೆ: ಭಾರಿ ಮಳೆ ಪ್ರಾರಂಭವಾಗುವ ಮೊದಲು {upcoming_task} ಪೂರ್ಣಗೊಳಿಸಲು ಇದು ಕೊನೆಯ ಅವಕಾಶ. ಇಂದೇ ಅನ್ವಯಿಸಿ!"
                    ),
                    "icon": "umbrella",
                    "color_code": "#3B82F6",  # Blue
                }
            )

    return alerts
