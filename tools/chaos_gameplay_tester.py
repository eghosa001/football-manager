#!/usr/bin/env python3
"""Hostile Android stress tester for Football Dynasty.

Intentionally abuses input, navigation, process lifecycle and rendering state to
find crashes, ANRs, unrecoverable process death, runaway memory, restart loops,
and fragile foreground/background behavior. Every run is seed-reproducible.
"""
from __future__ import annotations

import argparse, json, random, re, subprocess, time
from dataclasses import asdict, dataclass
from pathlib import Path

@dataclass
class Finding:
    severity: str
    kind: str
    title: str
    evidence: str
    step: int

def run(cmd, check=True, timeout=120):
    p = subprocess.run(
        cmd,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=check,
        timeout=timeout,
    )
    return p.stdout.strip()

def adb(*args, check=True, timeout=120):
    return run(["adb", *args], check=check, timeout=timeout)

def wait_device():
    adb("wait-for-device", timeout=240)
    for _ in range(120):
        booted = adb("shell", "getprop", "sys.boot_completed", check=False, timeout=20).strip()
        state = adb("get-state", check=False, timeout=20).strip()
        if booted == "1" and state == "device":
            return
        time.sleep(2)
    raise RuntimeError("emulator did not become fully ready")

def install_apk(apk):
    """Install reliably even when a just-booted CI emulator has a sluggish package manager."""
    wait_device()
    adb("shell", "settings", "put", "global", "verifier_verify_adb_installs", "0", check=False, timeout=30)
    adb("shell", "settings", "put", "global", "package_verifier_enable", "0", check=False, timeout=30)
    attempts = [
        (["install", "-r", "-g", apk], 240, "streaming"),
        (["install", "-r", "-g", "--no-streaming", apk], 360, "no-streaming"),
    ]
    diagnostics = []
    for args, timeout, mode in attempts:
        try:
            output = adb(*args, check=False, timeout=timeout)
            diagnostics.append(f"{mode}: {output[-1200:]}")
            if "Success" in output:
                return
        except subprocess.TimeoutExpired as exc:
            diagnostics.append(f"{mode}: timeout after {exc.timeout}s")
        adb("kill-server", check=False, timeout=30)
        adb("start-server", check=False, timeout=30)
        wait_device()
        time.sleep(2)
    raise RuntimeError("APK installation failed after retries: " + " | ".join(diagnostics))

def launch(pkg):
    return adb("shell", "monkey", "-p", pkg, "-c", "android.intent.category.LAUNCHER", "1", check=False, timeout=30)

def pid(pkg):
    x = adb("shell", "pidof", pkg, check=False).strip()
    return x.split()[0] if x else ""

def size():
    out = adb("shell", "wm", "size", check=False)
    m = re.findall(r"(\d+)x(\d+)", out)
    return tuple(map(int, m[-1])) if m else (1280, 720)

def mem_kb(pkg):
    out = adb("shell", "dumpsys", "meminfo", pkg, check=False, timeout=30)
    m = re.search(r"TOTAL\s+(\d+)", out) or re.search(r"TOTAL PSS:\s*(\d+)", out)
    return int(m.group(1)) if m else -1

def screenshot(path):
    with path.open("wb") as f:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=f, check=False, timeout=30)

def fatal_lines(text):
    rx = re.compile(r"FATAL EXCEPTION|ANR in |Fatal signal|SIGSEGV|SIGABRT|native crash|Godot.*SCRIPT ERROR|Godot.*ERROR:.*(?:Invalid|Freed|null instance|out of bounds|stack|overflow)", re.I)
    return [x for x in text.splitlines() if rx.search(x)]

def action(rng, pkg, w, h):
    roll = rng.random()
    if roll < .20:
        pts = []
        for _ in range(rng.randint(5, 18)):
            if rng.random() < .3:
                x = rng.choice([1, 4, w // 2, w - 4, w - 1])
                y = rng.choice([1, 8, h // 2, h - 8, h - 1])
            else:
                x = rng.randint(1, w - 2)
                y = rng.randint(1, h - 2)
            adb("shell", "input", "tap", str(x), str(y), check=False, timeout=8)
            pts.append([x, y])
        return {"kind": "tap-storm", "count": len(pts), "points": pts}
    if roll < .36:
        x1, y1, x2, y2 = [rng.randint(1, (w - 2 if i % 2 == 0 else h - 2)) for i in range(4)]
        dur = rng.choice([1, 5, 15, 50, 200, 700, 1800])
        adb("shell", "input", "swipe", str(x1), str(y1), str(x2), str(y2), str(dur), check=False, timeout=10)
        return {"kind": "swipe-abuse", "duration_ms": dur}
    if roll < .48:
        n = rng.randint(1, 8)
        for _ in range(n):
            adb("shell", "input", "keyevent", "4", check=False, timeout=8)
        return {"kind": "back-spam", "count": n}
    if roll < .58:
        adb("shell", "input", "keyevent", "3", check=False)
        time.sleep(rng.uniform(.03, .5))
        launch(pkg)
        return {"kind": "background-foreground"}
    if roll < .66:
        adb("shell", "am", "force-stop", pkg, check=False)
        time.sleep(rng.uniform(.03, .3))
        launch(pkg)
        return {"kind": "force-stop-relaunch"}
    if roll < .74:
        rot = rng.choice([0, 1, 2, 3])
        adb("shell", "settings", "put", "system", "accelerometer_rotation", "0", check=False)
        adb("shell", "settings", "put", "system", "user_rotation", str(rot), check=False)
        time.sleep(.2)
        adb("shell", "settings", "put", "system", "user_rotation", "0", check=False)
        return {"kind": "rotation", "rotation": rot}
    if roll < .88:
        events = rng.randint(20, 90)
        seed = rng.randint(1, 2147483647)
        out = adb("shell", "monkey", "-p", pkg, "--pct-touch", "40", "--pct-motion", "30", "--pct-nav", "12", "--pct-majornav", "8", "--pct-appswitch", "10", "-s", str(seed), str(events), check=False, timeout=60)
        return {"kind": "monkey-burst", "events": events, "seed": seed, "tail": out[-300:]}
    if roll < .95:
        x, y = rng.randint(1, w - 2), rng.randint(1, h - 2)
        dur = rng.choice([700, 1500, 3000, 5000])
        adb("shell", "input", "swipe", str(x), str(y), str(x), str(y), str(dur), check=False, timeout=10)
        return {"kind": "long-press", "duration_ms": dur}
    key = rng.choice([24, 25, 82, 61])
    adb("shell", "input", "keyevent", str(key), check=False)
    return {"kind": "keyevent", "key": key}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk", required=True)
    ap.add_argument("--package", default="com.footballdynasty.game")
    ap.add_argument("--out", default="build/chaos-gameplay")
    ap.add_argument("--steps", type=int, default=750)
    ap.add_argument("--seed", type=int, default=20260913)
    ap.add_argument("--checkpoint-every", type=int, default=25)
    a = ap.parse_args()
    out = Path(a.out)
    shots = out / "screenshots"
    shots.mkdir(parents=True, exist_ok=True)
    rng = random.Random(a.seed)
    findings = []
    timeline = []
    memories = []
    restarts = 0
    recoveries = 0

    wait_device()
    adb("logcat", "-c", check=False)
    install_apk(a.apk)
    launch(a.package)
    time.sleep(5)
    w, h = size()
    previous = pid(a.package)
    if not previous:
        findings.append(Finding("critical", "launch", "Game did not start", "pidof returned empty", 0))

    for step in range(1, a.steps + 1):
        act = action(rng, a.package, w, h)
        time.sleep(rng.uniform(.04, .25))
        current = pid(a.package)
        expected = act["kind"] == "force-stop-relaunch"
        if not current:
            launch(a.package)
            time.sleep(1)
            current = pid(a.package)
            if current:
                recoveries += 1
            else:
                findings.append(Finding("critical", "process-death", "Game died and could not recover", json.dumps(act), step))
                break
        elif previous and current != previous and not expected:
            restarts += 1
            findings.append(Finding("high", "unexpected-restart", "Game process restarted during hostile input", f"old={previous} new={current} action={json.dumps(act)}", step))
        previous = current or previous
        if step % max(1, a.checkpoint_every) == 0 or step == a.steps:
            m = mem_kb(a.package)
            memories.append({"step": step, "pss_kb": m})
            screenshot(shots / f"{step:05d}.png")
            logs = adb("logcat", "-d", "-v", "threadtime", check=False, timeout=60)
            fat = fatal_lines(logs)
            if fat:
                findings.append(Finding("critical", "runtime", "Fatal runtime evidence detected", "\n".join(fat[-50:]), step))
                break
        timeline.append({"step": step, "action": act, "pid": current})

    logs = adb("logcat", "-d", "-v", "threadtime", check=False, timeout=60)
    (out / "logcat.txt").write_text(logs, errors="replace")
    (out / "meminfo.txt").write_text(adb("shell", "dumpsys", "meminfo", a.package, check=False, timeout=60), errors="replace")
    (out / "gfxinfo.txt").write_text(adb("shell", "dumpsys", "gfxinfo", a.package, check=False, timeout=60), errors="replace")
    fat = fatal_lines(logs)
    if fat and not any(f.kind == "runtime" for f in findings):
        findings.append(Finding("critical", "runtime", "Fatal runtime evidence detected", "\n".join(fat[-50:]), a.steps))
    valid = [x["pss_kb"] for x in memories if x["pss_kb"] >= 0]
    growth = (valid[-1] - valid[0]) if len(valid) >= 2 else 0
    if growth > 250 * 1024:
        findings.append(Finding("high", "memory-growth", "Large memory growth during destructive session", f"growth_kb={growth}", a.steps))
    report = {
        "package": a.package,
        "seed": a.seed,
        "steps_requested": a.steps,
        "steps_completed": timeline[-1]["step"] if timeline else 0,
        "unexpected_restarts": restarts,
        "recoveries": recoveries,
        "memory_growth_kb": growth,
        "memory_samples": memories,
        "findings": [asdict(f) for f in findings],
        "timeline": timeline,
    }
    (out / "report.json").write_text(json.dumps(report, indent=2))
    md = [
        "# Football Dynasty Destructive Chaos Test",
        "",
        f"- Seed: `{a.seed}`",
        f"- Requested hostile actions: **{a.steps}**",
        f"- Completed actions: **{report['steps_completed']}**",
        f"- Unexpected restarts: **{restarts}**",
        f"- Recoveries: **{recoveries}**",
        f"- Memory growth: **{growth / 1024:.1f} MB**",
        f"- Findings: **{len(findings)}**",
        "",
    ]
    if findings:
        md += ["## Findings", ""] + [f"- **{f.severity.upper()}** `{f.kind}` — {f.title} (step {f.step})" for f in findings]
    else:
        md += ["The hostile run did not detect a crash, ANR, unrecoverable process death, restart anomaly, or large memory-growth signal."]
    (out / "report.md").write_text("\n".join(md))
    worst = max(({"low": 1, "medium": 2, "high": 3, "critical": 4}[f.severity] for f in findings), default=0)
    raise SystemExit(2 if worst >= 4 else 0)

if __name__ == "__main__":
    main()
