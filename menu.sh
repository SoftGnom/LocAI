#!/bin/bash

# Ruta del fitxer JSON de configuració
JSON_FILE="01-Volums/01_02-Ollama-Sync/models.json"
CONFIG_FILE="config.json"

# Assegurar que la carpeta i el fitxer JSON existeixen
mkdir -p "$(dirname "$JSON_FILE")"
if [ ! -f "$JSON_FILE" ]; then
  echo '{"models": []}' > "$JSON_FILE"
fi

# Funció per obtenir la llista de models del JSON
get_models() {
  jq -r '.models[]?' "$JSON_FILE" 2>/dev/null
}

# Funció per afegir un model al JSON
add_model() {
  local model_name="$1"
  # Si està buit, no fem res
  [ -z "$model_name" ] && return
  # Comprovar si ja existeix
  if jq -e --arg m "$model_name" '.models | index($m) != null' "$JSON_FILE" >/dev/null 2>&1; then
    return
  fi
  # Afegir-lo
  local tmp
  tmp=$(mktemp)
  jq --arg m "$model_name" '.models += [$m]' "$JSON_FILE" > "$tmp" && mv "$tmp" "$JSON_FILE"
}

# Funció per eliminar un model del JSON segons el seu índex
delete_model() {
  local index="$1"
  local tmp
  tmp=$(mktemp)
  jq --argjson i "$index" 'del(.models[$i])' "$JSON_FILE" > "$tmp" && mv "$tmp" "$JSON_FILE"
}

# Submenú per gestionar la llista de models a models.json
manage_json_menu() {
  while true; do
    clear
    echo "=================================================="
    echo "       GESTIÓ DE MODELS (models.json)"
    echo "=================================================="
    echo ""
    mapfile -t models_list < <(get_models)
    local count=${#models_list[@]}

    # Comprovar si el primer element està buit (llista buida)
    if [ $count -eq 1 ] && [ -z "${models_list[0]}" ]; then
      count=0
    fi

    if [ $count -eq 0 ]; then
      echo "  (No hi ha cap model configurat actualment)"
    else
      for i in "${!models_list[@]}"; do
        num=$((i + 1))
        echo "  [$num] ❌ ELIMINAR model: ${models_list[$i]}"
      done
    fi

    echo ""
    local add_option=$((count + 1))
    echo "  [$add_option] ➕ AFEGIR un nou model"
    echo "  [0] ⬅️  Tornar al menú principal"
    echo "=================================================="
    read -p "Selecciona una opció: " opt

    # Opcions del submenú
    if [ "$opt" = "0" ]; then
      break
    elif [ "$opt" -eq "$add_option" ] 2>/dev/null; then
      echo ""
      read -p "Introdueix el nom del nou model (ex: llama3.2:3b, deepseek-r1:8b): " new_model
      if [ -n "$new_model" ]; then
        add_model "$new_model"
        echo "✅ Model '$new_model' afegit correctament!"
        sleep 1.5
      fi
    elif [ "$opt" -ge 1 ] 2>/dev/null && [ "$opt" -le "$count" ] 2>/dev/null; then
      local idx=$((opt - 1))
      local deleted_model="${models_list[$idx]}"
      delete_model "$idx"
      echo "🗑️  Model '$deleted_model' eliminat del JSON!"
      sleep 1.5
    else
      echo "⚠️ Opció no vàlida."
      sleep 1.5
    fi
  done
}

# Funció per obtenir el comandament d'execució de la configruacio
get_engine_structure() {
  jq -r '.container_engine_structure // "podman compose"' "$CONFIG_FILE" 2>/dev/null
}

# Funció per obtenir el comandament d'execució de la configruacio
get_engine() {
  jq -r '.container_engine // "podman"' "$CONFIG_FILE" 2>/dev/null
}

# Menú Principal
main_menu() {
  while true; do
    local engine_structure
    engine_structure=$(get_engine_structure)
    local engine
    engine=$(get_engine)
    clear
    echo "=================================================="
    echo "         LocAI - MENÚ DE GESTIÓ OLLAMA"
    echo "=================================================="
    echo "  1) 🚀 PRODUCCIÓ: Ollama Int + Hermes Pro"
    echo "  2) 🚀 PRODUCCIÓ (WebUI): Ollama Int + Open WebUI + Terminal"
    echo "  3) 🔒 LOCALHOST: Ollama en 127.0.0.1:11434"
    echo "  4) 🌐 XARXA LAN: Ollama en 0.0.0.0:11434"
    echo "  5) 🔄 SINCRONITZAR: Amb Internet (Descàrrega models JSON)"
    echo "  6) 🧪 PROVA AÏLLADA: Ollama sense xarxa (network_mode: none)"
    echo "  7) ⚙️ EDITAR MODELS JSON"
    echo "  8) 📊 VEURE ESTAT / LOGS DELS CONTENIDORS"
    echo "  9) 🛑 ATURAR TOTS ELS SERVEIS"
    echo "  0) 🚪 Sortir"
    echo "=================================================="
    read -p "Selecciona una opció [0-9]: " option

    case $option in
      1)
        echo -e "\nIniciant perfil de PRODUCCIÓ (Ollama + Hermes)..."
        $engine_structure --profile produccio-ha up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      2)
        echo -e "\nIniciant perfil de PRODUCCIÓ (Open WebUI + Terminal)..."
        $engine_structure --profile produccio-ow up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      3)
        echo -e "\nIniciant Ollama en mode Localhost (127.0.0.1)..."
        $engine_structure --profile ollama-host up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      4)
        echo -e "\nIniciant Ollama obert a la xarxa (0.0.0.0)..."
        $engine_structure --profile ollama-ext up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      5)
        echo -e "\nIniciant sincronització de models amb internet..."
        $engine_structure --profile ollama-externa up
        read -p "Prem [Enter] per tornar al menú..."
        $engine_structure --profile ollama-externa down
        ;;
      6)
        echo -e "\nIniciant Ollama aïllat de la xarxa..."
        $engine_structure --profile ollama-interna up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      7)
        manage_json_menu
        ;;
      8)
        echo -e "\n--- Contenidors en execució ---"
        $engine ps
        echo ""
        read -p "Vols veure els logs en directe? (s/N): " logs_opt
        if [[ "$logs_opt" =~ ^[Ss]$ ]]; then
          $engine_structure --profile "*" logs -f
        fi
        ;;
      9)
        echo -e "\nAturant tots els serveis..."
        $engine_structure --profile "*" down --remove-orphans
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      0)
        echo -e "\nFins aviat!"
        exit 0
        ;;
      *)
        echo "⚠️ Opció no vàlida!"
        sleep 1
        ;;
    esac
  done
}

main_menu
