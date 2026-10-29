#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
for tool in docker tailscale python3; do
  command -v "$tool" >/dev/null || { echo "$tool fehlt. Bitte zuerst auf dem Server installieren." >&2; exit 1; }
done
docker compose version >/dev/null
ABOLIFE_TAILSCALE_STATUS=$(tailscale status --json)
export ABOLIFE_TAILSCALE_STATUS
ABOLIFE_SETUP_URL=$(python3 - <<'PY'
import os,json,sys
status=json.loads(os.environ['ABOLIFE_TAILSCALE_STATUS'])
name=status.get('Self',{}).get('DNSName','').rstrip('.')
if status.get('BackendState')!='Running' or not name:
    sys.exit('Tailscale zuerst auf diesem Server anmelden.')
print('https://'+name+':8443')
PY
)
export ABOLIFE_SETUP_URL
python3 - <<'PY'
import os,pathlib,secrets
path=pathlib.Path('.env')
url=os.environ['ABOLIFE_SETUP_URL']
if path.exists():
    configured=next((line.partition('=')[2] for line in path.read_text().splitlines() if line.startswith('ABOLIFE_PUBLIC_URL=')),None)
    if configured!=url:
        raise SystemExit('Vorhandene .env bleibt erhalten. ABOLIFE_PUBLIC_URL muss '+url+' entsprechen.')
else:
    with open(os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w') as f:
        f.write('ABOLIFE_PASSWORD='+secrets.token_urlsafe(32)+'\nABOLIFE_PUBLIC_URL='+url+'\n')
path.chmod(0o600)
PY
docker compose up -d --build --wait
# Own HTTPS port preserves other Homelab services on 443. No public Funnel.
tailscale serve --bg --https=8443 http://127.0.0.1:3055
printf '\nAboLife: %s\n' "$ABOLIFE_SETUP_URL"
printf 'Passwort: ausschließlich in %s/.env\n' "$PWD"
printf 'Diese URL auf Mac und iPhone mit aktivem Tailscale verwenden.\n'
printf 'Status: docker compose ps / tailscale serve status\n'
printf 'Sicherung: docker compose exec -T abolife node backup.mjs\n'
