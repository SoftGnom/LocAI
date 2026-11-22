#!/bin/bash

# Rutes base configurades globalment
JSON_FILE="${ROOT_DIR}/01-Volums/01_02-Ollama-Sync/models.json"
CONFIG_FILE="${ROOT_DIR}/config.json"

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
  [ -z "$model_name" ] && return
  if jq -e --arg m "$model_name" '.models | index($m) != null' "$JSON_FILE" >/dev/null 2>&1; then
    return
  fi
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

# Submenú per gestionar models.json
manage_json_menu() {
  while true; do
    clear
    echo "=================================================="
    echo "        GESTIÓ DE MODELS (models.json)"
    echo "=================================================="
    echo ""
    mapfile -t models_list < <(get_models)
    local count=${#models_list[@]}

    # Si la llista conté un element buit (fitxer buit o jq sense resultats)
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
    echo "  [0] ⬅️  Tornar enrere"
    echo "=================================================="
    read -p "Selecciona una opció: " opt

    if [ "$opt" = "0" ] || [ -z "$opt" ]; then
      break
    elif [[ "$opt" =~ ^[0-9]+$ ]] && [ "$opt" -eq "$add_option" ]; then
      echo ""
      read -p "Introdueix el nom del nou model (ex: llama3.2:3b, deepseek-r1:8b): " new_model
      if [ -n "$new_model" ]; then
        add_model "$new_model"
        echo "✅ Model '$new_model' afegit correctament!"
        sleep 1.5
      fi
    elif [[ "$opt" =~ ^[0-9]+$ ]] && [ "$opt" -ge 1 ] && [ "$opt" -le "$count" ]; then
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

# Obtenir l'estructura d'execució de contenidors (podman compose / docker compose)
get_engine_structure() {
  jq -r '.container_engine_structure // "podman compose"' "$CONFIG_FILE" 2>/dev/null
}

# Obtenir el motor de contenidors (podman / docker)
get_engine() {
  jq -r '.container_engine // "podman"' "$CONFIG_FILE" 2>/dev/null
}

# Seleccionar projecte a partir dels presets del config.json
select_preset_workspace() {
  clear
  echo "=================================================="
  echo "         PRESETS DE PROJECTES (config.json)"
  echo "=================================================="
  
  local preset_count
  preset_count=$(jq '.project_presets | length' "$CONFIG_FILE" 2>/dev/null)
  
  if [ -z "$preset_count" ] || [ "$preset_count" -eq 0 ]; then
    echo "⚠️ No hi ha presets definits a config.json"
    sleep 2
    return 1
  fi
  
  for i in $(seq 0 $((preset_count - 1))); do
    local p_name
    local p_path
    p_name=$(jq -r ".project_presets[$i].name" "$CONFIG_FILE")
    p_path=$(jq -r ".project_presets[$i].path" "$CONFIG_FILE")
    echo "  [$((i+1))] $p_name -> ($p_path)"
  done
  
  echo ""
  read -p "Tria un preset [1-$preset_count] o [0] per cancel·lar: " p_opt
  
  if [ "$p_opt" = "0" ] || [ -z "$p_opt" ]; then
    return 1
  fi
  
  if [[ "$p_opt" =~ ^[0-9]+$ ]] && [ "$p_opt" -ge 1 ] && [ "$p_opt" -le "$preset_count" ]; then
    jq -r ".project_presets[$((p_opt-1))].path" "$CONFIG_FILE"
    return 0
  else
    echo "⚠️ Opció no vàlida."
    sleep 1.5
    return 1
  fi
}

# Navegador visual de directoris per a l'Aider
select_directory() {
  local current_dir="$(pwd)"
  while true; do
    clear
    echo "=================================================="
    echo "       NAVEGADOR DE DIRECTORIS PER A AIDER"
    echo "=================================================="
    echo " Ruta actual: $current_dir"
    echo "--------------------------------------------------"
    
    mapfile -t dirs < <(ls -d "$current_dir"/*/ 2>/dev/null)
    
    echo "  [0] ✅ CONFIRMAR I UTILITZAR AQUESTA RUTA"
    echo "  [..] ⬅️  Pujar al directori pare"
    echo ""
    for i in "${!dirs[@]}"; do
      folder_name=$(basename "${dirs[$i]}")
      echo "  [$((i+1))] 📁 $folder_name"
    done
    echo "=================================================="
    read -p "Selecciona una opció o directori: " dir_opt

    if [ "$dir_opt" = "0" ]; then
      echo "$current_dir"
      return 0
    elif [ "$dir_opt" = ".." ]; then
      current_dir="$(dirname "$current_dir")"
    elif [[ "$dir_opt" =~ ^[0-9]+$ ]] && [ "$dir_opt" -ge 1 ] && [ "$dir_opt" -le "${#dirs[@]}" ]; then
      current_dir="${dirs[$((dir_opt-1))]}"
      current_dir="${current_dir%/}"
    else
      echo "⚠️ Opció no vàlida!"
      sleep 1
    fi
  done
}



# --- FUNCIONS PER A LA GESTIO DE PERFIL DE TASQUES (JSON) ---

# Obtenir la llista de claus de perfils disponibles
get_profiles() {
  jq -r '.profiles | keys[]?' "$JSON_FILE" 2>/dev/null
}

# Obtenir un camp concret d'un perfil (ex: overlay_profile, prompt_file, ollama_model)
get_profile_field() {
  local profile="$1"
  local field="$2"
  jq -r --arg p "$profile" '.profiles[$p].' "$JSON_FILE" 2>/dev/null | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
}

# Obtenir el nombre de volums configurats en un perfil
get_profile_volumes_count() {
  local profile="$1"
  jq -r --arg p "$profile" '.profiles[$p].volumes | length // 0' "$JSON_FILE" 2>/dev/null
}

# Obtenir un atribut concret d'un volum d'un perfil segons l'índex (label, host, container, mode)
get_profile_volume_field() {
  local profile="$1"
  local index="$2"
  local field="$3"
  jq -r --arg p "$profile" --argjson i "$index" '.profiles[$p].volumes[$i].' "$JSON_FILE" 2>/dev/null | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null
}


# --- FUNCIONS PER A LA GESTIO DE LAS EINES GRAFICAS ---

open_URL() {
  local URL="$1"
  local PERFIL_TEMP=$(mktemp -d)

  # S'executa en segon pla sense bloquejar la resta de l'script
  (
    firefox --no-remote --new-instance --profile "$PERFIL_TEMP" "$URL"
    rm -rf "$PERFIL_TEMP"
  ) &
}

