#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

echo -e "\nIniciant sincronització de models amb internet..."
$engine_structure --profile ollama-externa up
read -p "Prem [Enter] per tornar al menú..."
$engine_structure --profile ollama-externa down
