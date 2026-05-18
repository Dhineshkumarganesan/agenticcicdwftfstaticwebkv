# Release Pipeline Comparison Utility

"""
This script compares the pipeline definitions in cicd/contract.yml between two git refs (commits, tags, or branches)
and generates a human-readable summary of what changed in the release pipeline (jobs, triggers, approvals, etc).

Usage:
    python scripts/compare_release_pipelines.py <ref1> <ref2>

Example:
    python scripts/compare_release_pipelines.py v1.1.0 v1.2.0

Outputs a Markdown summary to stdout.
"""

import sys
import subprocess
import difflib
import yaml


def load_contract_at_ref(ref):
    result = subprocess.run([
        "git", "show", f"{ref}:cicd/contract.yml"
    ], capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error: Could not load contract.yml at {ref}", file=sys.stderr)
        sys.exit(1)
    return yaml.safe_load(result.stdout)


def compare_pipelines(p1, p2):
    summary = []
    # Compare CI jobs
    jobs1 = set(p1.get('ci', {}).get('jobs', []))
    jobs2 = set(p2.get('ci', {}).get('jobs', []))
    added_jobs = jobs2 - jobs1
    removed_jobs = jobs1 - jobs2
    if added_jobs:
        summary.append(f"- Added CI jobs: {', '.join(added_jobs)}")
    if removed_jobs:
        summary.append(f"- Removed CI jobs: {', '.join(removed_jobs)}")
    # Compare CD strategy
    strat1 = p1.get('cd', {}).get('strategy')
    strat2 = p2.get('cd', {}).get('strategy')
    if strat1 != strat2:
        summary.append(f"- Changed CD strategy: {strat1} → {strat2}")
    # Compare approval requirements
    appr1 = set(p1.get('cd', {}).get('approval_required', []))
    appr2 = set(p2.get('cd', {}).get('approval_required', []))
    added_appr = appr2 - appr1
    removed_appr = appr1 - appr2
    if added_appr:
        summary.append(f"- Added approval required for: {', '.join(added_appr)}")
    if removed_appr:
        summary.append(f"- Removed approval required for: {', '.join(removed_appr)}")
    return summary


def main():
    if len(sys.argv) != 3:
        print("Usage: python scripts/compare_release_pipelines.py <ref1> <ref2>")
        sys.exit(1)
    ref1, ref2 = sys.argv[1], sys.argv[2]
    c1 = load_contract_at_ref(ref1)
    c2 = load_contract_at_ref(ref2)
    p1 = c1.get('pipeline', {})
    p2 = c2.get('pipeline', {})
    summary = compare_pipelines(p1, p2)
    print(f"## Release Pipeline Comparison: {ref1} vs {ref2}\n")
    if summary:
        for line in summary:
            print(line)
    else:
        print("No pipeline changes detected.")

if __name__ == "__main__":
    main()
