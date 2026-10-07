#!/bin/bash

# Ruta del fitxer JSON de configuració
JSON_FILE="01-Volums/01_02-Ollama-Sync/models.json"

# Assegurar que la carpeta i el fitxer JSON existeixen
mkdir -p "$(dirname "$JSON_FILE")"
if [ ! -f "$JSON_FILE" ]; then
  echo '{"models": []}' > "$JSON_FILE"
fi

# Funció per obtenir la llista de models del JSON
get_models() {
  python3 -c "import json; data=json.load(open('$JSON_FILE')); print('\n'.join(data.get('models', [])))" 2>/dev/null
}

# Funció per afegir un model al JSON
add_model() {
  local model_name="$1"
  python3 -c "
import json
with open('$JSON_FILE', 'r+') as f:
    data = json.load(f)
    models = data.get('models', [])
    if '$model_name' not in models and '$model_name'.strip() != '':
        models.append('$model_name')
        data['models'] = models
        f.seek(0)
        json.dump(data, f, indent=2)
        f.truncate()
" 2>/dev/null
}

# Funció per eliminar un model del JSON segons el seu índex
delete_model() {
  local index="$1"
  python3 -c "
import json
with open('$JSON_FILE', 'r+') as f:
    data = json.load(f)
    models = data.get('models', [])
    if 0 <= $index < len(models):
        models.pop($index)
        data['models'] = models
        f.seek(0)
        json.dump(data, f, indent=2)
        f.truncate()
" 2>/dev/null
}

# Submenú per gestionar la llista de models a models.json
manage_json_menu() {
  while true; do
    clear
    echo "=================================================="
    echo "       GESTIÓ DE MODELS (models.json)"
    echo "=================================================="
    echo ""
    echo "Llista de models configurats per a la sincronització:"
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
      echo "⚠️ Opció no vàlida. Torna-ho a intentar."
      sleep 1.5
    fi
  done
}

# Menú Principal
main_menu() {
  while true; do
    clear
    echo "=================================================="
    echo "         LocAI - MENÚ DE GESTIÓ OLLAMA"
    echo "=================================================="
    echo "  1) 🚀 2.1.1 PERFIL PRODUCCIÓ (Ollama Pro + Hermes Pro)"
    echo "  2) 🔄 2.1.2 PERFIL AMB INTERNET (Sincronitzar models i report)"
    echo "  3) 🧪 2.1.3 PERFIL SENSE INTERNET (Comprovar estat fora de xarxa)"
    echo "  4) ⚙️  EDITAR MODELS JSON (Afegir / Eliminar models)"
    echo "  0) 🚪 Sortir"
    echo "=================================================="
    read -p "Selecciona una opció [0-4]: " option

    case $option in
      1)
        echo -e "\nIniciant entorn de producció..."
        docker compose --profile produccio up -d
        echo ""
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      2)
        echo -e "\nIniciant sincronització de models amb internet..."
        docker compose --profile ollama-externa up ollama-externa
        echo ""
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      3)
        echo -e "\nIniciant contenidor fora de xarxa..."
        docker compose --profile ollama-interna up -d ollama-interna
        echo ""
        read -p "Prem [Enter] per tornar al menú..."
        ;;
      4)
        manage_json_menu
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

# Iniciar l'script
main_menu
