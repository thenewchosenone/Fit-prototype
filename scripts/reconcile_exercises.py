#!/usr/bin/env python3
"""Generate a deterministic iOS/web exercise identifier reconciliation report."""

from __future__ import annotations

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MIGRATION = ROOT / "supabase/migrations/202607140002_exercise_catalog.sql"
OUTPUT = ROOT / "docs/exercise-identifier-reconciliation.csv"


def slug(value: str) -> str:
    return re.sub(r"(^-|-$)", "", re.sub(r"[^a-z0-9]+", "-", value.lower()))


def ios_rows() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    for relative in (
        "LiftRankApp/MockData/MockData.swift",
        "LiftRankApp/MockData/PopularExerciseCatalog.swift",
        "LiftRankApp/MockData/WorkoutProgramCatalog.swift",
    ):
        text = (ROOT / relative).read_text()
        rows.extend((identifier, name, "ios") for identifier, name in re.findall(
            r'TrainingExerciseCatalogItem\(id:\s*"([^"]+)",\s*name:\s*"([^"]+)"', text
        ))
        if relative.endswith("PopularExerciseCatalog.swift"):
            rows.extend((identifier, name, "ios") for identifier, name in re.findall(
                r'\("([a-z0-9_]+)",\s*"([^"]+)",\s*"[^"]+",\s*"[^"]+",\s*"[^"]+"\)', text
            ))
    return rows


def web_rows() -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    data = (ROOT / "src/data.ts").read_text()
    rows.extend((identifier, name, "web") for identifier, name in re.findall(
        r'\["([a-z0-9-]+)",\s*"([^"]+)"', data
    ))

    catalog = (ROOT / "src/catalog.ts").read_text()
    for body_part, equipment, names in re.findall(
        r'bodyPart:\s*"([^"]+)"[^\n]+equipment:\s*"([^"]+)"[^\n]+names:\s*"([^"]+)"', catalog
    ):
        for name in names.split("|"):
            identifier = f"catalog-{slug(body_part)}-{slug(equipment)}-{slug(name)}"
            rows.append((identifier, name, "web"))
    return rows


SPECIAL = {
    "Barbell Bench Press": "barbell-bench-press",
    "Incline Bench Press": "incline-barbell-bench-press",
    "Conventional Deadlift": "conventional-deadlift",
    "Overhead Press": "standing-barbell-overhead-press",
    "Dumbbell Bench Press": "dumbbell-bench-press",
    "Machine Chest Press": "machine-chest-press",
    "Lying Leg Curl": "lying-leg-curl",
    "Barbell Hip Thrust": "barbell-hip-thrust",
    "Seated Cable Row": "seated-cable-row",
    "Dumbbell Lateral Raise": "dumbbell-lateral-raise",
    "Cable Face Pull": "cable-face-pull",
    "Tricep Pushdown": "triceps-pushdown",
    "Triceps Pressdown": "triceps-pushdown",
}


def ranking_movement(name: str) -> str:
    return {
        "Barbell Bench Press": "bench_press",
        "Back Squat": "back_squat",
        "Conventional Deadlift": "deadlift",
        "Sumo Deadlift": "deadlift",
        "Overhead Press": "overhead_press",
        "Standing Barbell Overhead Press": "overhead_press",
    }.get(name, "")


def main() -> None:
    source_rows = sorted(set(ios_rows() + web_rows()), key=lambda row: (row[2], row[0], row[1]))
    migration = MIGRATION.read_text()
    seeded = set(re.findall(r"\('([a-z0-9-]+)',\s*'[^']+'", migration))
    identifiers_to_names: dict[str, set[str]] = {}
    names_to_ids: dict[str, set[str]] = {}
    for identifier, name, _ in source_rows:
        identifiers_to_names.setdefault(identifier, set()).add(name)
        names_to_ids.setdefault(name.casefold(), set()).add(identifier)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with OUTPUT.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow((
            "existing_identifier", "source_platform", "display_name",
            "proposed_canonical_identifier", "classification", "ranking_movement",
            "seeded_in_migration_2",
        ))
        for identifier, name, platform in source_rows:
            canonical = SPECIAL.get(name, slug(name))
            if len(identifiers_to_names[identifier]) > 1:
                classification = "unresolved"
            elif identifier == canonical:
                classification = "exact"
            elif len(names_to_ids[name.casefold()]) > 1:
                classification = "duplicate"
            else:
                classification = "alias"
            writer.writerow((
                identifier, platform, name, canonical, classification,
                ranking_movement(name), "yes" if canonical in seeded else "no",
            ))


if __name__ == "__main__":
    main()

