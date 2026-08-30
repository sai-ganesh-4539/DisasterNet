"""Scenario mode endpoints for SIH prototype demonstrations."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status

from app.services.demo_scenarios import (
    activate_scenario,
    get_active_scenario,
    list_scenarios,
)

router = APIRouter()


@router.get("/scenarios")
async def get_demo_scenarios():
    return {
        "mode": "DEMO_SCENARIO",
        "active_scenario": get_active_scenario()["scenario_id"],
        "scenarios": list_scenarios(),
    }


@router.get("/current")
async def get_current_demo_scenario():
    scenario = get_active_scenario()
    return {
        "mode": "DEMO_SCENARIO",
        "scenario": {
            "scenario_id": scenario["scenario_id"],
            "name": scenario["name"],
            "description": scenario["description"],
            "geography": scenario["geography"],
            "hazard_mix": scenario["hazard_mix"],
            "bbox": scenario["bbox"],
        },
    }


@router.post("/activate/{scenario_id}")
async def activate_demo_scenario(scenario_id: str):
    try:
        scenario = activate_scenario(scenario_id)
        return {
            "success": True,
            "mode": "DEMO_SCENARIO",
            "active_scenario": scenario_id,
            "scenario": {
                "scenario_id": scenario["scenario_id"],
                "name": scenario["name"],
                "description": scenario["description"],
                "geography": scenario["geography"],
                "hazard_mix": scenario["hazard_mix"],
                "bbox": scenario["bbox"],
            },
        }
    except KeyError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
