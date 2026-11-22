#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

echo -e "\nAturant tots els serveis..."
$engine_structure --profile "*" down --remove-orphans
read -p "Prem [Enter] per tornar al menú..."
