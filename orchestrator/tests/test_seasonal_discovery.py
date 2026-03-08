import asyncio
from app.services.discovery_service import get_intelligent_crops


async def run_tests():
    test_cases = [
        ("2026-06-15", "Early Kharif"),
        ("2026-08-15", "Mid Kharif"),
        ("2026-09-15", "Late Kharif (Anticipatory)"),
        ("2026-11-15", "Early Rabi"),
        ("2026-02-15", "Late Rabi (Anticipatory)"),
        ("2026-04-15", "Mid Summer"),
    ]

    print("\n=== Intelligent Seasonal Discovery Test ===\n")

    for date, label in test_cases:
        crops_data = await get_intelligent_crops(request_date=date)
        crops = crops_data.get("seasonal_groups", [])
        # Extract crop IDs from the first group if available
        ids = []
        if crops:
            ids = [c["id"] for c in crops[0]["crops"]]
        print(f"Date: {date} ({label})")
        print(f"Recommended Crops: {ids}\n")


if __name__ == "__main__":
    asyncio.run(run_tests())
