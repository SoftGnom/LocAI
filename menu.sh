#!/bin/bash

# Fixar el directori de treball al directori on resideix el main.sh
cd "$(dirname "$0")" || exit 1

# Exportar variables de rutes globals per als scripts fills
export ROOT_DIR="$(pwd)"
export LIB_DIR="$ROOT_DIR/lib"

# Carregar la llibreria central de funcions compartides
if [ -f "$LIB_DIR/core.sh" ]; then
  source "$LIB_DIR/core.sh"
else
  echo "⚠️ Avís: No s'ha trobat $LIB_DIR/core.sh"
fi

# Funció recursiva per gestionar submenús i accions de manera dinàmica
run_menu() {
  local current_menu_dir="$1"
  local menu_title="$2"

  while true; do
    clear
    echo "=================================================="
    echo "         $menu_title"
    echo "=================================================="
    echo ""

    # Obtenir elements ordenats alfabèticament/numèricament de la carpeta
    mapfile -t items < <(find "$current_menu_dir" -mindepth 1 -maxdepth 1 | sort)

    local index=1
    declare -A option_map

    for item in "${items[@]}"; do
      local name
      name=$(basename "$item")
      
      # Netejar prefixos numèrics tipus "1_", "2_" i extensions per mostrar-ho bonic
      local display_name
      display_name=$(echo "$name" | sed 's/^[0-9]\+_//g' | sed 's/\.sh$//' | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')

      if [ -d "$item" ]; then
        echo "  [$index] 📁 $display_name"
      elif [ -f "$item" ] && [[ "$item" == *.sh ]]; then
        echo "  [$index] 🚀 $display_name"
      else
        continue
      fi

      option_map[$index]="$item"
      index=$((index + 1))
    done

    echo ""
    echo "  [0] ⬅️  Tornar enrere / Sortir"
    echo "=================================================="
    read -p "Selecciona una opció: " opt

    if [ "$opt" = "0" ] || [ -z "$opt" ]; then
      break
    fi

    if [[ -n "${option_map[$opt]}" ]]; then
      local selected_path="${option_map[$opt]}"
      
      if [ -d "$selected_path" ]; then
        # Si és una carpeta, obrim el submenú recursivament
        local sub_title
        sub_title=$(basename "$selected_path" | sed 's/^[0-9]\+_//g' | tr '[:lower:]' '[:upper:]' | tr '_' ' ')
        run_menu "$selected_path" "MENÚ: $sub_title"
      elif [ -f "$selected_path" ]; then
        # Si és un fitxer .sh, l'executem directament
        bash "$selected_path"
      fi
    else
      echo "⚠️ Opció no vàlida."
      sleep 1.5
    fi
  done
}

# Punt d'entrada inicial
run_menu "$ROOT_DIR/menu" "LocAI - MENÚ DINÀMIC"
