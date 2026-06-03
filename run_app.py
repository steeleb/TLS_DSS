"""
Launch the Streamlit app, creating/updating the virtual environment as needed.

Usage:
    python run_app.py
"""
import subprocess
import sys
from pathlib import Path

REPO_DIR   = Path(__file__).parent
VENV_DIR   = REPO_DIR / ".venv_streamlit"
REQ_FILE   = REPO_DIR / "streamlit_app" / "requirements.txt"
APP_FILE   = REPO_DIR / "streamlit_app" / "app.py"

def venv_python():
    candidate = VENV_DIR / "bin" / "python"
    if not candidate.exists():
        candidate = VENV_DIR / "Scripts" / "python.exe"  # Windows fallback
    return candidate

def venv_streamlit():
    candidate = VENV_DIR / "bin" / "streamlit"
    if not candidate.exists():
        candidate = VENV_DIR / "Scripts" / "streamlit.exe"
    return candidate

def create_venv():
    print(f"Creating virtual environment at {VENV_DIR} …")
    subprocess.run([sys.executable, "-m", "venv", str(VENV_DIR)], check=True)

def install_deps():
    print("Installing / updating dependencies …")
    subprocess.run(
        [str(venv_python()), "-m", "pip", "install", "--upgrade", "pip", "--quiet"],
        check=True,
    )
    subprocess.run(
        [str(venv_python()), "-m", "pip", "install", "-r", str(REQ_FILE), "--quiet"],
        check=True,
    )

def run_app():
    print("Starting Streamlit app …\n")
    subprocess.run(
        [str(venv_streamlit()), "run", str(APP_FILE)],
        check=True,
    )

if __name__ == "__main__":
    if not VENV_DIR.exists():
        create_venv()
        install_deps()
    elif not venv_streamlit().exists():
        install_deps()

    run_app()
