#!/bin/bash
source "$ROOT_DIR/lib/core.sh"
engine_structure=$(get_engine_structure)

while true; do
  clear
  echo "=================================================="
  echo "          🚀 CONFIGURACIÓ I EXECUCIÓ D'AIDER"
  echo "=================================================="

  def_model=$(jq -r '.aider_default_model // "qwen2.5-coder:14b"' "$CONFIG_FILE")

  echo " 1) ⚡ Execució RÀPIDA (Model i Ruta per defecte)"
  echo "    └─ Model: $def_model"
  echo "    └─ Ruta: ./04-Projecte"
  echo ""
  echo " 2) 📁 Triar Projecte dels PRESETS del config.json"
  echo " 3) 🔍 Navegar i triar directori MANUALMENT (Navegador visual)"
  echo " 4) ⚙️  Personalitzar MODEL i RUTA completament"
  echo " [0] ⬅️  Tornar al menú anterior"
  echo "=================================================="
  read -p "Selecciona una opció: " aider_opt

  selected_model="$def_model"
  selected_workspace="./04-Projecte"

  case $aider_opt in
    1)
      # Ràpida: Valors per defecte
      ;;
    2)
      # Crida directa a la nova funció de presets
      preset_path=$(select_preset_workspace)
      if [ $? -eq 0 ] && [ -n "$preset_path" ]; then
        selected_workspace="$preset_path"
      else
        continue # Si cancel·la o dóna error, torna al submenú d'Aider
      fi
      ;;
    3)
      # Navegador visual de directoris
      selected_workspace=$(select_directory)
      ;;
    4)
      # Personalització completa (Model + Ruta)
      clear
      echo "--- 1. SELECCIÓ DE MODEL ---"
      mapfile -t avail_models < <(get_models)
      for i in "${!avail_models[@]}"; do
        echo "  [$((i+1))] ${avail_models[$i]}"
      done
      echo "  [M] ✏️ Escriure nom de model manualment"
      echo ""
      read -p "Tria model [Default: $def_model]: " m_opt

      if [ "$m_opt" = "M" ] || [ "$m_opt" = "m" ]; then
        read -p "Introdueix el nom del model exactament: " manual_m
        selected_model="${manual_m:-$def_model}"
      elif [[ "$m_opt" =~ ^[0-9]+$ ]] && [ "$m_opt" -ge 1 ] && [ "$m_opt" -le "${#avail_models[@]}" ]; then
        selected_model="${avail_models[$((m_opt-1))]}"
      fi

      echo -e "\n--- 2. SELECCIÓ DE RUTA ---"
      echo " 1) Triar d'un PRESET de config.json"
      echo " 2) Ús del Navegador visual"
      echo " 3) Escriure ruta manualment"
      read -p "Opció [1-3]: " path_mode

      if [ "$path_mode" = "1" ]; then
        preset_path=$(select_preset_workspace)
        if [ $? -eq 0 ] && [ -n "$preset_path" ]; then
          selected_workspace="$preset_path"
        fi
      elif [ "$path_mode" = "2" ]; then
        selected_workspace=$(select_directory)
      else
        read -p "Introdueix ruta absoluta o relativa: " manual_w
        selected_workspace="${manual_w:-./04-Projecte}"
      fi
      ;;
    0)
      break
      ;;
    *)
      echo "⚠️ Opció no vàlida!"
      sleep 1
      continue
      ;;
  end

  # Execució d'Aider un cop tenim model i workspace definits
  echo -e "\n🚀 Iniciant Aider..."
  echo " 📌 Model: $selected_model"
  echo " 📌 Ruta:  $selected_workspace"
  echo "=================================================="

  export AIDER_MODEL="$selected_model"
  export AIDER_WORKSPACE="$selected_workspace"

  $engine_structure --profile aider run --rm aider

  unset AIDER_MODEL
  unset AIDER_WORKSPACE

  read -p "Prem [Enter] per tornar..."
  $engine_structure --profile aider down
  break
done
