#!/usr/bin/env python3
import os
import sys
import json
import time
import traceback
import argparse
from pygtail import Pygtail


parser = argparse.ArgumentParser(
    prog = "hackinsdn-guardian.py",
    description = (
        "Adds remote IPS mode to Suricata (consume alert events and send "
        "remote blocking requests)"
    )
)
parser.add_argument('-e', '--suricata_eve', default="", required=True)
parser.add_argument('-i', '--interval', default="10")
parser.add_argument('-r', '--rounds', default="inf")
parser.add_argument('-d', '--block_duration', default="300")

args = parser.parse_args()

suricata_eve = args.suricata_eve
n_run=float(args.rounds)
run_interval=int(args.interval)
block_duration = int(args.block_duration)

active_blocks_file = f"{suricata_eve}.active_blocks"
script_dir = os.path.dirname(os.path.realpath(__file__))

def process_events():
    if not os.path.isfile(suricata_eve):
        return
    lines_interest = []
    for line in Pygtail(suricata_eve):
        if '"event_type":"alert"' not in line:
            continue
        if '"action":"blocked"' not in line:
            continue
        lines_interest.append(line)

    events_by_src = {}
    for line in lines_interest:
        event = json.loads(line)
        idx = str(event.get("vlan", ["untagged"])[0]) + "---" + event["src_ip"]
        #print(f"process event {idx}")
        events_by_src.setdefault(idx, [])
        events_by_src[idx].append(event)

    active_blocks = {}
    if os.path.isfile(active_blocks_file):
        active_blocks = json.load(open(active_blocks_file))

    cur_time = time.time()
    old_blocks = dict(active_blocks)
    for key, value in events_by_src.items():
        if key not in old_blocks:
            vlan, src_ip = key.split("---")
            os.system(f"{script_dir}/block.sh {vlan} {src_ip}")
        old_blocks.pop(key, None)
        active_blocks[key] = {"expire": cur_time + block_duration}

    for key, value in old_blocks.items():
        if value["expire"] < cur_time:
            vlan, src_ip = key.split("---")
            os.system(f"{script_dir}/unblock.sh {vlan} {src_ip}")
            active_blocks.pop(key)

    with open(active_blocks_file, 'w') as f:
        json.dump(active_blocks, f)

while n_run > 0:
    try:
        process_events()
        time.sleep(run_interval)
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception:
        err = traceback.format_exc().replace("\n", ", ")
        print(err)
        sys.exit(0)
    n_run -= 1
