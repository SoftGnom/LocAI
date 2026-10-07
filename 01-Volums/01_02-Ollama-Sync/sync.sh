#!/bin/bash

# Directoris i fitxers
REPORTS_DIR="/sync/reports"
CONFIG_FILE="/sync/models.json"

# Crear la subcarpeta si no existeix
mkdir -p "$REPORTS_DIR"

# Nom únic amb marca de temps (Ex: sync_report_20261007_223800.log)
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORTS_DIR/sync_report_${TIMESTAMP}.log"

echo "==================================================" | tee "$REPORT_FILE"
echo " INICI DE LA SINCRONITZACIÓ OLLAMA: $(date)" | tee -a "$REPORT_FILE"
echo "==================================================" | tee -a "$REPORT_FILE"

# 1. Iniciar el servidor Ollama en segon pla
ollama serve > /dev/null 2>&1 &
SERVER_PID=$!

# 2. Esperar que el servei estigui actiu
echo -n "Esperant que el servidor Ollama estigui a punt..." | tee -a "$REPORT_FILE"
until ollama list > /dev/null 2>&1; do
  sleep 2
done
echo " [OK]" | tee -a "$REPORT_FILE"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: No s'ha trobat el fitxer $CONFIG_FILE" | tee -a "$REPORT_FILE"
  kill $SERVER_PID
  exit 1
fi

# 3. Obtenir llista de models desitjats del JSON
DESIRED_MODELS=$(grep -o '"[^"]*"' "$CONFIG_FILE" | grep -v '"models"' | tr -d '"')

# 4. Obtenir llista de models actuals
CURRENT_MODELS=$(ollama list | tail -n +2 | awk '{print $1}')

echo -e "\n--- DESITJATS EN JSON ---" | tee -a "$REPORT_FILE"
echo "$DESIRED_MODELS" | tee -a "$REPORT_FILE"

echo -e "\n--- INSTAL·LATS ACTUALMENT ---" | tee -a "$REPORT_FILE"
echo "$CURRENT_MODELS" | tee -a "$REPORT_FILE"

echo -e "\n--- ACCIONS REALITZADES ---" | tee -a "$REPORT_FILE"

# A. Eliminar models que JA NO estan al JSON
for current in $CURRENT_MODELS; do
  FOUND=0
  for desired in $DESIRED_MODELS; do
    NORMALIZED_DESIRED="$desired"
    [[ "$NORMALIZED_DESIRED" != *":"* ]] && NORMALIZED_DESIRED="${NORMALIZED_DESIRED}:latest"
    NORMALIZED_CURRENT="$current"
    [[ "$NORMALIZED_CURRENT" != *":"* ]] && NORMALIZED_CURRENT="${NORMALIZED_CURRENT}:latest"

    if [ "$NORMALIZED_CURRENT" == "$NORMALIZED_DESIRED" ]; then
      FOUND=1
      break
    fi
  done

  if [ $FOUND -eq 0 ]; then
    echo "[ELIMINANT] Model no trobat al JSON: $current" | tee -a "$REPORT_FILE"
    ollama rm "$current" >> "$REPORT_FILE" 2>&1
  fi
done

# B. Descarregar models NOUS o actualitzar
for desired in $DESIRED_MODELS; do
  FOUND=0
  for current in $CURRENT_MODELS; do
    NORMALIZED_DESIRED="$desired"
    [[ "$NORMALIZED_DESIRED" != *":"* ]] && NORMALIZED_DESIRED="${NORMALIZED_DESIRED}:latest"
    NORMALIZED_CURRENT="$current"
    [[ "$NORMALIZED_CURRENT" != *":"* ]] && NORMALIZED_CURRENT="${NORMALIZED_CURRENT}:latest"

    if [ "$NORMALIZED_CURRENT" == "$NORMALIZED_DESIRED" ]; then
      FOUND=1
      break
    fi
  done

  if [ $FOUND -eq 0 ]; then
    echo "[DESCARREGANT] Nou model: $desired" | tee -a "$REPORT_FILE"
    ollama pull "$desired" >> "$REPORT_FILE" 2>&1
  else
    echo "[OMÈS] El model $desired ja existeix localment." | tee -a "$REPORT_FILE"
  fi
done

echo -e "\n--- ESTAT FINAL DE MODELS ---" | tee -a "$REPORT_FILE"
ollama list | tee -a "$REPORT_FILE"

echo -e "\n==================================================" | tee -a "$REPORT_FILE"
echo " SINCRONITZACIÓ FINALITZADA: $(date)" | tee -a "$REPORT_FILE"
echo "==================================================" | tee -a "$REPORT_FILE"

# Tancar el servidor perquè el contenidor s'aturi automàticament
kill $SERVER_PID
