import subprocess

import pytest
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def fail_if_subprocess_runs(*args, **kwargs):
    raise AssertionError("subprocess.run must not execute for a rejected target")


def test_home_page():
    response = client.get("/")

    assert response.status_code == 200
    assert "<title>Security Scan" in response.text


def test_approved_nmap_scan(monkeypatch):
    completed_process = subprocess.CompletedProcess(
        args=["nmap"],
        returncode=0,
        stdout="Nmap done\nPORT 22 open\n",
        stderr="",
    )
    monkeypatch.setattr(
        subprocess,
        "run",
        lambda *args, **kwargs: completed_process,
    )

    response = client.post(
        "/api/scan",
        json={
            "scan_type": "url",
            "target": "scanme.nmap.org",
        },
    )

    assert response.status_code == 200
    assert "Nmap done" in response.json()
    assert "PORT 22" in response.json()


@pytest.mark.parametrize(
    "target",
    [
        "127.0.0.1",
        "169.254.169.254",
    ],
)
def test_blocks_ssrf_targets(monkeypatch, target):
    monkeypatch.setattr(subprocess, "run", fail_if_subprocess_runs)

    response = client.post(
        "/api/scan",
        json={
            "scan_type": "url",
            "target": target,
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Target no permitido"


@pytest.mark.parametrize(
    "target",
    [
        "-V",
        "--script=vuln",
    ],
)
def test_blocks_argument_injection(monkeypatch, target):
    monkeypatch.setattr(subprocess, "run", fail_if_subprocess_runs)

    response = client.post(
        "/api/scan",
        json={
            "scan_type": "url",
            "target": target,
        },
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Target inválido"
