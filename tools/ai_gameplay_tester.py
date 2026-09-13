#!/usr/bin/env python3
"""Adaptive Android gameplay tester for Football Dynasty.

Runs against the exported APK, explores the rendered UI with screenshot feedback,
learns which regions produce useful state transitions, detects crashes/ANRs,
blank screens, softlocks and poor progression, and writes reproducible JSON/Markdown
reports for CI artifacts.
"""
from __future__ import annotations

import argparse, hashlib, json, math, random, re, subprocess, time
from dataclasses import asdict, dataclass
from pathlib import Path
from PIL import Image, ImageChops, ImageFilter, ImageStat

@dataclass
class Finding:
    severity: str
    kind: str
    title: str
    evidence: str
    step: int

@dataclass
class Target:
    x: int
    y: int
    score: float
    source: str

def run(cmd, check=True, timeout=120):
    p = subprocess.run(cmd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=check, timeout=timeout)
    return p.stdout.strip()

def adb(*args, check=True, timeout=120):
    return run(["adb", *args], check=check, timeout=timeout)

def wait_device():
    adb("wait-for-device", timeout=180)
    for _ in range(90):
        if adb("shell", "getprop", "sys.boot_completed", check=False) == "1": return
        time.sleep(2)
    raise RuntimeError("emulator did not boot")

def launch(package):
    return adb("shell", "monkey", "-p", package, "-c", "android.intent.category.LAUNCHER", "1", check=False, timeout=30)

def foreground():
    out = adb("shell", "dumpsys", "activity", "activities", check=False, timeout=20)
    m = re.search(r"mResumedActivity:.*?\s([\w.]+)/", out)
    return m.group(1) if m else ""

def size():
    out = adb("shell", "wm", "size", check=False)
    m = re.findall(r"(\d+)x(\d+)", out)
    return tuple(map(int, m[-1])) if m else (1280, 720)

def shot(path: Path):
    with path.open("wb") as f:
        subprocess.run(["adb", "exec-out", "screencap", "-p"], stdout=f, check=True, timeout=30)

def ahash(path: Path, n=16):
    img = Image.open(path).convert("L").resize((n,n))
    px = list(img.getdata()); avg = sum(px)/len(px)
    return hex(int("".join("1" if p >= avg else "0" for p in px),2))[2:].zfill(n*n//4)

def hd(a,b):
    try: return (int(a,16)^int(b,16)).bit_count()
    except Exception: return 999

def delta(a: Path,b: Path):
    x=Image.open(a).convert("RGB").resize((256,144)); y=Image.open(b).convert("RGB").resize((256,144))
    return sum(ImageStat.Stat(ImageChops.difference(x,y)).mean)/(3*255)

def metrics(path: Path):
    img=Image.open(path).convert("RGB"); st=ImageStat.Stat(img)
    gray=img.convert("L").resize((360,max(180,int(360*img.height/img.width))))
    edge=ImageStat.Stat(gray.filter(ImageFilter.FIND_EDGES)).mean[0]
    colors=img.resize((64,64)).quantize(colors=64).getcolors(maxcolors=64) or []
    return {"brightness":round(sum(st.mean)/3,2),"contrast":round(ImageStat.Stat(gray).stddev[0],2),"edge_density":round(min(1.0,edge/42.0),4),"color_buckets":len(colors),"hash":ahash(path)}

def visual_targets(path: Path,w:int,h:int):
    img=Image.open(path).convert("L"); edges=img.filter(ImageFilter.FIND_EDGES)
    out=[]; cols,rows=8,5
    for r in range(rows):
        for c in range(cols):
            x1=int(c*img.width/cols); x2=int((c+1)*img.width/cols)
            y1=int(r*img.height/rows); y2=int((r+1)*img.height/rows)
            cell=img.crop((x1,y1,x2,y2)); ed=edges.crop((x1,y1,x2,y2))
            score=ImageStat.Stat(cell).stddev[0]/64 + ImageStat.Stat(ed).mean[0]/40
            nx=(c+.5)/cols; ny=(r+.5)/rows
            score*=1-.12*math.hypot(nx-.5,ny-.5)
            out.append(Target(int(w*nx),int(h*ny),score,"vision"))
    return sorted(out,key=lambda t:t.score,reverse=True)[:18]

def ui_targets(out_file: Path):
    remote="/sdcard/fd-ui.xml"
    adb("shell","uiautomator","dump",remote,check=False,timeout=20)
    adb("pull",remote,str(out_file),check=False,timeout=20)
    if not out_file.exists(): return []
    text=out_file.read_text(errors="replace")
    found=[]
    for m in re.finditer(r'<node[^>]*clickable="true"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"',text):
        x1,y1,x2,y2=map(int,m.groups())
        if x2>x1 and y2>y1: found.append(Target((x1+x2)//2,(y1+y2)//2,3.0,"uiautomator"))
    return found

def fatal_lines(text):
    rx=re.compile(r"FATAL EXCEPTION|ANR in |Fatal signal|SIGSEGV|SIGABRT|Godot.*SCRIPT ERROR|Godot.*ERROR",re.I)
    return [x for x in text.splitlines() if rx.search(x)]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--apk",required=True); ap.add_argument("--package",default="com.footballdynasty.game"); ap.add_argument("--out",default="build/ai-gameplay"); ap.add_argument("--steps",type=int,default=140); ap.add_argument("--seed",type=int,default=20260913)
    a=ap.parse_args(); out=Path(a.out); shots=out/"screenshots"; dumps=out/"ui"; shots.mkdir(parents=True,exist_ok=True); dumps.mkdir(parents=True,exist_ok=True)
    rng=random.Random(a.seed); findings=[]; timeline=[]; learned={}; states={}; transitions={}
    wait_device(); adb("logcat","-c",check=False); adb("install","-r",a.apk,timeout=240); launch(a.package); time.sleep(6)
    if foreground() and foreground()!=a.package: findings.append(Finding("critical","launch","Game did not stay in foreground",foreground(),0))
    w,h=size(); cur=shots/"000.png"; shot(cur); cm=metrics(cur); cs=cm["hash"]; states[cs]=1
    if cm["brightness"]<3 or cm["color_buckets"]<=2: findings.append(Finding("critical","visual","Initial screen appears blank",json.dumps(cm),0))
    stagnant=0
    for step in range(1,a.steps+1):
        candidates=visual_targets(cur,w,h)
        if step%5==1: candidates=ui_targets(dumps/f"{step:03d}.xml")+candidates
        candidates += [Target(int(w*x),int(h*y),.8,"fallback") for x,y in [(0.5,.5),(.15,.12),(.85,.12),(.2,.85),(.8,.85),(.5,.88)]]
        roll=rng.random(); action={}
        if roll<.78:
            weights=[]
            for t in candidates:
                k=f"{round(t.x/80)}:{round(t.y/80)}"; rec=learned.get(k,{"n":0,"reward":0.0}); weights.append(max(.05,t.score*(1+rec["reward"]/max(1,rec["n"]))/(1+.1*rec["n"])))
            t=rng.choices(candidates,weights=weights,k=1)[0]; adb("shell","input","tap",str(t.x),str(t.y),check=False); action={"kind":"tap","x":t.x,"y":t.y,"source":t.source}; key=f"{round(t.x/80)}:{round(t.y/80)}"
        elif roll<.94:
            x=int(w*rng.uniform(.2,.8)); y=int(h*rng.uniform(.25,.8)); dx,dy=rng.choice([(0,-int(h*.35)),(0,int(h*.35)),(-int(w*.45),0),(int(w*.45),0)]); adb("shell","input","swipe",str(x),str(y),str(max(10,min(w-10,x+dx))),str(max(10,min(h-10,y+dy))),"280",check=False); action={"kind":"swipe"}; key=None
        else:
            adb("shell","input","keyevent","4",check=False); action={"kind":"back"}; key=None
        time.sleep(.7)
        nxt=shots/f"{step:03d}.png"; shot(nxt); nm=metrics(nxt); d=delta(cur,nxt); changed=d>=.004 or hd(cs,nm["hash"])>=8; novel=all(hd(nm["hash"],s)>=10 for s in states)
        if key:
            rec=learned.setdefault(key,{"n":0,"reward":0.0}); rec["n"]+=1; rec["reward"] += 2.0 if novel else 1.0 if changed else -.3
        states[nm["hash"]]=states.get(nm["hash"],0)+1; transitions[f"{cs[:10]}->{nm['hash'][:10]}"]=1; stagnant=0 if changed else stagnant+1
        if nm["brightness"]<3 or nm["color_buckets"]<=2: findings.append(Finding("high","visual",f"Blank/near-blank screen at step {step}",json.dumps(nm),step))
        if stagnant>=8:
            findings.append(Finding("high","softlock",f"Eight actions produced no meaningful progress by step {step}",f"state={nm['hash'][:16]} delta={d:.5f}",step)); adb("shell","input","keyevent","4",check=False); stagnant=0
        fg=foreground()
        if fg and fg!=a.package and not fg.startswith("com.android"): findings.append(Finding("high","navigation",f"Game lost foreground at step {step}",fg,step))
        timeline.append({"step":step,"action":action,"changed":changed,"novel":novel,"delta":round(d,5),"state":nm["hash"],"foreground":fg})
        cur=nxt; cm=nm; cs=nm["hash"]
    logs=adb("logcat","-d","-v","threadtime",check=False,timeout=60); (out/"logcat.txt").write_text(logs,errors="replace")
    fat=fatal_lines(logs)
    if fat: findings.append(Finding("critical","runtime","Crash/ANR/runtime error detected","\n".join(fat[-40:]),a.steps))
    unique_states=len(states); unique_transitions=len(transitions)
    if a.steps>=60 and unique_states<=5: findings.append(Finding("high","playability","AI tester discovered very little navigable progression",f"unique_states={unique_states} transitions={unique_transitions}",a.steps))
    dedup=[]; seen=set()
    for f in findings:
        k=(f.kind,f.title)
        if k not in seen: seen.add(k); dedup.append(f)
    fingerprint=hashlib.sha1("\n".join(sorted(f"{f.kind}:{f.title}" for f in dedup)).encode()).hexdigest()[:12] if dedup else "clean"
    report={"package":a.package,"seed":a.seed,"steps":a.steps,"coverage":{"unique_states":unique_states,"unique_transitions":unique_transitions,"learned_regions":len(learned)},"findings":[asdict(f) for f in dedup],"timeline":timeline,"fingerprint":fingerprint}
    (out/"report.json").write_text(json.dumps(report,indent=2))
    md=["# Football Dynasty AI Gameplay Test","",f"- Seed: `{a.seed}`",f"- Actions: **{a.steps}**",f"- Unique visual states: **{unique_states}**",f"- Unique transitions: **{unique_transitions}**",f"- Findings: **{len(dedup)}**",""]
    if dedup:
        md += ["## Findings",""]+[f"- **{f.severity.upper()}** `{f.kind}` — {f.title} (step {f.step})" for f in dedup]
    else: md += ["No crash, softlock, blank-screen, or severe navigation finding was detected."]
    (out/"report.md").write_text("\n".join(md))
    worst=max(({"low":1,"medium":2,"high":3,"critical":4}[f.severity] for f in dedup),default=0)
    raise SystemExit(2 if worst>=4 else 0)

if __name__=="__main__": main()
