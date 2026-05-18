#!/usr/bin/env python3
"""
Compliance Audit Report Generator
Generates compliance reports from audit logs for auditors and compliance teams
"""

import json
from pathlib import Path
from datetime import datetime, timedelta


class ComplianceReportGenerator:
    """Generate compliance reports from audit logs"""

    def __init__(self, log_path=".github/audit-logs"):
        self.log_path = Path(log_path)

    def load_logs(self, days_back=None):
        """Load audit logs from the last N days"""
        entries = []

        if not self.log_path.exists():
            return entries

        cutoff = datetime.utcnow() - timedelta(days=days_back or 30)

        for log_file in sorted(self.log_path.glob("audit-*.jsonl")):
            with open(log_file) as f:
                for line in f:
                    entry = json.loads(line)
                    timestamp = datetime.fromisoformat(
                        entry["timestamp"].replace("Z", "+00:00")
                    )
                    if timestamp >= cutoff:
                        entries.append(entry)

        return entries

    def generate_summary_report(self, days_back=30):
        """Generate compliance summary report"""
        entries = self.load_logs(days_back)

        if not entries:
            return {"status": "no_data", "message": "No audit logs found"}

        # Calculate metrics
        statuses = {}
        environments = {}
        all_scores = []
        violations_by_severity = {"CRITICAL": 0, "WARNING": 0, "INFO": 0}

        for entry in entries:
            status = entry.get("compliance_status", "UNKNOWN")
            statuses[status] = statuses.get(status, 0) + 1

            env = entry.get("environment", "unknown")
            environments[env] = environments.get(env, 0) + 1

            score = entry.get("compliance_score", 0)
            if isinstance(score, str):
                score = float(score.rstrip("%"))
            all_scores.append(score)

            violations = entry.get("violations", [])
            for v in violations:
                severity = v.get("severity", "INFO")
                violations_by_severity[severity] = (
                    violations_by_severity.get(severity, 0) + 1
                )

        avg_score = sum(all_scores) / len(all_scores) if all_scores else 0

        report = {
            "report_generated": datetime.utcnow().isoformat() + "Z",
            "time_period_days": days_back,
            "total_compliance_checks": len(entries),
            "compliance_breakdown": {
                "approved": statuses.get("APPROVE", 0),
                "rejected": statuses.get("REJECT", 0),
                "conditional": statuses.get("CONDITIONAL", 0),
            },
            "approval_rate": round(
                (statuses.get("APPROVE", 0) / len(entries) * 100) if entries else 0, 1
            ),
            "average_compliance_score": round(avg_score, 1),
            "by_environment": environments,
            "violations": {
                "critical": violations_by_severity.get("CRITICAL", 0),
                "warnings": violations_by_severity.get("WARNING", 0),
                "info": violations_by_severity.get("INFO", 0),
            },
            "recent_rejections": [
                {
                    "timestamp": e["timestamp"],
                    "environment": e.get("environment"),
                    "resource": e.get("resource"),
                    "violations": e.get("violations", [])[:3],
                }
                for e in entries
                if e.get("compliance_status") == "REJECT"
            ][-5:],  # Last 5 rejections
        }

        return report

    def generate_detailed_report(self, days_back=30):
        """Generate detailed compliance report with all entries"""
        entries = self.load_logs(days_back)
        summary = self.generate_summary_report(days_back)

        report = {
            "summary": summary,
            "entries": entries,
            "compliance_matrix": self._build_compliance_matrix(entries),
        }

        return report

    def _build_compliance_matrix(self, entries):
        """Build compliance matrix by resource and environment"""
        matrix = {}

        for entry in entries:
            env = entry.get("environment", "unknown")
            resource = entry.get("resource", "unknown")
            status = entry.get("compliance_status", "unknown")

            if env not in matrix:
                matrix[env] = {}

            if resource not in matrix[env]:
                matrix[env][resource] = {
                    "passed": 0,
                    "failed": 0,
                    "conditional": 0,
                }

            if status == "APPROVE":
                matrix[env][resource]["passed"] += 1
            elif status == "REJECT":
                matrix[env][resource]["failed"] += 1
            elif status == "CONDITIONAL":
                matrix[env][resource]["conditional"] += 1

        return matrix


def main():
    """CLI entry point"""
    import sys

    generator = ComplianceReportGenerator()

    if len(sys.argv) > 1 and sys.argv[1] == "detailed":
        # Generate detailed report
        report = generator.generate_detailed_report()
    else:
        # Generate summary report
        report = generator.generate_summary_report()

    print(json.dumps(report, indent=2))

    # Also save to file
    report_file = Path(".github/audit-logs") / "latest-report.json"
    report_file.parent.mkdir(parents=True, exist_ok=True)
    with open(report_file, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\n✅ Report saved to: {report_file}")


if __name__ == "__main__":
    main()
