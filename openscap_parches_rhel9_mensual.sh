#!/usr/bin/env bash
set -euo pipefail

# =========================
# Configuración
# =========================
REPORT_DIR="/var/reports/openscap/parches"
LOG_DIR="/var/log/openscap"
DATE="$(date +%F)"
HOST="$(hostname -f 2>/dev/null || hostname)"
OVAL_URL="https://security.access.redhat.com/data/oval/v2/RHEL9/rhel-9.oval.xml.bz2"

OVAL_BZ2="${REPORT_DIR}/rhel-9.oval.xml.bz2"
OVAL_XML="${REPORT_DIR}/rhel-9.oval.xml"

RESULTS_XML="${REPORT_DIR}/oval-results-${HOST}-${DATE}.xml"
REPORT_HTML="${REPORT_DIR}/parches-report-${HOST}-${DATE}.html"
RUN_LOG="${LOG_DIR}/openscap-parches-${HOST}-${DATE}.log"

# Mantener evidencia y orden
umask 027
mkdir -p "${REPORT_DIR}" "${LOG_DIR}"

exec > >(tee -a "${RUN_LOG}") 2>&1

echo "==== OpenSCAP Parches RHEL9 - Inicio: $(date -Is) ===="
echo "Host: ${HOST}"
echo "Directorio reportes: ${REPORT_DIR}"
echo

# =========================
# Prechecks / dependencias
# =========================
echo "[1/6] Verificando dependencias..."
if ! command -v dnf >/dev/null 2>&1; then
  echo "ERROR: dnf no está disponible."
  exit 1
fi

# Paquetes necesarios: openscap + bzip2 + wget/curl
# (wget suele estar, pero garantizamos curl si falta)
dnf -y install openscap-scanner bzip2 wget curl >/dev/null

echo "OK - Dependencias instaladas/verificadas."
echo

# =========================
# Depuración kernels viejos
# =========================
echo "[2/6] Depurando kernels viejos (mantener 2)..."
# IMPORTANTE: esto NO debe remover el kernel en ejecución; dnf maneja installonly.
# Aun así, se recomienda correr fuera de ventanas críticas.
dnf -y remove --oldinstallonly --setopt installonly_limit=2 kernel || true
echo "OK - Depuración kernels finalizada."
echo

# =========================
# Descargar OVAL más actual
# =========================
echo "[3/6] Descargando OVAL actual de Red Hat..."
# Intentar descarga condicional con wget -N; si falla, usar curl con -z
if command -v wget >/dev/null 2>&1; then
  wget -q -N -O "${OVAL_BZ2}" "${OVAL_URL}"
else
  # curl: descarga solo si el remoto es más nuevo (si ya existe)
  if [[ -f "${OVAL_BZ2}" ]]; then
    curl -fsSL -z "${OVAL_BZ2}" -o "${OVAL_BZ2}" "${OVAL_URL}"
  else
    curl -fsSL -o "${OVAL_BZ2}" "${OVAL_URL}"
  fi
fi
echo "OK - OVAL descargado: ${OVAL_BZ2}"
echo

# =========================
# Descomprimir
# =========================
echo "[4/6] Descomprimiendo OVAL..."
# -f para sobrescribir si ya existía
bunzip2 -f -k "${OVAL_BZ2}"   # deja el .bz2 y genera el .xml
# bunzip2 por defecto genera rhel-9.oval.xml en el mismo dir
# Validación rápida
if [[ ! -s "${OVAL_XML}" ]]; then
  echo "ERROR: No se generó ${OVAL_XML} o está vacío."
  exit 1
fi
echo "OK - OVAL descomprimido: ${OVAL_XML}"
echo

# =========================
# Ejecutar evaluación OVAL + HTML
# =========================
echo "[5/6] Ejecutando OpenSCAP OVAL eval (XML + HTML)..."
oscap oval eval \
  --results "${RESULTS_XML}" \
  --report "${REPORT_HTML}" \
  "${OVAL_XML}"

echo "OK - Resultados:"
echo "  XML:  ${RESULTS_XML}"
echo "  HTML: ${REPORT_HTML}"
echo

# =========================
# Retención (opcional)
# =========================
echo "[6/6] Retención: borrando reportes/logs antiguos (opcional)..."
# Mantener 13 meses (aprox 400 días). Ajusta a tu política.
find "${REPORT_DIR}" -type f -name "*-${HOST}-*.html" -mtime +400 -delete || true
find "${REPORT_DIR}" -type f -name "*-${HOST}-*.xml"  -mtime +400 -delete || true
find "${LOG_DIR}"    -type f -name "openscap-parches-${HOST}-*.log" -mtime +400 -delete || true
echo "OK - Retención aplicada."
echo

echo "==== OpenSCAP Parches RHEL9 - Fin: $(date -Is) ===="
