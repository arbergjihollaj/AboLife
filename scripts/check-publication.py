#!/usr/bin/env python3
"""Fail on common credential formats and private artifacts in the proposed source tree."""
import pathlib,re,subprocess,sys
ROOT=pathlib.Path(__file__).resolve().parent.parent
PATTERNS={
    'Telegram token':re.compile(rb'\b[0-9]{7,12}:[A-Za-z0-9_-]{30,50}\b'),
    'GitHub token':re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,255}|github_pat_[A-Za-z0-9_]{30,255})\b'),
    'private key':re.compile(rb'-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----'),
    'AWS access key':re.compile(rb'\b(?:AKIA|ASIA)[A-Z0-9]{16}\b')}
EXCLUDED_PREFIXES=('work/','outputs/','plan/','graphify-out/','.understand-anything/','generated_images/','web/.openai/','docs/AboLife_File_Node_Graph')
def allowed(path):
    return not (path.startswith(EXCLUDED_PREFIXES) or '/xcuserdata/' in path or path.endswith('.xcuserstate'))
def candidates():
    raw=subprocess.check_output(['git','ls-files','-z','--cached','--others','--exclude-standard'],cwd=ROOT)
    return sorted({x.decode() for x in raw.split(b'\0') if x and allowed(x.decode()) and (ROOT/x.decode()).is_file()})
def scan(paths):
    findings=[]
    for name in paths:
        path=ROOT/name
        if (path.name.startswith('.env') and path.name!='.env.example') or path.suffix in ('.sqlite','.db','.p12','.key') or 'sqlite-wal' in name or 'sqlite-shm' in name:
            findings.append((name,'private data or credential file'));continue
        for kind,pattern in PATTERNS.items():
            if pattern.search(path.read_bytes()):findings.append((name,kind))
    return findings
if __name__=='__main__':
    paths=candidates();findings=scan(paths)
    for path,kind in findings:print(f'{path}: {kind}',file=sys.stderr)
    print(f'Publication scan: {len(paths)} source files; {len(findings)} findings.')
    sys.exit(bool(findings))
