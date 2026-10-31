#!/usr/bin/env bash
# CRMoveis · inicia o prototipo (Linux/macOS). Antes, crie o banco com ../executar_tudo.sh
set -e
cd "$(dirname "$0")"
[ -d .venv ] || python3 -m venv .venv
.venv/bin/python -c "import flask, psycopg" 2>/dev/null || .venv/bin/pip install -q -r requirements.txt
if [ ! -f .env ]; then
  read -rp "Usuario do PostgreSQL [postgres]: " U; U=${U:-postgres}
  read -rsp "Senha: " P; echo
  P=$(.venv/bin/python -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$P")
  sed "s#postgresql://postgres:SUA_SENHA@#postgresql://$U:$P@#" .env.example > .env
fi
echo "Prototipo em http://127.0.0.1:${CRM_PORTA:-5003}"
exec .venv/bin/python app.py
