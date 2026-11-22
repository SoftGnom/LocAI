#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

echo -e "\nIniciant Ollama aïllat de la xarxa..."
$engine_structure --profile ollama-interna up -d
read -p "Prem [Enter] per tornar al menú..."
