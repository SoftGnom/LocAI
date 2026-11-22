#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

echo -e "\nIniciant Ollama obert a la xarxa (0.0.0.0)..."
$engine_structure --profile ollama-ext up -d
read -p "Prem [Enter] per tornar al menú..."
