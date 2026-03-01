# GrowMate Backend Integration Contract
> Extracted from source code. Version: 2.1.0
> **Rule**: Frontend must never invent data, infer conditions, or recalculate priorities. Only render what the backend sends.

---

## BASE URL

```
https://growmate-backend.onrender.com
```

OpenAPI docs: `{BASE_URL}/docs`

---

## AUTH MECHANISM

All protected endpoints require:

```
Authorization: Bearer <jwt_token>
```

- Algorithm: `HS256`
- Expiry: `1440 minutes` (24 hours)
- JWT Payload fields: `sub` (user_id), `phone_number`, `active_crop`, `active_sowing_date`, `iat`, `exp`

### Auth Error Responses
| Status | Detail |
|--------|--------|
| `401` | `"Invalid or missing token"` |
| `401` | `"Token has expired"` |
| `401` | `"Invalid token"` |

---

## ENDPOINTS

### 1. POST `/user/register`
**Auth:** None

**Request Body:**
```json
{
  "phone_number": "9876543210",
  "password": "optional_password",
  "full_name": "Farmer Name",
  "language": "en",
  "latitude": 13.8,
  "longitude": 74.6,
  "active_crop": "Paddy",
  "active_sowing_date": "2026-01-15",
  "quick_pin": "1234"
}
```

**Success Response `200`:**
```json
{
  "status": "registered",
  "user_id": "42",
  "token": "<jwt>",
  "profile": {
    "full_name": "Farmer Name",
    "language": "en"
  }
}
```

**Error Responses:**
| Status | Detail |
|--------|--------|
| `409` | `"Phone number already registered"` |
| `500` | `"Registration failed internally"` |

---

### 2. POST `/user/login`
**Auth:** None

**Request Body:**
```json
{
  "phone_number": "9876543210",
  "password": "password123"
}
```

**Success Response `200`:**
```json
{
  "status": "authenticated",
  "user_id": "42",
  "token": "<jwt>",
  "profile": {
    "full_name": "Farmer Name",
    "language": "en",
    "active_crop": "Paddy",
    "active_sowing_date": "2026-01-15"
  }
}
```

**Error Responses:**
| Status | Detail |
|--------|--------|
| `404` | `"User not found. Please register first."` |
| `401` | `"Invalid credentials"` |
| `500` | `"Login failed internally"` |

---

### 3. POST `/user/quick-login`
**Auth:** None

**Request Body:**
```json
{
  "phone_number": "9876543210",
  "pin": "1234"
}
```

**Response:** Same as `/user/login` (status, token, profile)

**Error:**
| Status | Detail |
|--------|--------|
| `401` | `"Invalid PIN or phone number"` |

---

### 4. GET `/user/profile`
**Auth:** Required

**Response `200`:**
```json
{
  "full_name": "Farmer Name",
  "language": "en",
  "latitude": 13.8,
  "longitude": 74.6,
  "active_crop": "Paddy",
  "active_sowing_date": "2026-01-15"
}
```

**Error:**
| Status | Detail |
|--------|--------|
| `404` | `"User not found"` |

---

### 5. PATCH `/user/profile`
**Auth:** Required

**Request Body** (all fields optional):
```json
{
  "full_name": "New Name",
  "language": "kn",
  "latitude": 13.9,
  "longitude": 74.7
}
```

**Response `200`:**
```json
{
  "status": "success",
  "updated_fields": ["full_name", "language"]
}
```

---

### 6. GET `/user/crops`
**Auth:** Required

**Response `200`:**
```json
[
  {
    "id": 1,
    "crop_name": "Paddy",
    "variety": "MO-4",
    "sowing_date": "2026-01-15",
    "latitude": 13.8,
    "longitude": 74.6,
    "is_primary": true
  }
]
```

---

### 7. POST `/user/crops`
**Auth:** Required

**Request Body:**
```json
{
  "crop_name": "Paddy",
  "variety": "MO-4",
  "sowing_date": "2026-01-15",
  "latitude": 13.8,
  "longitude": 74.6,
  "is_primary": true
}
```

**Response `200`:**
```json
{
  "status": "success",
  "crop_id": 1
}
```

**Errors:**
| Status | Detail |
|--------|--------|
| `500` | `"Database unavailable"` |
| `500` | `"Database failure"` |

---

### 8. PATCH `/user/crops/{crop_id}/set-primary`
**Auth:** Required

**Response `200`:**
```json
{
  "status": "success",
  "message": "Primary crop updated and synced"
}
```

---

### 9. DELETE `/user/crops/{crop_id}`
**Auth:** Required

**Response `200`:**
```json
{
  "status": "success"
}
```

---

### 10. POST `/farmer-advisory`
**Auth:** Required
> **Critical endpoint.** Orchestrates 13 parallel data streams.

**Request Body:**
```json
{
  "user_id": "42",
  "latitude": 13.8,
  "longitude": 74.6,
  "date": "2026-03-01",
  "crop": "Paddy",
  "variety": "MO-4",
  "language": "en",
  "intelligence_only": false,
  "sowing_date": "2026-01-15"
}
```

**Success Response `200`:**
```json
{
  "status": "success",
  "confidence_score": 1.0,
  "main_status": {
    "risk_level": "HIGH | MEDIUM | LOW",
    "message": "Conditions are critical. Please check alerts.",
    "icon": "report_problem | warning | check_circle",
    "color_code": "#EF4444 | #F59E0B | #10B981",
    "status_label": "High Risk | Caution | Safe"
  },
  "rainfall": { "...": "upstream rainfall payload or DEGRADED object" },
  "soil": {},
  "pest": {},
  "crop_calendar": {},
  "market_prices": {},
  "weather": {},
  "udupi_intelligence": {
    "satellite_monitoring": {},
    "government_schemes": [],
    "agri_news": [],
    "groundwater_status": {},
    "market_arrivals": {},
    "seed_verification": {},
    "community_node": {},
    "market_pivot": {}
  },
  "recommendations": [{ "...": "..." }],
  "alerts": [
    {
      "priority_level": "CRITICAL | HIGH | MEDIUM | LOW",
      "should_notify": true,
      "source": "rainfall | pest | soil | weather",
      "message": "Alert message text",
      "icon": "warning_amber | error_outline",
      "color_code": "#F59E0B | #EF4444",
      "action_text": "Take Action"
    }
  ],
  "partial_data": false,
  "service_health": {
    "rainfall_api": "closed | open | half_open"
  },
  "last_updated": "2026-03-01T09:00:00+00:00",
  "ui_config": {
    "theme": "premium_glass",
    "header_blur": true,
    "primary_gradient": ["#10B981", "#1F2937"],
    "dashboard_vfx": true
  }
}
```

**DEGRADED Sub-Object** (when a data stream fails):
```json
{
  "status": "DEGRADED",
  "message": "Rainfall data unavailable",
  "confidence_score": 0.5,
  "source": "rainfall"
}
```

**Error Responses:**
| Status | Detail |
|--------|--------|
| `429` | `"Too many requests per IP"` |
| `429` | `"Too many requests per user"` |

---

### 11. GET `/supported-crops`
**Auth:** None

**Query Params:**
| Param | Type | Default |
|-------|------|---------|
| `latitude` | float | `13.8` |
| `longitude` | float | `74.6` |
| `date` | string | null |
| `language` | string | `"en"` |

**Response `200`:**
```json
{
  "status": "success",
  "location": "Udupi",
  "date": "2026-03-01",
  "seasonal_groups": [
    {
      "season": "kharif",
      "crops": ["Paddy", "Maize"]
    }
  ],
  "render_hints": {
    "layout": "grid",
    "theme": "premium_glass",
    "animations": true
  }
}
```

---

### 12. GET `/health`
**Auth:** None

**Response `200`:**
```json
{
  "status": "healthy",
  "version": "2.1.0",
  "environment": "production",
  "database": "connected | disconnected (DB-less mode)",
  "circuit_breakers": {
    "service_name": "closed | open | half_open"
  },
  "timestamp": "2026-03-01T09:00:00+00:00"
}
```

---

## CONFIDENCE SCORE RULES

| Value | Frontend Display |
|-------|-----------------|
| `> 0.8` | Green badge — "High Confidence" |
| `0.5 – 0.8` | Amber badge — "Partial Data" |
| `< 0.5` | Red badge — "DEGRADED — Data Unavailable" |

---

## PRIORITY LEVEL COLOR MAPPING

| Backend `priority_level` | Color | Hex |
|--------------------------|-------|-----|
| `CRITICAL` | dangerRed | `#EF4444` |
| `HIGH` | warningAmber | `#F59E0B` |
| `MEDIUM` | infoBlue | `#1565C0` |
| `LOW` | successGreen | `#10B981` |

---

## LANGUAGE SUPPORT

| Code | Language |
|------|----------|
| `"en"` | English |
| `"kn"` | Kannada |

---

## RATE LIMITS

| Scope | Limit |
|-------|-------|
| Per IP | 100 requests/minute |
| Per User token | 30 requests/minute |

HTTP `429` returned on breach.
