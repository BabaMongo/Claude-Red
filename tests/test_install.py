"""Tests for install.sh script."""
import subprocess
import tempfile
from pathlib import Path


def test_install_script_exists():
    """Verify install.sh script exists and is executable."""
    install_script = Path(__file__).parent.parent / "install.sh"
    assert install_script.exists(), "install.sh not found"
    assert install_script.stat().st_mode & 0o111, "install.sh is not executable"


def test_install_script_help():
    """Verify install.sh help output works."""
    result = subprocess.run(
        ["bash", "install.sh", "--help"],
        cwd=Path(__file__).parent.parent,
        capture_output=True,
        text=True
    )
    assert result.returncode == 0, f"Help failed: {result.stderr}"
    assert "Usage" in result.stdout, "Help output doesn't contain Usage"


def test_install_script_list():
    """Verify install.sh --list works."""
    result = subprocess.run(
        ["bash", "install.sh", "--list"],
        cwd=Path(__file__).parent.parent,
        capture_output=True,
        text=True
    )
    assert result.returncode == 0, f"List failed: {result.stderr}"
    assert "web" in result.stdout, "Categories not listed"
