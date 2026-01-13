#!/usr/bin/env python3
"""
Latency Log Analysis Tool

Analyzes Heart Beat latency validation logs to verify P95 < 100ms requirement.
Processes logs from LatencyService and generates statistical reports.

Usage:
    python3 analyze_latency.py <log_file> [--detailed] [--csv <output.csv>]

Example:
    python3 analyze_latency.py latency_validation_20260113.txt --detailed
"""

import re
import sys
import argparse
from dataclasses import dataclass
from typing import List, Optional
from pathlib import Path


@dataclass
class LatencySample:
    """Represents a single latency statistics log entry."""
    timestamp: str
    sample_count: int
    total_samples: int
    p50_ms: float
    p95_ms: float
    p99_ms: float
    meets_requirement: bool


class LatencyAnalyzer:
    """Analyzes latency logs and generates statistical reports."""

    def __init__(self, log_file: str):
        self.log_file = Path(log_file)
        self.samples: List[LatencySample] = []

    def parse_logs(self) -> bool:
        """Parse the log file and extract latency statistics."""
        if not self.log_file.exists():
            print(f"Error: Log file '{self.log_file}' not found", file=sys.stderr)
            return False

        print(f"Parsing log file: {self.log_file}")

        # Pattern to match latency statistics blocks
        # Example:
        # 01-13 14:30:00.123 ... [LatencyService] Latency Statistics:
        # 01-13 14:30:00.123 ...   Samples: 456 (Total: 1234)
        # 01-13 14:30:00.123 ...   P50: 45.23 ms
        # 01-13 14:30:00.123 ...   P95: 78.91 ms
        # 01-13 14:30:00.123 ...   P99: 92.45 ms
        # 01-13 14:30:00.123 ...   ✓ P95 latency meets <100ms requirement

        with open(self.log_file, 'r', encoding='utf-8') as f:
            content = f.read()

        # Find all latency statistics blocks
        pattern = re.compile(
            r'(\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+).*?\[LatencyService\] Latency Statistics:\s*\n'
            r'.*?Samples:\s*(\d+)\s*\(Total:\s*(\d+)\)\s*\n'
            r'.*?P50:\s*([\d.]+)\s*ms\s*\n'
            r'.*?P95:\s*([\d.]+)\s*ms\s*\n'
            r'.*?P99:\s*([\d.]+)\s*ms\s*\n'
            r'.*?(✓|⚠️|WARNING)',
            re.MULTILINE | re.DOTALL
        )

        matches = pattern.findall(content)

        for match in matches:
            timestamp, samples, total, p50, p95, p99, status = match
            sample = LatencySample(
                timestamp=timestamp.strip(),
                sample_count=int(samples),
                total_samples=int(total),
                p50_ms=float(p50),
                p95_ms=float(p95),
                p99_ms=float(p99),
                meets_requirement=(status == '✓')
            )
            self.samples.append(sample)

        print(f"Found {len(self.samples)} latency statistics entries\n")
        return len(self.samples) > 0

    def generate_report(self, detailed: bool = False) -> str:
        """Generate a validation report."""
        if not self.samples:
            return "No latency samples found in log file."

        # Calculate overall statistics
        p50_values = [s.p50_ms for s in self.samples]
        p95_values = [s.p95_ms for s in self.samples]
        p99_values = [s.p99_ms for s in self.samples]

        total_samples = self.samples[-1].total_samples
        failing_windows = sum(1 for s in self.samples if not s.meets_requirement)
        max_p95 = max(p95_values)
        min_p95 = min(p95_values)
        avg_p95 = sum(p95_values) / len(p95_values)

        # Estimate session duration (30 second intervals between logs)
        duration_minutes = len(self.samples) * 0.5  # 30 seconds = 0.5 minutes

        # Calculate sample rate
        sample_rate = total_samples / (duration_minutes * 60) if duration_minutes > 0 else 0

        # Determine validation result
        validation_passed = (
            failing_windows == 0 and
            max_p95 < 100.0 and
            avg_p95 < 100.0 and
            total_samples >= 3600  # Minimum 30 minutes @ 2 Hz
        )

        # Build report
        report_lines = [
            "=" * 60,
            "LATENCY VALIDATION REPORT",
            "=" * 60,
            "",
            "Session Information:",
            f"  Log File: {self.log_file.name}",
            f"  Log Entries: {len(self.samples)}",
            f"  Estimated Duration: {duration_minutes:.1f} minutes",
            f"  Total Samples: {total_samples:,}",
            f"  Sample Rate: {sample_rate:.2f} Hz",
            "",
            "Latency Statistics (P95):",
            f"  Average: {avg_p95:.2f} ms",
            f"  Minimum: {min_p95:.2f} ms",
            f"  Maximum: {max_p95:.2f} ms",
            "",
            "Latency Statistics (P50):",
            f"  Average: {sum(p50_values) / len(p50_values):.2f} ms",
            f"  Minimum: {min(p50_values):.2f} ms",
            f"  Maximum: {max(p50_values):.2f} ms",
            "",
            "Latency Statistics (P99):",
            f"  Average: {sum(p99_values) / len(p99_values):.2f} ms",
            f"  Minimum: {min(p99_values):.2f} ms",
            f"  Maximum: {max(p99_values):.2f} ms",
            "",
            "Validation Results:",
            f"  P95 < 100ms Requirement: {'✓ PASS' if max_p95 < 100.0 else '❌ FAIL'}",
            f"  Failing Windows: {failing_windows} / {len(self.samples)}",
            f"  Minimum Sample Count: {'✓ PASS' if total_samples >= 3600 else '❌ FAIL'} ({total_samples:,} / 3,600)",
            "",
            f"Overall Validation: {'✓ PASS' if validation_passed else '❌ FAIL'}",
            "",
        ]

        # Add warnings/recommendations
        warnings = []
        if max_p95 > 100.0:
            warnings.append(f"⚠️  P95 exceeded 100ms (max: {max_p95:.2f}ms)")
        elif max_p95 > 90.0:
            warnings.append(f"⚠️  P95 close to threshold (max: {max_p95:.2f}ms)")

        if avg_p95 > 80.0:
            warnings.append(f"⚠️  Average P95 high ({avg_p95:.2f}ms)")

        if max(p99_values) > 150.0:
            warnings.append(f"⚠️  P99 shows outliers (max: {max(p99_values):.2f}ms)")

        if total_samples < 3600:
            warnings.append(f"⚠️  Insufficient samples ({total_samples:,} < 3,600)")

        if duration_minutes < 30:
            warnings.append(f"⚠️  Session too short ({duration_minutes:.1f} < 30 minutes)")

        # Check for increasing trend
        if len(p95_values) >= 5:
            early_avg = sum(p95_values[:len(p95_values)//3]) / (len(p95_values)//3)
            late_avg = sum(p95_values[-len(p95_values)//3:]) / (len(p95_values)//3)
            if late_avg > early_avg * 1.2:  # 20% increase
                warnings.append(f"⚠️  P95 increasing over time ({early_avg:.1f}ms → {late_avg:.1f}ms)")

        if warnings:
            report_lines.append("Warnings:")
            for warning in warnings:
                report_lines.append(f"  {warning}")
            report_lines.append("")

        # Detailed breakdown if requested
        if detailed and len(self.samples) > 0:
            report_lines.extend([
                "=" * 60,
                "DETAILED BREAKDOWN",
                "=" * 60,
                "",
                f"{'Timestamp':<20} {'Samples':>8} {'P50':>8} {'P95':>8} {'P99':>8} {'Status':>6}",
                "-" * 70,
            ])

            for sample in self.samples:
                status = "✓" if sample.meets_requirement else "❌"
                report_lines.append(
                    f"{sample.timestamp:<20} {sample.sample_count:>8} "
                    f"{sample.p50_ms:>7.2f}ms {sample.p95_ms:>7.2f}ms "
                    f"{sample.p99_ms:>7.2f}ms {status:>6}"
                )
            report_lines.append("")

        report_lines.append("=" * 60)

        return "\n".join(report_lines)

    def export_csv(self, output_file: str) -> bool:
        """Export samples to CSV format."""
        if not self.samples:
            print("No samples to export", file=sys.stderr)
            return False

        try:
            with open(output_file, 'w') as f:
                # Write header
                f.write("timestamp,sample_count,total_samples,p50_ms,p95_ms,p99_ms,meets_requirement\n")

                # Write data
                for sample in self.samples:
                    f.write(
                        f"{sample.timestamp},{sample.sample_count},{sample.total_samples},"
                        f"{sample.p50_ms},{sample.p95_ms},{sample.p99_ms},"
                        f"{sample.meets_requirement}\n"
                    )

            print(f"\nExported {len(self.samples)} samples to {output_file}")
            return True
        except Exception as e:
            print(f"Error writing CSV: {e}", file=sys.stderr)
            return False


def main():
    parser = argparse.ArgumentParser(
        description="Analyze Heart Beat latency validation logs",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic analysis
  python3 analyze_latency.py latency_validation_20260113.txt

  # Detailed breakdown
  python3 analyze_latency.py latency_validation_20260113.txt --detailed

  # Export to CSV
  python3 analyze_latency.py latency_validation_20260113.txt --csv data.csv

  # Both detailed and CSV
  python3 analyze_latency.py latency_validation_20260113.txt --detailed --csv data.csv
        """
    )

    parser.add_argument(
        'log_file',
        help='Path to the latency validation log file'
    )
    parser.add_argument(
        '--detailed',
        action='store_true',
        help='Include detailed per-entry breakdown in report'
    )
    parser.add_argument(
        '--csv',
        metavar='OUTPUT',
        help='Export samples to CSV file'
    )

    args = parser.parse_args()

    # Create analyzer and parse logs
    analyzer = LatencyAnalyzer(args.log_file)

    if not analyzer.parse_logs():
        print("\nNo latency statistics found in log file.", file=sys.stderr)
        print("Make sure the log contains LatencyService output.", file=sys.stderr)
        sys.exit(1)

    # Generate and print report
    report = analyzer.generate_report(detailed=args.detailed)
    print(report)

    # Export to CSV if requested
    if args.csv:
        analyzer.export_csv(args.csv)

    # Exit with appropriate code
    sys.exit(0 if "✓ PASS" in report else 1)


if __name__ == '__main__':
    main()
