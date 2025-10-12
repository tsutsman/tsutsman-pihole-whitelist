#!/usr/bin/env python3
"""Прототип REST API для build_whitelist.sh."""
from __future__ import annotations

import argparse
import datetime as dt
import json
import pathlib
import threading
import uuid
from dataclasses import dataclass
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from subprocess import CalledProcessError, run
from typing import Any, Dict, List, Optional


@dataclass
class CategoryInfo:
    name: str
    path: pathlib.Path
    domain_count: int
    description: str


ROOT = pathlib.Path(__file__).resolve().parent


def _read_json(handler: BaseHTTPRequestHandler) -> Any:
    length_header = handler.headers.get("Content-Length")
    if not length_header:
        raise ValueError("Відсутній заголовок Content-Length")
    try:
        length = int(length_header)
    except ValueError as exc:  # pragma: no cover - захист від некоректних значень
        raise ValueError("Content-Length має бути числом") from exc
    payload = handler.rfile.read(length)
    try:
        return json.loads(payload.decode("utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError("Не вдалося розпарсити JSON") from exc


def _safe_join(base: pathlib.Path, *parts: str) -> pathlib.Path:
    candidate = (base.joinpath(*parts)).resolve()
    if base not in candidate.parents and candidate != base:
        raise ValueError("Шлях виходить за межі дозволеного каталогу")
    return candidate


def _count_domains(path: pathlib.Path) -> int:
    count = 0
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            count += 1
    return count


def _append_log(path: pathlib.Path, message: str) -> None:
    timestamp = dt.datetime.utcnow().isoformat(timespec="seconds")
    with path.open("a", encoding="utf-8") as fh:
        fh.write(f"{timestamp}\t{message}\n")



class BuilderConfig:
    """Налаштування сервера."""

    def collect_categories(self) -> List[CategoryInfo]:
        items: List[CategoryInfo] = []
        if not self.categories_dir.exists():
            return items
        for path in sorted(self.categories_dir.glob("*.txt")):
            if path.name == "deprecated.txt":
                continue
            count = _count_domains(path)
            description = self._extract_description(path)
            items.append(
                CategoryInfo(name=path.name, path=path, domain_count=count, description=description)
            )
        return items

    def _extract_description(self, path: pathlib.Path) -> str:
        description_lines: List[str] = []
        with path.open("r", encoding="utf-8") as fh:
            for line in fh:
                stripped = line.strip()
                if not stripped:
                    if description_lines:
                        break
                    continue
                if stripped.startswith("#"):
                    description_lines.append(stripped.lstrip("# "))
                    continue
                break
        return " ".join(description_lines).strip()

    def __init__(
        self,
        build_script: pathlib.Path,
        data_dir: pathlib.Path,
        log_file: pathlib.Path,
        categories_dir: pathlib.Path,
        allow_external_categories: bool,
        allowed_extra_paths: Optional[List[pathlib.Path]],
    ) -> None:
        self.build_script = build_script
        self.data_dir = data_dir
        self.log_file = log_file
        self.categories_dir = categories_dir
        self.allow_external_categories = allow_external_categories
        self.allowed_extra_paths = allowed_extra_paths or []
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.log_file.parent.mkdir(parents=True, exist_ok=True)

    def resolve_category(self, value: str) -> pathlib.Path:
        raw = pathlib.Path(value)
        if raw.is_absolute():
            candidate = raw.resolve()
            if not self.allow_external_categories and not candidate.is_relative_to(self.categories_dir):
                raise ValueError("Зовнішні категорії заборонено політикою сервера")
        else:
            candidate = _safe_join(self.categories_dir, value)
        if not candidate.exists():
            raise ValueError(f"Категорію {value} не знайдено")
        return candidate

    def resolve_extra(self, value: str) -> pathlib.Path:
        candidate = pathlib.Path(value).resolve()
        if not candidate.exists():
            raise ValueError(f"Додатковий шлях {value} не існує")
        if self.allowed_extra_paths:
            allowed = any(candidate.is_relative_to(base) for base in self.allowed_extra_paths)
            if not allowed:
                raise ValueError("Шлях не входить до списку дозволених extra-path")
        return candidate



class BuilderHTTPServer(ThreadingHTTPServer):
    """HTTP-сервер з доступом до конфігурації."""

    def __init__(self, server_address: tuple[str, int], config: BuilderConfig) -> None:
        super().__init__(server_address, BuilderRequestHandler)
        self.config = config
        self._shutdown_requested = threading.Event()

    def shutdown(self) -> None:  # pragma: no cover - викликається при завершенні
        self._shutdown_requested.set()
        super().shutdown()


class BuilderRequestHandler(BaseHTTPRequestHandler):
    """Обробник HTTP-запитів для API."""

    server: "BuilderHTTPServer"  # type: ignore[assignment]

    def log_message(self, fmt: str, *args: Any) -> None:  # pragma: no cover - уникнення зайвих логів у stderr
        _append_log(self.server.config.log_file, fmt % args)

    def _send_json(self, status: HTTPStatus, payload: Dict[str, Any]) -> None:
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._send_json(HTTPStatus.OK, {"status": "ok"})
            return
        if self.path == "/api/categories":
            self._handle_categories()
            return
        if self.path.startswith("/downloads/"):
            self._handle_download()
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"status": "error", "errors": ["Ресурс не знайдено"]})

    def _handle_categories(self) -> None:
        items = [
            {
                "name": info.name,
                "domain_count": info.domain_count,
                "description": info.description,
            }
            for info in self.server.config.collect_categories()
        ]
        self._send_json(HTTPStatus.OK, {"status": "ok", "categories": items})

    def _handle_download(self) -> None:
        relative = self.path[len("/downloads/") :]
        try:
            file_path = _safe_join(self.server.config.data_dir, relative)
        except ValueError:
            self._send_json(HTTPStatus.BAD_REQUEST, {"status": "error", "errors": ["Некоректний шлях"]})
            return
        if not file_path.exists():
            self._send_json(HTTPStatus.NOT_FOUND, {"status": "error", "errors": ["Файл не знайдено"]})
            return
        data = file_path.read_bytes()
        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/api/build":
            self._handle_build()
            return
        self._send_json(HTTPStatus.NOT_FOUND, {"status": "error", "errors": ["Ресурс не знайдено"]})

    def _handle_build(self) -> None:
        try:
            payload = _read_json(self)
        except ValueError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"status": "error", "errors": [str(exc)]})
            return

        try:
            request = self._validate_payload(payload)
        except ValueError as exc:
            self._send_json(HTTPStatus.BAD_REQUEST, {"status": "error", "errors": [str(exc)]})
            return

        output_name = f"whitelist-{dt.datetime.utcnow().strftime('%Y%m%d-%H%M%S')}-{uuid.uuid4().hex[:8]}.txt"
        output_path = self.server.config.data_dir / output_name

        cmd: List[str] = [str(self.server.config.build_script), "--output", str(output_path)]
        if request["categories"]:
            cmd.extend(["--categories", ",".join(str(p) for p in request["categories"])])
        for extra in request["extra_paths"]:
            cmd.extend(["--extra-path", str(extra)])
        cmd.extend(["--include-external", "1" if request["include_external"] else "0"])
        if request["sources_combined"]:
            cmd.extend(["--sources-combined", request["sources_combined"]])
        cmd.extend(["--apply-directly", "1" if request["apply_directly"] else "0"])

        try:
            completed = run(cmd, capture_output=True, text=True, check=True)
        except CalledProcessError as exc:
            errors = ["Не вдалося згенерувати whitelist", exc.stderr.strip() or exc.stdout.strip()]
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"status": "error", "errors": errors})
            return

        if not output_path.exists():
            self._send_json(HTTPStatus.INTERNAL_SERVER_ERROR, {"status": "error", "errors": ["Файл результату не створено"]})
            return

        domain_count = _count_domains(output_path)
        download_url = f"/downloads/{output_path.name}"
        log_message = (
            f"client={self.client_address[0]} categories={len(request['categories'])} "
            f"domains={domain_count} apply={int(request['apply_directly'])}"
        )
        _append_log(self.server.config.log_file, log_message)

        self._send_json(
            HTTPStatus.OK,
            {
                "status": "ok",
                "domain_count": domain_count,
                "download_url": download_url,
                "command_stdout": completed.stdout.strip(),
            },
        )

    def _validate_payload(self, payload: Any) -> Dict[str, Any]:
        if not isinstance(payload, dict):
            raise ValueError("Очікується JSON-об'єкт")
        categories_raw = payload.get("categories", [])
        if not isinstance(categories_raw, list):
            raise ValueError("Поле categories має бути списком")
        if not categories_raw:
            raise ValueError("Потрібно вказати щонайменше одну категорію")
        categories = [self.server.config.resolve_category(str(item)) for item in categories_raw]

        extra_raw = payload.get("extra_paths", [])
        if not isinstance(extra_raw, list):
            raise ValueError("Поле extra_paths має бути списком")
        extra_paths = [self.server.config.resolve_extra(str(item)) for item in extra_raw]

        include_external = bool(payload.get("include_external", True))
        apply_directly = bool(payload.get("apply_directly", False))
        sources_combined = payload.get("sources_combined", "")
        if sources_combined:
            sources_combined = str(sources_combined)

        return {
            "categories": categories,
            "extra_paths": extra_paths,
            "include_external": include_external,
            "apply_directly": apply_directly,
            "sources_combined": sources_combined,
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="REST API для build_whitelist.sh")
    parser.add_argument("--host", default="127.0.0.1", help="Хост для прослуховування")
    parser.add_argument("--port", type=int, default=5000, help="Порт для прослуховування")
    parser.add_argument(
        "--build-script",
        default=str(ROOT / "build_whitelist.sh"),
        help="Шлях до build_whitelist.sh",
    )
    parser.add_argument(
        "--data-dir",
        default=str(ROOT / "tmp" / "downloads"),
        help="Каталог для збереження сформованих whitelist-файлів",
    )
    parser.add_argument(
        "--log-file",
        default=str(ROOT / "logs" / "whitelist_builder.log"),
        help="Файл журналу операцій",
    )
    parser.add_argument(
        "--categories-dir",
        default=str(ROOT / "categories"),
        help="Каталог з файлами категорій",
    )
    parser.add_argument(
        "--allow-external-categories",
        action="store_true",
        help="Дозволити абсолютні шляхи категорій поза стандартним каталогом",
    )
    parser.add_argument(
        "--allow-extra-path",
        action="append",
        default=[],
        help="Додаткові дозволені каталоги для extra-path (якщо не вказано — дозволено будь-які існуючі шляхи)",
    )
    return parser.parse_args()


def build_server(args: argparse.Namespace) -> BuilderHTTPServer:
    build_script = pathlib.Path(args.build_script).resolve()
    if not build_script.exists():
        raise SystemExit(f"Скрипт {build_script} не знайдено")
    config = BuilderConfig(
        build_script=build_script,
        data_dir=pathlib.Path(args.data_dir).resolve(),
        log_file=pathlib.Path(args.log_file).resolve(),
        categories_dir=pathlib.Path(args.categories_dir).resolve(),
        allow_external_categories=bool(args.allow_external_categories),
        allowed_extra_paths=[pathlib.Path(item).resolve() for item in args.allow_extra_path],
    )
    server = BuilderHTTPServer((args.host, args.port), config)
    return server


def main() -> None:
    args = parse_args()
    server = build_server(args)
    print(f"Whitelist Builder API запущено на http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:  # pragma: no cover - зручно при ручному запуску
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
