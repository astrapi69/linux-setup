#!/usr/bin/env python3
import argparse, json
from linux_setup_backend import run_provision, get_latest

def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    a = sub.add_parser("audit");  a.add_argument("--profile", default="desktop"); a.add_argument("--quick", action="store_true")
    h = sub.add_parser("harden"); h.add_argument("--profile", default="desktop")
    f = sub.add_parser("fix");    f.add_argument("fix_id")

    sub.add_parser("latest")

    args = p.parse_args()
    if args.cmd == "audit":
        ok, meta = run_provision("audit", profile=args.profile, quick=args.quick)
    elif args.cmd == "harden":
        ok, meta = run_provision("harden", profile=args.profile)
    elif args.cmd == "fix":
        ok, meta = run_provision("fix", profile="", quick=False); meta["note"]=f"FIX placeholder id={args.fix_id}"
    else:
        print(json.dumps(get_latest(), indent=2)); return

    print(json.dumps(meta, indent=2))
    exit(0 if meta.get("ok") else 1)

if __name__ == "__main__":
    main()
