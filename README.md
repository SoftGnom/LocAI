# 🤖 LocAI - Entorn Local d'Intel·ligència Artificial

**LocAI** és una plataforma desacoblada i automatitzada per a l'execució local de models de llenguatge (LLM) mitjançant **Ollama** i agents d'IA avançats mitjançant **Hermes Agent**. 

Està dissenyada prioritzant la **seguretat**, l'**aïllament de xarxa** i la **sincronització declarativa** de models.

---

## 📋 Taula de Continguts

1. [Estructura del Projecte](#-estructura-del-projecte)
2. [Requisits Previs](#-requisits-previs)
3. [Perfils d'Execució](#-perfils-dexecució)
4. [Gestió Declarativa de Models (`models.json`)](#-gestió-declarativa-de-models-modelsjson)
5. [Scripts de Gestió Interactiva (`menu.sh` / `menu-Podman.sh`)](#-scripts-de-gestió-interactiva)
6. [Sincronització i Reports Automàtics](#-sincronització-i-reports-automàtics)
7. [Guia Pas a Pas d'Ús](#-guia-pas-a-pas-dús)
8. [Serveis i Ports](#-serveis-i-ports)

---

## 📁 Estructura del Projecte

```text
.
├── compose.yml                       # Definició dels serveis, perfils i xarxes Docker/Podman
├── menu.sh                           # Menú de gestió interactiu per a Docker
├── menu-Podman.sh                    # Menú de gestió interactiu per a Podman
├── README.md                         # Documentació del projecte
└── 01-Volums/
    ├── 01_01-LLM-Ollama/             # Persistent storage d'Ollama (models descarregats)
    ├── 01_02-Ollama-Sync/            # Volum de sincronització i configuració
    │   ├── models.json               # Fitxer JSON amb la llista de models desitjats
    │   ├── sync.sh                   # Script d'automatització (s'executa dins del contenidor)
    │   └── reports/                  # Històric de reports de sincronització (generats auto)
    └── 02_02-Agent-Hermes/           # Dades persistents de l'Agent Hermes
        ├── config/                   # Configuració de l'agent
        └── workspace/                # Espai de treball i fitxers de l'agent
```

---

## ⚙️ Requisits Previs

* **Motor de contenidors**: `docker` amb `docker compose` O BEN BÉ `podman` amb `podman-compose`.
* **Suport GPU** (Opcional pero recomanat): Driver NVIDIA i `nvidia-container-toolkit` configurat.
* **Interpreter Python 3**: Requerit al host per a l'execució dels scripts de menú (`menu.sh` / `menu-Podman.sh`).

---

## 🚀 Perfils d'Execució

El projecte s'organitza en 3 perfils principals d'Ollama i 3 variants d'Hermes Agent:

### 1. Perfil Producció (`produccio`)
* **Objectiu**: Execució normal del sistema complet (Ollama + Hermes Agent).
* **Xarxa**: Aïllat a la xarxa interna (`ia-net-interna`) **sense accés a Internet**.
* **Comportament**: Ollama actua com a backend per a Hermes. Cap dels dos serveis pot fer connexions cap a l'exterior.

### 2. Perfil amb Internet / Descàrregues (`ollama-externa`)
* **Objectiu**: Sincronitzar la biblioteca local de models d'Ollama d'acord amb `models.json`.
* **Xarxa**: Connectat a la xarxa externa (`ia-net-externa`) amb **accés a Internet**.
* **Comportament**:
  1. Executa l'script `/sync/sync.sh` automàticament com a `entrypoint`.
  2. Descarrega els nous models especificats al JSON.
  3. Elimina els models locals que ja no figuren al JSON.
  4. Genera un report únic amb timestamp a `01-Volums/01_02-Ollama-Sync/reports/`.
  5. Atura el contenidor automàticament en finalitzar.

### 3. Perfil Sense Internet / Proves (`ollama-interna`)
* **Objectiu**: Executar Ollama en mode aïllat manualment per a proves del desenvolupador.
* **Xarxa**: `network_mode: none` (totalment desconnectat de qualsevol xarxa).

---

## 📄 Gestió Declarativa de Models (`models.json`)

El fitxer `01-Volums/01_02-Ollama-Sync/models.json` defineix l'estat desitjat de la biblioteca de models:

```json
{
  "models": [
    "llama3.2:3b",
    "qwen2.5:7b",
    "deepseek-r1:8b"
  ]
}
```

* Si afegiu un model a la llista, el perfil `ollama-externa` el descarregarà automàticament.
* Si el publiqueu sense etiquetes (ex: `"llama3.2"`), el sistema el normalitzarà automàticament a `"llama3.2:latest"`.
* Si esborreu un model d'aquesta llista, l'script de sincronització l'eliminarà del disc per alliberar espai.

---

## 🖥️ Scripts de Gestió Interactiva

Pots utilitzar els menús interactius per no haver de recordar les comandes de Docker/Podman:

* Per a entorns Docker: `./menu.sh`
* Per a entorns Podman: `./menu-Podman.sh`

### Funcionalitats del Menú:
1. **🚀 2.1.1 PERFIL PRODUCCIÓ**: Arrenca Ollama i Hermes en xarxa interna aïllada.
2. **🔄 2.1.2 PERFIL AMB INTERNET**: Executa la sincronització de models segons el JSON i genera el report.
3. **🧪 2.1.3 PERFIL SENSE INTERNET**: Inicia Ollama aïllat per a proves puntuals.
4. **⚙️ EDITAR MODELS JSON**: Submenú que permet:
   * Veure la llista actual de models.
   * Eliminar models del JSON prement el seu número (`❌ ELIMINAR model`).
   * Afegir nous models introduint el seu nom/tag (`➕ AFEGIR un nou model`).
   * Tornar al menú anterior prement `0`.

---

## 📊 Sincronització i Reports Automàtics

Cada vegada que s'executa el perfil `ollama-externa`, l'script intern `sync.sh`:
1. Crea la subcarpeta `01-Volums/01_02-Ollama-Sync/reports/` si no existeix.
2. Genera un log únic basat en la data i hora: `sync_report_YYYYMMDD_HHMMSS.log`.
3. Registra:
   * Models sol·licitats al JSON.
   * Models prèviament instal·lats.
   * Accions d'eliminació i descàrrega efectuades.
   * Estat final de la llista de models a Ollama.

Exemple de report generat (`reports/sync_report_20261007_223800.log`):

```text
==================================================
 INICI DE LA SINCRONITZACIÓ OLLAMA: Wed Oct  7 22:38:00 CEST 2026
==================================================
Esperant que el servidor Ollama estigui a punt... [OK]

--- DESITJATS EN JSON ---
llama3.2:3b
qwen2.5:7b

--- INSTAL·LATS ACTUALMENT ---
qwen2.5:7b
gemma:2b

--- ACCIONS REALITZADES ---
[ELIMINANT] Model no trobat al JSON: gemma:2b
[OMÈS] El model qwen2.5:7b ja existeix localment.
[DESCARREGANT] Nou model: llama3.2:3b

--- ESTAT FINAL DE MODELS ---
NAME         ID           SIZE   MODIFIED
llama3.2:3b  a80c4f172edd 2.0 GB Just now
qwen2.5:7b   84323e59335a 4.7 GB 2 days ago

==================================================
 SINCRONITZACIÓ FINALITZADA: Wed Oct  7 22:39:15 CEST 2026
==================================================
```

---

## 🛠️ Guia Pas a Pas d'Ús

### 1. Donar permisos d'execució als scripts
```bash
chmod +x menu.sh menu-Podman.sh 01-Volums/01_02-Ollama-Sync/sync.sh
```

### 2. Configurar o afegir models desitjats
Executa el menú (`./menu.sh` o `./menu-Podman.sh`), tria l'opció `4` i afegeix els models que vulguis utilitzar (ex: `llama3.2:3b`).

### 3. Sincronitzar/Descarregar els models
Dins del menú, selecciona l'opció `2` (**PERFIL AMB INTERNET**). El contenidor descarregarà els models i s'aturarà sol quan acabi.

### 4. Arrencar en Producció
Selecciona l'opció `1` (**PERFIL PRODUCCIÓ**). Això aixecarà Ollama i Hermes Agent de forma aïllada i segura.

---

## 🔌 Serveis i Ports

Quan el perfil **Producció** està actiu, es pot accedir als següents serveis des del `localhost` del host:

| Servei | Descripció | URL / Endpoint Local |
| :--- | :--- | :--- |
| **Hermes Web Dashboard** | Interfície gràfica d'Hermes Agent | `http://127.0.0.1:9119` |
| **Hermes API Gateway** | API d'integració amb Hermes | `http://127.0.0.1:8642` |
| **Ollama API** | API REST nativa d'Ollama | `http://127.0.0.1:11434` |