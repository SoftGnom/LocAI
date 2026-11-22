#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)
engine=$(get_engine)

echo -e "\n--- Contenidors en execució ---"
$engine ps
echo ""
read -p "Prem [Enter] per obrir el seguiment de logs en directe..."

$engine_structure --profile "*" logs -f
read -p "Prem [Enter] per obrir el seguiment de logs en directe..."
