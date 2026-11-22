#!/usr/bin/env bash
# run_pi_task.sh - Orquestrador automàtic per a l'agent Pi amb OverlayFS, volums etiquetats i execució concurrent

set -e

# Carregar la llibreria central per disposar de ROOT_DIR
source "$ROOT_DIR/lib/core.sh"

CONFIG_FILE="${ROOT_DIR}/config.json"
OVERLAY_SCRIPT="${ROOT_DIR}/overlay_manager.sh"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: No s'ha trobat el fitxer $CONFIG_FILE"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' no està instal·lat."
    exit 1
fi

# --- MENÚ INTERACTIU SI NO ES PASSA CAP PARÀMETRE ---
if [ -z "$1" ]; then
    echo "=== Selecciona un perfil de configuració ==="
    mapfile -t PROFILES < <(jq -r '.profiles | keys[]' "$CONFIG_FILE")
    
    if [ ${#PROFILES[@]} -eq 0 ]; then
        echo "Error: No hi ha cap perfil definit a $CONFIG_FILE."
        exit 1
    fi

    select PROFILE in "${PROFILES[@]}"; do
        if [ -n "$PROFILE" ]; then
            break
        else
            echo "Opció no vàlida. Torna-ho a provar."
        fi
    done
else
    PROFILE="$1"
fi

echo "=================================================="
echo " Carregant perfil: '$PROFILE'"
echo "=================================================="

# 1. Llegir propietats bàsiques del perfil
OVERLAY_PROFILE=$(jq -r --arg p "$PROFILE" '.profiles[$p].overlay_profile // empty' "$CONFIG_FILE")
REL_PROMPT_FILE=$(jq -r --arg p "$PROFILE" '.profiles[$p].prompt_file // empty' "$CONFIG_FILE")
PROMPT_FILE="${ROOT_DIR}/${REL_PROMPT_FILE}"
OLLAMA_MODEL=$(jq -r --arg p "$PROFILE" '.profiles[$p].ollama_model // "llama3"' "$CONFIG_FILE")

if [ -z "$OVERLAY_PROFILE" ] || [ -z "$REL_PROMPT_FILE" ]; then
    echo "Error: El perfil '$PROFILE' no té 'overlay_profile' o 'prompt_file' definits al JSON."
    exit 1
fi

# 2. Muntar l'OverlayFS mitjançant l'script gestor
echo "[1/4] Comprovant i muntant l'OverlayFS ($OVERLAY_PROFILE)..."
if [ -f "$OVERLAY_SCRIPT" ]; then
    chmod +x "$OVERLAY_SCRIPT"
    "$OVERLAY_SCRIPT" "$ROOT_DIR" mount "$OVERLAY_PROFILE"
else
    echo "Error: No s'ha trobat l'script OverlayFS a $OVERLAY_SCRIPT"
    exit 1
fi

# 3. Llegir configuració fixa global de Docker del JSON
echo "[2/4] Carregant paràmetres fixos de Docker..."
DOCKER_ARGS=""

# Extra Hosts
NUM_HOSTS=$(jq '.global_docker_config.extra_hosts | length' "$CONFIG_FILE")
for ((i=0; i<NUM_HOSTS; i++)); do
    EXTRA_HOST=$(jq -r --argjson i "$i" '.global_docker_config.extra_hosts[$i]' "$CONFIG_FILE")
    DOCKER_ARGS="$DOCKER_ARGS --add-host=$EXTRA_HOST"
done

# Variables d'entorn globals
eval "$(jq -r '.global_docker_config.environment | to_entries | map("export \(.key)=\(.value)") | .[]' "$CONFIG_FILE")"
for key in $(jq -r '.global_docker_config.environment | keys[]' "$CONFIG_FILE"); do
    val=$(jq -r --arg k "$key" '.global_docker_config.environment[$k]' "$CONFIG_FILE")
    DOCKER_ARGS="$DOCKER_ARGS -e $key=$val"
done

# 4. Construir dinàmicament els volums i mostrar les seves etiquetes
echo "[3/4] Preparant volums i finalitats:"
NUM_VOLS=$(jq --arg p "$PROFILE" '.profiles[$p].volumes | length' "$CONFIG_FILE")

for ((i=0; i<NUM_VOLS; i++)); do
    LABEL=$(jq -r --arg p "$PROFILE" --argjson i "$i" '.profiles[$p].volumes[$i].label // "Sense etiqueta"' "$CONFIG_FILE")
    H_PATH=$(jq -r --arg p "$PROFILE" --argjson i "$i" '.profiles[$p].volumes[$i].host' "$CONFIG_FILE")
    C_PATH=$(jq -r --arg p "$PROFILE" --argjson i "$i" '.profiles[$p].volumes[$i].container' "$CONFIG_FILE")
    MODE=$(jq -r --arg p "$PROFILE" --argjson i "$i" '.profiles[$p].volumes[$i].mode // "rw"' "$CONFIG_FILE")
    
    # Assegurar rutes absolutes al host basades en ROOT_DIR
    if [[ "$H_PATH" != /* ]]; then
        ABS_H_PATH="${ROOT_DIR}/${H_PATH#./}"
    else
        ABS_H_PATH="$H_PATH"
    fi

    if [ ! -d "$ABS_H_PATH" ] && [ ! -f "$ABS_H_PATH" ]; then
        mkdir -p "$ABS_H_PATH"
    fi
    
    DOCKER_ARGS="$DOCKER_ARGS -v $ABS_H_PATH:$C_PATH:$MODE"
    
    echo "   -> [$MODE] $C_PATH <- $ABS_H_PATH"
    echo "      Finalitat: $LABEL"
done

# Afegir el prompt/tasca com a volum de només lectura
if [ -f "$PROMPT_FILE" ]; then
    ABS_PROMPT_PATH=$(realpath "$PROMPT_FILE")
    DOCKER_ARGS="$DOCKER_ARGS -v $ABS_PROMPT_PATH:/app/tasca.md:ro"
else
    echo "Error: El fitxer de prompt '$PROMPT_FILE' no existeix."
    exit 1
fi

# Generar un nom de contenidor totalment únic per evitar conflictes
UNIQUE_CONTAINER_NAME="pi_agent_${PROFILE}_$$-${RANDOM}"

# 5. Execució del contenidor Docker amb --rm
echo "[4/4] Llançant l'agent Pi (Contenidor: $UNIQUE_CONTAINER_NAME)..."
echo "--------------------------------------------------"

docker run --rm \
    --name "$UNIQUE_CONTAINER_NAME" \
    $DOCKER_ARGS \
    pi-runner \
    run --model "$OLLAMA_MODEL" --file /app/tasca.md --dir /workspace

echo "--------------------------------------------------"
echo " Tasca finalitzada amb èxit! El contenidor s'ha tancat i eliminat."
read -p "Prem [Enter] per tornar al menú..."
