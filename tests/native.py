"""Compile and run the Swift checks (macOS), type-check the SwiftUI sources against the iOS SDK, and compile the Kotlin checks.

The overlay reads the theme and controls components' Swift types, so their sources are found next to this
component (components/<name>/implementation/apple/Sources in a checkout, components/<name>/apple/Sources once installed).

Usage: python3 tests/native.py apple|android
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]


def sibling(name, *candidates):
    for candidate in candidates:
        path = root.parent / name / candidate
        if path.is_dir():
            return path
    sys.exit(f"blocked: the {name} component's sources were not found next to this component")


def ios_flags():
    sdk = subprocess.run(["xcrun", "--sdk", "iphonesimulator", "--show-sdk-path"], capture_output=True, text=True, check=True).stdout.strip()
    return ["-sdk", sdk, "-target", "arm64-apple-ios17.0-simulator"]


def apple():
    sources = root / "implementation/apple/Sources"
    with tempfile.TemporaryDirectory() as directory:
        output = Path(directory) / "check"
        subprocess.run(["swiftc", str(sources / "TourModel.swift"), str(root / "tests/apple/main.swift"), "-o", str(output)], check=True)
        subprocess.run([str(output)], cwd=root, check=True)
    others = [sibling(name, "implementation/apple/Sources", "apple/Sources") for name in ("theme", "controls")]
    everything = sorted(str(p) for p in [*sources.glob("*.swift"), *[f for d in others for f in d.glob("*.swift")]])
    subprocess.run(["swiftc", "-typecheck", *ios_flags(), *everything], check=True)
    print("ios type-check passed")


def android():
    sources = sorted((root / "implementation/android/src/main/java").rglob("*.kt"))
    pure = [str(p) for p in sources if p.name == "TourModel.kt"]
    tests = sorted(str(p) for p in (root / "tests/android").glob("*.kt"))
    with tempfile.TemporaryDirectory() as directory:
        jar = str(Path(directory) / "check.jar")
        subprocess.run(["kotlinc", *pure, *tests, "-include-runtime", "-d", jar], check=True)
        subprocess.run(["java", "-jar", jar], cwd=root, check=True)
    # Compose sources need the Android and Compose libraries: compiled in the application's Gradle build.


{"apple": apple, "android": android}.get(sys.argv[1] if len(sys.argv) > 1 else "", lambda: sys.exit("expected apple or android"))()
