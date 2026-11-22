#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

open_URL "http://localhost:8642"
open_URL "http://localhost:9119"

echo -e "\nIniciant perfil de PRODUCCIÓ (Ollama + Hermes)..."
$engine_structure --profile produccio-ha up -d
read -p "Prem [Enter] per tornar al menú..."
