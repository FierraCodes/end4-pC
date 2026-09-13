#!/usr/bin/env python3
import json, subprocess, time, os, sys

lockfile = "/tmp/qs-autostart.lock"
force = "--force" in sys.argv or "-f" in sys.argv

if not force and os.path.exists(lockfile):
    exit(0)

open(lockfile, 'w').close()

config_path = f"{os.environ['HOME']}/.config/illogical-impulse/config.json"
if not os.path.exists(config_path):
    exit(0)

try:
    with open(config_path) as f:
        data = json.load(f)
except Exception:
    exit(1)

autostart = data.get('hyprland', {}).get('autostartApps', {})
if not autostart.get('enable', False) and not force:
    exit(0)

for app in autostart.get('apps', []):
    cmd = app.get('cmd', '').strip()
    workspace = app.get('workspace', 1)
    delay = app.get('delay', 0)
    if not cmd:
        continue

    subprocess.run(['hyprctl', 'dispatch', f'hl.dsp.focus({{workspace = {workspace}}})'],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    expanded_cmd = os.path.expanduser(cmd)
    subprocess.Popen(
        ['hyprctl', 'dispatch', f'hl.dsp.exec_cmd("{expanded_cmd}")'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        close_fds=True
    )

    if delay > 0:
        time.sleep(delay)