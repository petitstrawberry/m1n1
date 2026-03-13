#!/usr/bin/env python3
import sys
import pathlib
import subprocess
import gzip

sys.path.append(str(pathlib.Path(__file__).resolve().parent / "proxyclient"))

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Create boot.bin for m1n1 + U-Boot')
    parser.add_argument('--dtb', type=pathlib.Path, default=None, help='DTB file (auto-detect if not specified)')
    parser.add_argument('--output', '-o', type=pathlib.Path, default=None, help='Output file')
    parser.add_argument('machine', nargs='?', default='j293', help='Machine code (e.g., j293 for MacBook Pro M1 13")')
    args = parser.parse_args()

    base = pathlib.Path(__file__).resolve().parent
    
    m1n1_bin = base / "payloads" / "m1n1.bin"
    uboot_bin = base / "payloads" / "u-boot-nodtb.bin"
    dtb_dir = base / "payloads" / "dtb"
    
    if not m1n1_bin.exists():
        print(f"Error: {m1n1_bin} not found")
        sys.exit(1)
    if not uboot_bin.exists():
        print(f"Error: {uboot_bin} not found")
        sys.exit(1)
    
    if args.dtb:
        dtb = args.dtb
    else:
        dtb = dtb_dir / f"t8103-{args.machine}.dtb"
        if not dtb.exists():
            dtb = dtb_dir / f"t6000-{args.machine}.dtb"
        if not dtb.exists():
            dtb = dtb_dir / f"t6020-{args.machine}.dtb"
    
    if not dtb.exists():
        print(f"Error: DTB not found for {args.machine}")
        print(f"Available DTBs:")
        for d in sorted(dtb_dir.glob("*.dtb")):
            print(f"  {d.name}")
        sys.exit(1)
    
    output = args.output or base / "payloads" / f"boot-{args.machine}.bin"
    
    print(f"m1n1: {m1n1_bin}")
    print(f"DTB:  {dtb}")
    print(f"U-Boot: {uboot_bin}")
    print(f"Output: {output}")
    
    uboot_gz = pathlib.Path("/tmp") / "u-boot-nodtb.bin.gz"
    with open(uboot_bin, "rb") as f_in:
        with gzip.open(uboot_gz, "wb") as f_out:
            f_out.write(f_in.read())
    
    with open(output, "wb") as out:
        out.write(m1n1_bin.read_bytes())
        out.write(dtb.read_bytes())
        out.write(uboot_gz.read_bytes())
    
    print(f"Created {output} ({output.stat().st_size} bytes)")

if __name__ == "__main__":
    main()
