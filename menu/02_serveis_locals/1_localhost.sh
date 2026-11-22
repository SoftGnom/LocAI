#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

echo -e "\nIniciant Ollama en mode Localhost (127.0.0.1)..."
$engine_structure --profile ollama-host up -d
read -p "Prem [Enter] per tornar al menú..."
