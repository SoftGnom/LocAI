#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

open_URL "http://localhost:3000"

echo -e "\nIniciant perfil de PRODUCCIÓ (Open WebUI + Terminal)..."
$engine_structure --profile produccio-ow up -d
read -p "Prem [Enter] per tornar al menú..."
