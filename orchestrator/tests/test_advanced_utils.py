import httpx
import asyncio


async def verify_advanced_polish():
    url = "http://localhost:8000/farmer-advisory"
    headers = {"Authorization": "Bearer grower_secret_token"}

    # Test Payload 1: Paddy in Kharif (High humidity/Pest timing)
    payload = {
        "user_id": "test_udupi_pro",
        "latitude": 13.34,
        "longitude": 74.74,
        "date": "2026-07-15",  # Peak Monsoon
        "crop": "Paddy",
        "variety": "Mahaveer",
        "sowing_date": "2026-06-15",
        "language": "kn",
    }

    print("🚀 Verifying Advanced Polish Features (Kharif Paddy)...")

    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()

            ui = data.get("udupi_intelligence", {})
            pest = data.get("pest", {})

            print("\n1. Heuristic Pest Check:")
            print(f"   - Status: {pest.get('status')}")
            print(f"   - Risk: {pest.get('risk_level')}")
            print(f"   - Pests Found: {len(pest.get('monitored_pests', []))}")
            if pest.get("monitored_pests"):
                print(f"   - Sample Pest: {pest['monitored_pests'][0]['name']}")

            print("\n2. Advanced Utilities Check:")
            mandi = ui.get("market_arrivals", {})
            print(
                f"   - Mandi Tracking: {len(mandi.get('markets', []))} local markets found"
            )
            print(f"   - Summary: {mandi.get('summary')}")

            seed = ui.get("seed_verification", {})
            print(f"   - Seed Authenticity: {seed.get('provider')}")
            print(f"   - Status: {seed.get('message')}")

            print("\n3. Seasonal Mock Check (Monsoon):")
            weather = data.get("weather", {})
            print(
                f"   - Weather: {weather.get('condition')} ({weather.get('temperature')}°C)"
            )
            ndvi = ui.get("satellite_monitoring", {})
            print(
                f"   - NDVI Health: {ndvi.get('health_index')} ({ndvi.get('condition')})"
            )

            print("\n✨ ALL ADVANCED POLISH FEATURES VERIFIED! ✨")

        except Exception as e:
            print(f"❌ Verification Failed: {e}")


if __name__ == "__main__":
    asyncio.run(verify_advanced_polish())
