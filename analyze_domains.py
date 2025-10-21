#!/usr/bin/env python3
"""Звіт з аналітики доменів для списків білого списку Pi-hole.

Скрипт читає файли категорій, обчислює агреговані метрики та формує
Markdown-звіт із ключовими показниками, розподілом за категоріями,
TLD і базовими доменами. Дублікати між категоріями відображаються
окремим розділом.
"""
from __future__ import annotations

import argparse
import collections
import datetime as _dt
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Counter, Dict, Iterable, List, Mapping, Sequence, Set, Tuple

DEFAULT_CATEGORIES_DIR = "categories"
DEFAULT_WHITELIST_FILE = "whitelist.txt"
DEFAULT_OUTPUT_FILE = "docs/domain_analysis.md"
DEFAULT_JSON_OUTPUT = "docs/domain_analysis.json"


@dataclass(frozen=True)
class DomainRecord:
    domain: str
    category: str


@dataclass
class CategoryStats:
    name: str
    total: int
    unique: int
    duplicates: int
    tld_counter: Counter[str]

    @property
    def unique_ratio(self) -> float:
        if self.total == 0:
            return 0.0
        return self.unique / self.total

    def top_tlds(self, limit: int = 3) -> List[Tuple[str, int]]:
        return sorted(self.tld_counter.items(), key=lambda item: (-item[1], item[0]))[:limit]


class DomainAnalyzer:
    def __init__(
        self,
        categories_dir: Path,
        whitelist_file: Path | None,
    ) -> None:
        self.categories_dir = categories_dir
        self.whitelist_file = whitelist_file
        self._category_files: List[Path] = []

    def _iter_category_files(self) -> Iterable[Path]:
        if not self.categories_dir.is_dir():
            return []
        if not self._category_files:
            excluded = {"deprecated.txt", "comment_allowlist.txt"}
            files = [
                path
                for path in self.categories_dir.rglob("*.txt")
                if path.is_file() and path.name not in excluded
            ]
            self._category_files = sorted(files)
        return self._category_files

    @staticmethod
    def _clean_domain(line: str) -> str | None:
        line = line.strip()
        if not line:
            return None
        if line.startswith("#"):
            return None
        if "#" in line:
            line = line.split("#", 1)[0].strip()
        if not line:
            return None
        return line

    @staticmethod
    def _tld(domain: str) -> str:
        if "." not in domain:
            return domain.lower()
        return domain.rsplit(".", 1)[-1].lower()

    @staticmethod
    def _base_domain(domain: str) -> str:
        parts = domain.lower().split(".")
        if len(parts) < 2:
            return domain.lower()
        return ".".join(parts[-2:])

    def read_categories(self) -> Tuple[List[DomainRecord], Dict[str, CategoryStats]]:
        records: List[DomainRecord] = []
        per_category: Dict[str, CategoryStats] = {}
        for file_path in self._iter_category_files():
            category_name = file_path.name
            domains: List[str] = []
            tld_counter: Counter[str] = collections.Counter()
            seen: Set[str] = set()
            duplicates = 0
            with file_path.open("r", encoding="utf-8") as handle:
                for line in handle:
                    domain = self._clean_domain(line)
                    if domain is None:
                        continue
                    domains.append(domain)
                    tld_counter[self._tld(domain)] += 1
                    if domain in seen:
                        duplicates += 1
                    else:
                        seen.add(domain)
                        records.append(DomainRecord(domain=domain, category=category_name))
            stats = CategoryStats(
                name=category_name,
                total=len(domains),
                unique=len(seen),
                duplicates=duplicates,
                tld_counter=tld_counter,
            )
            per_category[category_name] = stats
        return records, per_category

    def read_whitelist(self) -> Set[str]:
        if not self.whitelist_file:
            return set()
        if not self.whitelist_file.exists():
            return set()
        domains: Set[str] = set()
        with self.whitelist_file.open("r", encoding="utf-8") as handle:
            for raw in handle:
                domain = self._clean_domain(raw)
                if domain is None:
                    continue
                domains.add(domain)
        return domains


def format_percentage(value: float) -> str:
    if value <= 0:
        return "0.0%"
    return f"{value * 100:.1f}%"


def render_markdown(
    summary: Mapping[str, int],
    category_stats: Sequence[CategoryStats],
    tld_counts: Mapping[str, int],
    base_domain_counts: Mapping[str, int],
    duplicates: Mapping[str, Sequence[str]],
    whitelist_summary: Mapping[str, int],
    generated_at: _dt.datetime,
) -> str:
    lines: List[str] = []
    lines.append("# Аналітика доменів")
    lines.append("")
    timezone_label = generated_at.strftime("%Z")
    timestamp = generated_at.strftime("%Y-%m-%d %H:%M:%S")
    if timezone_label:
        lines.append(f"Оновлено: {timestamp} {timezone_label}")
    else:
        lines.append(f"Оновлено: {generated_at.isoformat()}")
    lines.append("")
    lines.append("## Коротке зведення")
    lines.append("")
    lines.append(f"- Категорій проаналізовано: {summary['categories']}.")
    lines.append(f"- Записів у категоріях (з повторами): {summary['total_records']}.")
    share = summary['unique_domains'] / max(summary['total_records'], 1)
    lines.append(
        "- Унікальних доменів у категоріях: "
        f"{summary['unique_domains']} ({format_percentage(share)} від загальної кількості записів)."
    )
    lines.append(
        f"- Домени, що зустрічаються в кількох категоріях: {summary['multi_category_domains']}."
    )
    if whitelist_summary:
        lines.append(
            f"- Унікальних доменів у whitelist.txt: {whitelist_summary['unique_whitelist']}."
        )
        lines.append(
            "- Доменів поза категоріями, але присутніх у whitelist.txt: "
            f"{whitelist_summary['only_in_whitelist']}."
        )
        examples = whitelist_summary.get("only_in_whitelist_examples", [])
        if examples:
            preview = ", ".join(examples[:5])
            lines.append(
                "- Приклади доменів, що є лише у whitelist.txt: "
                f"{preview}."
            )
    lines.append("")

    lines.append("## Розподіл за категоріями")
    lines.append("")
    if not category_stats:
        lines.append("Немає доступних категорій для аналізу.")
    else:
        lines.append("| Категорія | Записів | Унікальних | Повторів | Частка унікальних | Топ TLD |")
        lines.append("| --- | ---: | ---: | ---: | ---: | --- |")
        for stats in sorted(category_stats, key=lambda item: item.name):
            top_tld_str = ", ".join(
                f"{tld} ({count})" for tld, count in stats.top_tlds()
            ) or "—"
            lines.append(
                f"| {stats.name} | {stats.total} | {stats.unique} | {stats.duplicates} | "
                f"{format_percentage(stats.unique_ratio)} | {top_tld_str} |"
            )
    lines.append("")

    lines.append("## Розподіл за TLD")
    lines.append("")
    if not tld_counts:
        lines.append("Немає даних про TLD.")
    else:
        total_unique = sum(tld_counts.values())
        lines.append("| TLD | Доменів | Частка |")
        lines.append("| --- | ---: | ---: |")
        for tld, count in sorted(tld_counts.items(), key=lambda item: (-item[1], item[0])):
            share = format_percentage(count / max(total_unique, 1))
            lines.append(f"| .{tld} | {count} | {share} |")
    lines.append("")

    lines.append("## Найпоширеніші базові домени")
    lines.append("")
    if not base_domain_counts:
        lines.append("Не вдалося визначити базові домени.")
    else:
        lines.append("| Базовий домен | Кількість піддоменів |")
        lines.append("| --- | ---: |")
        for domain, count in sorted(base_domain_counts.items(), key=lambda item: (-item[1], item[0]))[:15]:
            lines.append(f"| {domain} | {count} |")
    lines.append("")

    lines.append("## Дублікати між категоріями")
    lines.append("")
    if not duplicates:
        lines.append("Доменів, що дублюються між категоріями, не виявлено.")
    else:
        lines.append("| Домен | Категорії |")
        lines.append("| --- | --- |")
        for domain, cats in sorted(duplicates.items()):
            joined = ", ".join(sorted(cats))
            lines.append(f"| {domain} | {joined} |")
    lines.append("")

    return "\n".join(lines) + "\n"


def render_json(
    summary: Mapping[str, int],
    category_stats: Mapping[str, Mapping[str, int]],
    tld_counts: Mapping[str, int],
    base_domains: Mapping[str, int],
    duplicates: Mapping[str, Sequence[str]],
    whitelist_summary: Mapping[str, int],
    generated_at: _dt.datetime,
) -> str:
    payload = {
        "generated_at": generated_at.isoformat(),
        "summary": summary,
        "categories": category_stats,
        "tld": dict(tld_counts),
        "base_domains": dict(base_domains),
        "duplicates": {key: list(value) for key, value in duplicates.items()},
        "whitelist": whitelist_summary,
    }
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Аналітика доменів за категоріями")
    parser.add_argument(
        "--categories",
        dest="categories",
        default=os.environ.get("CATEGORIES_DIR", DEFAULT_CATEGORIES_DIR),
        help="Каталог із файлами категорій",
    )
    parser.add_argument(
        "--whitelist",
        dest="whitelist",
        default=os.environ.get("WHITELIST_FILE", DEFAULT_WHITELIST_FILE),
        help="Файл whitelist.txt для порівняння (опційно)",
    )
    parser.add_argument(
        "--output",
        dest="output",
        default=os.environ.get("DOMAIN_ANALYSIS_OUTPUT", DEFAULT_OUTPUT_FILE),
        help="Markdown-звіт для збереження",
    )
    parser.add_argument(
        "--json",
        dest="json_output",
        default=os.environ.get("DOMAIN_ANALYSIS_JSON", DEFAULT_JSON_OUTPUT),
        help="JSON-файл зі статистикою",
    )
    parser.add_argument(
        "--stdout", action="store_true", help="Вивести результат у stdout замість запису у файл"
    )

    args = parser.parse_args()

    categories_dir = Path(args.categories)
    whitelist_path = Path(args.whitelist) if args.whitelist else None
    analyzer = DomainAnalyzer(categories_dir=categories_dir, whitelist_file=whitelist_path)

    records, per_category = analyzer.read_categories()
    whitelist_domains = analyzer.read_whitelist()

    domain_to_categories: Dict[str, Set[str]] = collections.defaultdict(set)
    for record in records:
        domain_to_categories[record.domain].add(record.category)

    unique_domains = set(domain_to_categories.keys())

    tld_counts: Dict[str, int] = collections.Counter()
    base_domain_counts: Dict[str, int] = collections.Counter()
    for domain in unique_domains:
        tld_counts[DomainAnalyzer._tld(domain)] += 1
        base_domain_counts[DomainAnalyzer._base_domain(domain)] += 1

    duplicates: Dict[str, Sequence[str]] = {
        domain: sorted(categories)
        for domain, categories in domain_to_categories.items()
        if len(categories) > 1
    }

    summary = {
        "categories": len(per_category),
        "total_records": sum(stats.total for stats in per_category.values()),
        "unique_domains": len(unique_domains),
        "multi_category_domains": len(duplicates),
    }

    whitelist_summary: Dict[str, int] = {}
    if whitelist_domains:
        only_in_whitelist = whitelist_domains - unique_domains
        only_in_list = sorted(only_in_whitelist)
        whitelist_summary = {
            "unique_whitelist": len(whitelist_domains),
            "only_in_whitelist": len(only_in_whitelist),
            "only_in_whitelist_examples": only_in_list[:10],
        }

    generated_at = _dt.datetime.now(tz=_dt.timezone.utc).astimezone()

    markdown = render_markdown(
        summary=summary,
        category_stats=list(per_category.values()),
        tld_counts=tld_counts,
        base_domain_counts=base_domain_counts,
        duplicates=duplicates,
        whitelist_summary=whitelist_summary,
        generated_at=generated_at,
    )

    json_payload = render_json(
        summary=summary,
        category_stats={
            name: {
                "total": stats.total,
                "unique": stats.unique,
                "duplicates": stats.duplicates,
            }
            for name, stats in per_category.items()
        },
        tld_counts=tld_counts,
        base_domains=base_domain_counts,
        duplicates=duplicates,
        whitelist_summary=whitelist_summary,
        generated_at=generated_at,
    )

    if args.stdout:
        print(markdown)
    else:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(markdown, encoding="utf-8")

    json_path = Path(args.json_output)
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json_payload, encoding="utf-8")


if __name__ == "__main__":
    main()
