#!/usr/bin/env python3
"""Local/CI quality gates; formatting never mutates files without --fix-format."""
import argparse
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fix-format', action='store_true')
    args = parser.parse_args()
    ignored = {s.strip() for s in (ROOT / '.swift-format-ignore').read_text().splitlines() if s.strip() and not s.startswith('#')}
    files = sorted(str(p.relative_to(ROOT)) for folder in ['AboLife', 'AboLifeTests', 'AboLifeUITests'] for p in (ROOT / folder).rglob('*.swift') if str(p.relative_to(ROOT)) not in ignored)
    command = ['xcrun', 'swift-format', 'format' if args.fix_format else 'lint', '--configuration', '.swift-format']
    command += ['--in-place'] if args.fix_format else ['--strict']
    results = [subprocess.run(command + files, cwd=ROOT).returncode]
    if not shutil.which('swiftlint'):
        print('SwiftLint fehlt. Aus offizieller Homebrew-Formel installieren: brew install swiftlint', file=sys.stderr)
        results.append(1)
    else:
        results.append(subprocess.run(['swiftlint', 'lint', '--quiet', '--strict', '--cache-path', str(ROOT / 'work' / 'swiftlint-cache'), '--baseline', '.swiftlint-baseline.json'], cwd=ROOT).returncode)
    results.append(subprocess.run([sys.executable, 'scripts/check-publication.py'], cwd=ROOT).returncode)
    print(f'Format scope: {len(files)} Swift files; {len(ignored)} legacy paths explicitly excluded from formatting only.')
    return int(any(results))

if __name__ == '__main__':
    sys.exit(main())
