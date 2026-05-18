#!/usr/bin/env python3
"""
Audit Logger for Compliance Governance
Logs all compliance decisions to JSON audit trail for auditor access
"""

import json
import os
from datetime import datetime
from pathlib import Path


class ComplianceAuditLogger:
    """Simple audit logger for compliance decisions"""

    def __init__(self, log_path=".github/audit-logs"):
        self.log_path = Path(log_path)
        self.log_path.mkdir(parents=True, exist_ok=True)

    def log_compliance_check(self, details):
        """
        Log a compliance check result

        Args:
            details (dict): Compliance check details with keys:
                - environment (str): dev/test/prod
                - resource (str): Resource name/type
                - status (str): APPROVE/REJECT/CONDITIONAL
                - violations (list): List of violations found
                - compliance_score (float): Score percentage
        """
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "actor": os.getenv("GITHUB_ACTOR", "ci-system"),
            "environment": details.get("environment", "unknown"),
            "resource": details.get("resource", "unknown"),
            "compliance_status": details.get("status", "UNKNOWN"),
            "compliance_score": details.get("compliance_score", 0),
            "violations_count": len(details.get("violations", [])),
            "violations": details.get("violations", []),
            "run_id": os.getenv("GITHUB_RUN_ID", "local"),
            "commit_sha": os.getenv("GITHUB_SHA", "local"),
            "pull_request": os.getenv("GITHUB_REF", "N/A"),
        }

        # Append to daily log file (one per day)
        log_file = self.log_path / f"audit-{datetime.now().strftime('%Y-%m-%d')}.jsonl"
        with open(log_file, "a") as f:
            f.write(json.dumps(log_entry) + "\n")

        return log_entry

    def generate_summary(self):
        """Generate summary of all logged compliance checks"""
        summary = {
            "generated_at": datetime.utcnow().isoformat() + "Z",
            "total_checks": 0,
            "approved": 0,
            "rejected": 0,
            "conditional": 0,
            "average_compliance_score": 0.0,
            "critical_violations": [],
        }

        if not self.log_path.exists():
            return summary

        all_scores = []
        for log_file in self.log_path.glob("audit-*.jsonl"):
            with open(log_file) as f:
                for line in f:
                    entry = json.loads(line)
                    summary["total_checks"] += 1

                    status = entry.get("compliance_status", "UNKNOWN")
                    if status == "APPROVE":
                        summary["approved"] += 1
                    elif status == "REJECT":
                        summary["rejected"] += 1
                    elif status == "CONDITIONAL":
                        summary["conditional"] += 1

                    score = entry.get("compliance_score", 0)
                    if isinstance(score, str):
                        score = float(score.rstrip("%"))
                    all_scores.append(score)

                    # Track critical violations
                    violations = entry.get("violations", [])
                    for v in violations:
                        if v.get("severity") == "CRITICAL":
                            summary["critical_violations"].append(
                                {
                                    "timestamp": entry["timestamp"],
                                    "resource": entry.get("resource"),
                                    "violation": v.get("message"),
                                }
                            )

        if all_scores:
            summary["average_compliance_score"] = round(
                sum(all_scores) / len(all_scores), 1
            )

        return summary


def main():
    """CLI entry point"""
    import sys

    logger = ComplianceAuditLogger()

    if len(sys.argv) > 1 and sys.argv[1] == "summary":
        # Generate summary
        summary = logger.generate_summary()
        print(json.dumps(summary, indent=2))
    else:
        # Log a compliance check (for testing)
        details = {
            "environment": "dev",
            "resource": "storage-account-demo",
            "status": "APPROVE",
            "compliance_score": 100,
            "violations": [],
        }
        entry = logger.log_compliance_check(details)
        print(f"✅ Logged: {entry['timestamp']}")
        print(f"   Status: {entry['compliance_status']}")
        print(f"   Score: {entry['compliance_score']}%")


if __name__ == "__main__":
    main()
