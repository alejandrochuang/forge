import subprocess

from fastapi import FastAPI, Form, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel

SCAN_TIMEOUT_SECONDS = 60

ALLOWED_TARGETS = {
    "url": {"scanme.nmap.org"},
    "docker": {"ubuntu:latest"},
}


class ScanRequest(BaseModel):
    scan_type: str
    target: str


app = FastAPI(title="SecurityScanService")
templates = Jinja2Templates(directory="app/templates")


def validate_target(scan_type: str, target: str) -> None:
    """Reject unsupported scan types, arbitrary targets and option-like input."""
    if scan_type not in ALLOWED_TARGETS:
        raise HTTPException(status_code=400, detail="scan_type no válido")

    if target.startswith("-"):
        raise HTTPException(status_code=400, detail="Target inválido")

    if target not in ALLOWED_TARGETS[scan_type]:
        raise HTTPException(status_code=400, detail="Target no permitido")


def scan_url(target: str) -> str:
    try:
        result = subprocess.run(
            [
                "nmap",
                "-sT",
                "--top-ports",
                "500",
                "-Pn",
                "-T4",
                "--max-retries",
                "1",
                "-A",
                "--host-timeout",
                "45s",
                target,
            ],
            capture_output=True,
            text=True,
            timeout=SCAN_TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(
            status_code=504,
            detail="Timeout: el escaneo tardó más de 60s",
        ) from exc

    return result.stdout


def scan_image(target: str) -> str:
    try:
        result = subprocess.run(
            ["trivy", "image", target],
            capture_output=True,
            text=True,
            timeout=SCAN_TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise HTTPException(
            status_code=504,
            detail="Timeout: el escaneo tardó más de 60s",
        ) from exc

    return result.stdout


def execute_scan(scan_type: str, target: str) -> str:
    if scan_type == "url":
        return scan_url(target)

    return scan_image(target)


@app.get("/", response_class=HTMLResponse)
def home(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={"request": request},
    )


@app.post("/ui/scan", response_class=HTMLResponse)
def ui_scan(
    request: Request,
    scan_type: str = Form(...),
    target: str = Form(...),
):
    validate_target(scan_type, target)
    output = execute_scan(scan_type, target)

    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={
            "request": request,
            "output": output,
            "scan_type": scan_type,
            "target": target,
        },
    )


@app.post("/api/scan")
def api_scan(scan: ScanRequest):
    validate_target(scan.scan_type, scan.target)
    return execute_scan(scan.scan_type, scan.target)
