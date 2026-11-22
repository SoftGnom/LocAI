#!/usr/bin/env bash
# overlay_manager.sh - Gestor modular d'estructures OverlayFS amb rutes relatives i selecció segura

set -euo pipefail

# Comprovar si jq està instal·lat
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' no està instal·lat. Instal·la'l amb 'sudo apt install jq'." >&2
    exit 1
fi

ROOT_PATH=""
CONFIG_FILE=""

# ==========================================
# 1. MÒDUL DE CONFIGURACIÓ I ESTAT (JSON)
# ==========================================

init_environment() {
    local target_path="$1"
    ROOT_PATH="$(realpath "$target_path")"
    CONFIG_FILE="${ROOT_PATH}/config.json"

    # Crear l'estructura base de carpetes obligatòries
    mkdir -p "${ROOT_PATH}"/{capa_base,gestio,duplicats,contingut_virtual}

    # Inicialitzar el JSON amb estructura neta i sense rutes absolutes d'usuari
    if [ ! -f "$CONFIG_FILE" ]; then
        jq -n '{
            profiles: {}
        }' > "$CONFIG_FILE"
        echo "S'ha creat el fitxer de configuració privat: $CONFIG_FILE"
    fi
}

save_profile_status() {
    local profile="$1"
    local status="$2"
    local tmp
    tmp=$(jq --arg p "$profile" --arg s "$status" '.profiles[$p].status = $s' "$CONFIG_FILE")
    echo "$tmp" > "$CONFIG_FILE"
}

# Funció auxiliar per seleccionar perfils de manera interactiva i evitar errades de teclat
select_profile_interactive() {
    local profiles
    profiles=$(jq -r '.profiles | keys[]' "$CONFIG_FILE" 2>/dev/null || true)
    
    if [ -z "$profiles" ]; then
        echo "Error: No hi ha cap perfil registrat." >&2
        return 1
    fi

    local profile_array=($profiles)
    local count=${#profile_array[@]}

    # Si només hi ha un perfil, el seleccionem directament
    if [ "$count" -eq 1 ]; then
        echo "${profile_array[0]}"
        return 0
    fi

    echo -n "---------------------------------\n"
    echo "Perfils disponibles:"
    local i=1
    for p in "${profile_array[@]}"; do
        echo "  $i) $p"
        i=$((i+1))
    done
    echo -n "Tria el número del perfil: "
    read -r choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$count" ]; then
        echo "${profile_array[$((choice-1))]}"
    else
        echo "Error: Selecció no vàlida." >&2
        return 1
    fi
}

# ==========================================
# 2. MÒDUL DE SISTEMA DE FITXERS I PERFIL
# ==========================================

cmd_create_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        echo -n "Nom del nou perfil: "
        read -r profile
    fi

    if [ -z "$profile" ]; then
        echo "Error: El nom del perfil no pot estar buit." >&2
        return 1
    fi

    # Rutes relatives per guardar al JSON (privacitat total)
    local upper="duplicats/${profile}"
    local work="gestio/${profile}"
    local merged="contingut_virtual/${profile}"

    # Crear carpetes físiques a disc utilitzant ROOT_PATH
    mkdir -p "${ROOT_PATH}/$upper" "${ROOT_PATH}/$work" "${ROOT_PATH}/$merged"

    # Registrar al JSON amb rutes relatives
    local tmp
    tmp=$(jq --arg p "$profile" \
             --arg u "$upper" \
             --arg w "$work" \
             --arg m "$merged" \
             '.profiles[$p] = {upper: $u, work: $w, merged: $m, status: "unmounted"}' "$CONFIG_FILE")
    echo "$tmp" > "$CONFIG_FILE"

    echo "Perfil '$profile' creat correctament."
}

cmd_delete_profile() {
    local profile="$1"
    if [ -z "$profile" ]; then
        profile=$(select_profile_interactive) || return 1
    fi
    
    # Desmuntar primer de forma segura si està actiu
    cmd_umount "$profile" 2>/dev/null || true

    # Esborrar carpetes físiques
    rm -rf "${ROOT_PATH}/duplicats/${profile}"
    rm -rf "${ROOT_PATH}/gestio/${profile}"
    rm -rf "${ROOT_PATH}/contingut_virtual/${profile}"

    # Eliminar del registre JSON
    local tmp
    tmp=$(jq --arg p "$profile" 'del(.profiles[$p])' "$CONFIG_FILE")
    echo "$tmp" > "$CONFIG_FILE"

    echo "Perfil '$profile' eliminat correctament."
}

# ==========================================
# 3. MÒDUL D'OPERACIONS KERNEL (OVERLAYFS)
# ==========================================

get_real_status() {
    local profile="$1"
    local merged
    merged=$(jq -r --arg p "$profile" '.profiles[$p].merged' "$CONFIG_FILE")
    if mountpoint -q "${ROOT_PATH}/${merged}"; then
        echo "[ACTIU / MUNTAT]"
    else
        echo "[INACTIU / DESMUNTAT]"
    fi
}

cmd_mount() {
    local profile="$1"
    if [ -z "$profile" ]; then
        profile=$(select_profile_interactive) || return 1
    fi

    # Llegir rutes relatives del JSON i convertir-les a absolutes per al Kernel
    local upper_rel work_rel merged_rel
    upper_rel=$(jq -r --arg p "$profile" '.profiles[$p].upper // empty' "$CONFIG_FILE")
    work_rel=$(jq -r --arg p "$profile" '.profiles[$p].work // empty' "$CONFIG_FILE")
    merged_rel=$(jq -r --arg p "$profile" '.profiles[$p].merged // empty' "$CONFIG_FILE")

    if [ -z "$upper_rel" ]; then
        echo "Error: El perfil '$profile' no existeix al fitxer de configuració." >&2
        return 1
    fi

    local upper="${ROOT_PATH}/${upper_rel}"
    local work="${ROOT_PATH}/${work_rel}"
    local merged="${ROOT_PATH}/${merged_rel}"
    local base="${ROOT_PATH}/capa_base"

    if mountpoint -q "$merged"; then
        echo "Avís: El perfil '$profile' ja estava muntat."
        save_profile_status "$profile" "mounted"
        return 0
    fi

    echo "Muntant OverlayFS per al perfil '$profile'..."
    sudo mount -t overlay "overlay_${profile}" \
        -o lowerdir="$base",upperdir="$upper",workdir="$work" \
        "$merged"

    save_profile_status "$profile" "mounted"
    echo "Perfil '$profile' muntat a '$merged'."
}

cmd_umount() {
    local profile="$1"
    if [ -z "$profile" ]; then
        profile=$(select_profile_interactive) || return 1
    fi

    local merged_rel
    merged_rel=$(jq -r --arg p "$profile" '.profiles[$p].merged // empty' "$CONFIG_FILE")
    if [ -z "$merged_rel" ]; then
        echo "Error: El perfil '$profile' no existeix." >&2
        return 1
    fi

    local merged="${ROOT_PATH}/${merged_rel}"

    if mountpoint -q "$merged"; then
        echo "Desmuntant OverlayFS per al perfil '$profile'..."
        sudo umount "$merged"
        save_profile_status "$profile" "unmounted"
        echo "Perfil '$profile' desmuntat correctament."
    else
        echo "Avís: El perfil '$profile' ja estava desmuntat."
        save_profile_status "$profile" "unmounted"
    fi
}

cmd_collapse() {
    local profile="$1"
    if [ -z "$profile" ]; then
        profile=$(select_profile_interactive) || return 1
    fi

    local upper_rel work_rel
    upper_rel=$(jq -r --arg p "$profile" '.profiles[$p].upper' "$CONFIG_FILE")
    work_rel=$(jq -r --arg p "$profile" '.profiles[$p].work' "$CONFIG_FILE")

    local upper="${ROOT_PATH}/${upper_rel}"
    local work="${ROOT_PATH}/${work_rel}"
    local base="${ROOT_PATH}/capa_base"

    echo "--- Iniciant procés de col·lapse del perfil '$profile' ---"
    cmd_umount "$profile"

    echo "Consolidant canvis a la capa base..."
    sudo rsync -aHAX --delete "$upper/" "$base/"

    echo "Netejant canvis temporals del perfil '$profile'..."
    sudo rm -rf "${upper:?}"/* "${work:?}"/*

    cmd_mount "$profile"
    echo "Col·lapse completat amb èxit!"
}

cmd_list() {
    echo "--- Estats dels Perfils ---"
    if ! jq -e '.profiles | length > 0' "$CONFIG_FILE" >/dev/null 2>&1; then
        echo "No hi ha cap perfil registrat."
        return
    fi

    for profile in $(jq -r '.profiles | keys[]' "$CONFIG_FILE"); do
        local json_status real_status
        json_status=$(jq -r --arg p "$profile" '.profiles[$p].status // "unknown"' "$CONFIG_FILE")
        real_status=$(get_real_status "$profile")
        echo " - Perfil: [$profile] | JSON: $json_status | Kernel: $real_status"
    done
}

# ==========================================
# 4. MÒDUL D'INTERFÍCIE (MENÚ)
# ==========================================

show_menu() {
    while true; do
        echo -e "\n================================="
        echo "    GESTOR OVERLAYFS (MENÚ)"
        echo "================================="
        echo "1) Llistar perfils (Estat JSON vs Real)"
        echo "2) Crear perfil nou"
        echo "3) Muntar perfil"
        echo "4) Desmuntar perfil"
        echo "5) Col·lapsar canvis d'un perfil"
        echo "6) Esborrar perfil"
        echo "0) Sortir"
        echo -n "Tria una opció: "
        read -r opt

        case $opt in
            1) cmd_list ;;
            2) cmd_create_profile "" ;;
            3) cmd_mount "" ;;
            4) cmd_umount "" ;;
            5) cmd_collapse "" ;;
            6) cmd_delete_profile "" ;;
            0) exit 0 ;;
            *) echo "Opció no vàlida." ;;
        esac
    done
}

# ==========================================
# 5. EXECUCIÓ / ENTRADA DE PARÀMETRES
# ==========================================

if [ $# -lt 1 ]; then
    echo "Ús: $0 <path_arrel> [comandament] [nom_perfil]"
    echo "Exemple interactiu: $0 /opt/app"
    exit 1
fi

init_environment "$1"

COMMAND="${2:-menu}"
PROFILE_NAME="${3:-}"

case "$COMMAND" in
    init)
        echo "Estructura inicial verificada correctament a: $ROOT_PATH"
        ;;
    create)
        cmd_create_profile "$PROFILE_NAME"
        ;;
    mount)
        cmd_mount "$PROFILE_NAME"
        ;;
    umount)
        cmd_umount "$PROFILE_NAME"
        ;;
    collapse)
        cmd_collapse "$PROFILE_NAME"
        ;;
    delete)
        cmd_delete_profile "$PROFILE_NAME"
        ;;
    list)
        cmd_list
        ;;
    menu)
        show_menu
        ;;
    *)
        echo "Comandament desconegut: $COMMAND"
        echo "Opcions vàlides: init, create, mount, umount, collapse, delete, list, menu"
        exit 1
        ;;
es:
