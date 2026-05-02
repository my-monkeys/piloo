#!/usr/bin/env python3
"""
Réordonne le board GitHub Project "Piloo MVP" pour qu'un agent qui prend
le premier ticket de la colonne `Todo` attaque le bon travail.

Clé de tri (priorité décroissante) :
  1. type:task avant type:epic   (les epics sont des conteneurs, pas des tâches)
  2. milestone : M1 < M2 < M3 < M4+ < (sans milestone)
  3. priority  : p0 < p1 < p2 < p3 < (sans priorité)
  4. numéro d'issue croissant     (les plus anciennes d'abord à priorité égale)

Usage :
  python3 scripts/reorder-board.py --dry-run   # affiche l'ordre prévu, n'écrit rien
  python3 scripts/reorder-board.py --apply     # applique le réordonnancement

Prérequis :
  gh auth refresh -s project        # le token doit avoir le scope `project`
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time

ORG = "my-monkeys"
PROJECT_NUMBER = 2

MILESTONE_RANK = {"M1": 1, "M2": 2, "M3": 3, "M4+": 4}
PRIORITY_RANK = {"p0": 0, "p1": 1, "p2": 2, "p3": 3}


def gh_graphql(query: str, **variables) -> dict:
    args = ["gh", "api", "graphql", "-f", f"query={query}"]
    for k, v in variables.items():
        if v is None:
            args += ["-F", f"{k}=null"]
        elif isinstance(v, bool):
            args += ["-F", f"{k}={'true' if v else 'false'}"]
        elif isinstance(v, int):
            args += ["-F", f"{k}={v}"]
        else:
            args += ["-f", f"{k}={v}"]
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"gh api graphql failed: {r.stderr}")
    data = json.loads(r.stdout)
    if "errors" in data:
        sys.exit(f"GraphQL errors: {json.dumps(data['errors'], indent=2)}")
    return data["data"]


def get_project_id() -> str:
    q = """
    query($org: String!, $num: Int!) {
      organization(login: $org) { projectV2(number: $num) { id title } }
    }
    """
    d = gh_graphql(q, org=ORG, num=PROJECT_NUMBER)
    p = d["organization"]["projectV2"]
    if not p:
        sys.exit(f"Project not found: {ORG} #{PROJECT_NUMBER}")
    print(f"Project: {p['title']} ({p['id']})")
    return p["id"]


def fetch_items(project_id: str) -> list[dict]:
    q = """
    query($pid: ID!, $cursor: String) {
      node(id: $pid) {
        ... on ProjectV2 {
          items(first: 100, after: $cursor) {
            pageInfo { hasNextPage endCursor }
            nodes {
              id
              content {
                ... on Issue {
                  number
                  title
                  state
                  milestone { title }
                  labels(first: 30) { nodes { name } }
                }
              }
            }
          }
        }
      }
    }
    """
    items, cursor = [], None
    while True:
        d = gh_graphql(q, pid=project_id, cursor=cursor or "")
        page = d["node"]["items"]
        for n in page["nodes"]:
            c = n.get("content") or {}
            if not c.get("number"):
                continue  # draft issue ou autre — on ignore
            labels = [l["name"] for l in (c.get("labels") or {}).get("nodes", [])]
            milestone = (c.get("milestone") or {}).get("title", "")
            ms_short = milestone.split("—")[0].strip() if "—" in milestone else milestone
            priority = next((l.split(":")[1] for l in labels if l.startswith("priority:")), "")
            issue_type = next((l.split(":")[1] for l in labels if l.startswith("type:")), "")
            items.append({
                "item_id": n["id"],
                "number": c["number"],
                "title": c["title"],
                "state": c.get("state"),
                "milestone": ms_short,
                "priority": priority,
                "type": issue_type,
            })
        if not page["pageInfo"]["hasNextPage"]:
            break
        cursor = page["pageInfo"]["endCursor"]
    return items


def sort_key(item: dict) -> tuple:
    type_rank = 1 if item["type"] == "epic" else 0
    ms_rank = MILESTONE_RANK.get(item["milestone"], 99)
    prio_rank = PRIORITY_RANK.get(item["priority"], 99)
    return (type_rank, ms_rank, prio_rank, item["number"])


def move_item(project_id: str, item_id: str, after_id: str | None, max_retries: int = 5) -> None:
    q = """
    mutation($pid: ID!, $iid: ID!, $aid: ID) {
      updateProjectV2ItemPosition(input: {
        projectId: $pid, itemId: $iid, afterId: $aid
      }) { clientMutationId }
    }
    """
    args = ["gh", "api", "graphql", "-f", f"query={q}", "-f", f"pid={project_id}", "-f", f"iid={item_id}"]
    if after_id is None:
        args += ["-F", "aid=null"]
    else:
        args += ["-f", f"aid={after_id}"]
    last_err = ""
    for attempt in range(max_retries):
        r = subprocess.run(args, capture_output=True, text=True)
        if r.returncode == 0:
            try:
                data = json.loads(r.stdout)
            except json.JSONDecodeError:
                last_err = f"non-json response: {r.stdout[:200]}"
            else:
                if "errors" not in data:
                    return
                last_err = json.dumps(data["errors"])
        else:
            last_err = r.stderr.strip()
        wait = 2 ** attempt  # 1, 2, 4, 8, 16
        print(f"  retry {attempt+1}/{max_retries} for item {item_id} after {wait}s — {last_err[:120]}")
        time.sleep(wait)
    sys.exit(f"move failed for item {item_id} after {max_retries} retries: {last_err}")


def main() -> None:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--dry-run", action="store_true", help="affiche l'ordre prévu, n'écrit rien")
    g.add_argument("--apply", action="store_true", help="applique le réordonnancement")
    ap.add_argument("--skip-closed", action="store_true", help="ignore les issues closes")
    args = ap.parse_args()

    project_id = get_project_id()
    items = fetch_items(project_id)
    if args.skip_closed:
        items = [i for i in items if i["state"] != "CLOSED"]
    items.sort(key=sort_key)

    print(f"\nOrdre prévu ({len(items)} items) :\n")
    for i, it in enumerate(items, 1):
        print(f"{i:3d}. #{it['number']:3d} [{it['milestone']:4s}|{it['type']:5s}|{it['priority']:2s}] {it['title']}")

    if args.dry_run:
        print("\n--dry-run : aucune modification appliquée.")
        return

    print(f"\nApplication du réordonnancement ({len(items)} mutations)...")
    prev_id: str | None = None
    for i, it in enumerate(items, 1):
        move_item(project_id, it["item_id"], prev_id)
        if i % 10 == 0:
            print(f"  ... {i}/{len(items)} déplacés")
        prev_id = it["item_id"]
        time.sleep(0.25)  # respect rate limit secondaire (~80 mut/min)
    print(f"\nFait. Vérifie l'ordre sur https://github.com/orgs/{ORG}/projects/{PROJECT_NUMBER}")


if __name__ == "__main__":
    main()
