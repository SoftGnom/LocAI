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



# Funció per seleccionar un projecte a partir dels presets del config.json
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
    # Retornem directament la ruta per capturar-la
    jq -r ".project_presets[$((p_opt-1))].path" "$CONFIG_FILE"
    return 0
  else
    echo "⚠️ Opció no vàlida."
    sleep 1.5
    return 1
  fi
}


# Funció per navegar i seleccionar un directori de manera fàcil
select_directory() {
  local current_dir="$(pwd)"
  while true; do
    clear
    echo "=================================================="
    echo "       NAVEGADOR DE DIRECTORIS PER A AIDER"
    echo "=================================================="
    echo " Ruta actual: $current_dir"
    echo "--------------------------------------------------"
    
    # Llistar només directoris
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
      # Eliminar la barra final si existeix
      current_dir="${current_dir%/}"
    else
      echo "⚠️ Opció no vàlida!"
      sleep 1
    fi
  done
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
    echo "  3) 🚀 PRODUCCIÓ (Aider): Ollama Int + Aider"
    echo "  4) 🔒 LOCALHOST: Ollama en 127.0.0.1:11434"
    echo "  5) 🌐 XARXA LAN: Ollama en 0.0.0.0:11434"
    echo "  6) 🔄 SINCRONITZAR: Amb Internet (Descàrrega models JSON)"
    echo "  7) 🧪 PROVA AÏLLADA: Ollama sense xarxa (network_mode: none)"
    echo "  8) ⚙️ EDITAR MODELS JSON"
    echo "  9) 📊 VEURE ESTAT / LOGS DELS CONTENIDORS"
    echo "  S) 🛑 ATURAR TOTS ELS SERVEIS"
    echo "  E) 🚪 Sortir"
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
          echo " [0] ⬅️  Tornar al menú principal"
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
              break 2
              ;;
            *)
              echo "⚠️ Opció no vàlida!"
              sleep 1
              continue
              ;;
          esac

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
        ;;
      4)
        echo -e "\nIniciant Ollama en mode Localhost (127.0.0.1)..."
        $engine_structure --profile ollama-host up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      5)
        echo -e "\nIniciant Ollama obert a la xarxa (0.0.0.0)..."
        $engine_structure --profile ollama-ext up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      6)
        echo -e "\nIniciant sincronització de models amb internet..."
        $engine_structure --profile ollama-externa up
        read -p "Prem [Enter] per tornar al menú..."
        $engine_structure --profile ollama-externa down
        ;;
      7)
        echo -e "\nIniciant Ollama aïllat de la xarxa..."
        $engine_structure --profile ollama-interna up -d
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      8)
        manage_json_menu
        ;;
      9)
        echo -e "\n--- Contenidors en execució ---"
        $engine ps
        echo ""
        read -p "Vols veure els logs en directe? (s/N): " logs_opt
        if [[ "$logs_opt" =~ ^[Ss]$ ]]; then
          $engine_structure --profile "*" logs -f
        fi
        ;;
      S)
        echo -e "\nAturant tots els serveis..."
        $engine_structure --profile "*" down --remove-orphans
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      E)
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
