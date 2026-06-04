#!/usr/bin/env bash
# =============================================================================
# compilar.sh — Compila ESTE proyecto (TFM.tex) usando el contenedor Docker
#               definido en la carpeta padre (Latex_Projects/).
# =============================================================================
# Uso:
#   ./compilar.sh            Compila TFM.tex con latexmk (XeLaTeX, requerido)
#   ./compilar.sh pdflatex   Compila con motor pdfLaTeX (NO sirve: usa fontspec)
#   ./compilar.sh lualatex   Compila con motor LuaLaTeX
#   ./compilar.sh watch      Recompila automáticamente al guardar cambios
#   ./compilar.sh clean      Elimina archivos auxiliares de compilación
#   ./compilar.sh shell      Abre una terminal dentro del contenedor
# =============================================================================

set -euo pipefail

# --- Rutas ---
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
ROOT_DIR="$(cd "$PROJECT_DIR/../.." && pwd)"          # Latex_Projects/
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
WORKDIR="/workspace/projects/$PROJECT_NAME"           # ruta dentro del contenedor

MAIN_TEX="TFM.tex"                                    # archivo principal de este proyecto

# --- Colores ---
GREEN='\033[0;32m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# --- Validaciones ---
if [ ! -f "$COMPOSE_FILE" ]; then
    err "No se encontró docker-compose.yml en $ROOT_DIR"
    exit 1
fi
if [ ! -f "$PROJECT_DIR/$MAIN_TEX" ]; then
    err "No se encontró $MAIN_TEX en $PROJECT_DIR"
    exit 1
fi

# Pasar UID/GID a docker-compose para que el PDF generado sea de tu usuario
# (UID es de solo lectura en bash, por eso se exporta GID y se pasa UID inline)
export GID="$(id -g)"
COMPOSE="env UID=$(id -u) docker compose -f $COMPOSE_FILE"
COMMAND="${1:-compile}"

case "$COMMAND" in
    compile|xelatex)
        info "Compilando $PROJECT_NAME/$MAIN_TEX con latexmk (XeLaTeX)..."
        $COMPOSE run --rm -w "$WORKDIR" latex \
            "latexmk -xelatex -interaction=nonstopmode -file-line-error $MAIN_TEX"
        ok "Salida: $PROJECT_DIR/${MAIN_TEX%.tex}.pdf"
        ;;
    pdflatex)
        info "Compilando $MAIN_TEX con pdfLaTeX (advertencia: este proyecto usa fontspec)..."
        $COMPOSE run --rm -w "$WORKDIR" latex \
            "latexmk -pdf -interaction=nonstopmode -file-line-error $MAIN_TEX"
        ok "Salida: $PROJECT_DIR/${MAIN_TEX%.tex}.pdf"
        ;;
    lualatex)
        info "Compilando $MAIN_TEX con LuaLaTeX..."
        $COMPOSE run --rm -w "$WORKDIR" latex \
            "latexmk -lualatex -interaction=nonstopmode -file-line-error $MAIN_TEX"
        ok "Salida: $PROJECT_DIR/${MAIN_TEX%.tex}.pdf"
        ;;
    watch)
        info "Vigilando cambios en $PROJECT_NAME (Ctrl+C para detener)..."
        $COMPOSE run --rm -w "$WORKDIR" latex \
            "echo 'Esperando cambios en archivos .tex...' && while true; do \
                inotifywait -r -e modify,create --include '\.tex\$' . 2>/dev/null; \
                echo \"[\$(date '+%H:%M:%S')] Recompilando...\"; \
                latexmk -xelatex -interaction=nonstopmode $MAIN_TEX 2>&1 | tail -3; \
            done"
        ;;
    clean)
        info "Limpiando archivos auxiliares en $PROJECT_NAME..."
        $COMPOSE run --rm -w "$WORKDIR" latex \
            "latexmk -C $MAIN_TEX && rm -f *.bbl *.run.xml *.synctex.gz"
        ok "Limpieza completada"
        ;;
    shell)
        info "Abriendo terminal en el contenedor (proyecto: $PROJECT_NAME)..."
        $COMPOSE run --rm -w "$WORKDIR" --entrypoint /bin/bash latex
        ;;
    *)
        err "Comando desconocido: $COMMAND"
        echo "Uso: $0 [compile|xelatex|lualatex|watch|clean|shell]"
        exit 1
        ;;
esac
