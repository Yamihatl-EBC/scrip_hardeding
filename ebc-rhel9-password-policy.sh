#!/usr/bin/env bash
#
# Aplica la Política de contraseñas EBC v1.0 en RHEL 9 (cuentas locales).
#
# Uso:   sudo ./ebc-rhel9-password-policy.sh
# Opciones (variables de entorno):
#   PROFILE=sssd|minimal      Perfil authselect si el servidor no tiene uno activo (default: sssd)
#   INSTALL_FAIL2BAN=yes|no   Instalar/configurar fail2ban para SSH (default: yes)
#   F2B_IGNOREIP="..."        IPs que fail2ban nunca bloquea (bastión, monitoreo, admins)
#
# IMPORTANTE: deja una sesión root abierta mientras corres el script y prueba
# un nuevo login en otra terminal antes de cerrarla.
#
# Cubre:  4.1, 4.2 (local), 4.3, 5.1, 6, 8 (auditoría) y 9 (evidencia).
# No cubre (ver notas al final): MFA (sec. 7), longitud de 20 para privilegiadas,
# contraseñas filtradas en brechas y el límite de 12 h en aplicaciones.
#
set -euo pipefail

PROFILE="${PROFILE:-sssd}"
INSTALL_FAIL2BAN="${INSTALL_FAIL2BAN:-yes}"
F2B_IGNOREIP="${F2B_IGNOREIP:-127.0.0.1/8 ::1}"

TS="$(date +%F-%H%M%S)"
BACKUP="/root/ebc-backup-${TS}"
EVID_DIR="/var/log/ebc-hardening"
EVID_FILE="${EVID_DIR}/evidencia-$(hostname -s)-${TS}.txt"

log()  { printf '\033[1;32m[OK]\033[0m   %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[ERR]\033[0m  %s\n' "$*" >&2; exit 1; }

# Reemplaza (idempotente) un bloque administrado por este script dentro de un archivo.
# Comenta cualquier línea activa previa de las claves indicadas para evitar duplicados.
apply_block() {
  local file="$1" keys="$2" content="$3"
  touch "$file"
  sed -Ei "/^# BEGIN EBC-POLICY/,/^# END EBC-POLICY/d; s/^(${keys})([[:space:]=]|\$)/# \1\2/" "$file"
  { echo "# BEGIN EBC-POLICY"; printf '%s\n' "$content"; echo "# END EBC-POLICY"; } >> "$file"
}

set_logindefs() {
  local key="$1" val="$2"
  if grep -Eq "^[[:space:]]*${key}[[:space:]]" /etc/login.defs; then
    sed -Ei "s|^[[:space:]]*${key}[[:space:]]+.*|${key} ${val}|" /etc/login.defs
  else
    echo "${key} ${val}" >> /etc/login.defs
  fi
}

# ---------------------------------------------------------------- 0. Validaciones
[[ $EUID -eq 0 ]] || die "Ejecutar como root."
# shellcheck disable=SC1091
. /etc/os-release
[[ "${VERSION_ID%%.*}" == "9" ]] || die "Este script es solo para RHEL 9 (detectado: ${PRETTY_NAME})."
command -v authselect >/dev/null || die "authselect no está instalado."

# ---------------------------------------------------------------- 1. Respaldo
mkdir -p "$BACKUP"
cp -a /etc/pam.d /etc/security /etc/ssh /etc/login.defs "$BACKUP"/
[[ -d /etc/systemd/logind.conf.d ]] && cp -a /etc/systemd/logind.conf.d "$BACKUP"/ || true
log "Respaldo en ${BACKUP}"

# ---------------------------------------------------------------- 2. authselect
if authselect current >/dev/null 2>&1; then
  current="$(authselect current --raw)"
  for feat in with-faillock with-pwhistory; do
    grep -qw -- "$feat" <<<"$current" || authselect enable-feature "$feat"
  done
else
  authselect select "$PROFILE" with-faillock with-pwhistory --force
fi
authselect check || die "authselect check falló; revisa la configuración."
log "authselect: faillock y pwhistory activos ($(authselect current --raw))"

# ---------------------------------------------------------------- 3. Calidad de contraseñas (4.1 / 4.2)
mkdir -p /etc/security/pwquality.conf.d
cat > /etc/security/pwquality.conf.d/50-ebc.conf <<'EOF'
# Política de contraseñas EBC v1.0 - secciones 4.1 y 4.2
minlen = 15
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
maxrepeat = 3
maxsequence = 3
difok = 8
dictcheck = 1
usercheck = 1
gecoscheck = 1
enforce_for_root
badwords = ebc escuela bancaria comercial
EOF
log "pwquality: minlen=15, 4 clases, difok=8, badwords EBC"

# Historial de 10 contraseñas (4.1)
apply_block /etc/security/pwhistory.conf "remember|enforce_for_root|file|retry" \
"remember = 10
enforce_for_root"
log "pwhistory: remember=10"

# ---------------------------------------------------------------- 4. Sin caducidad por tiempo (Principio 7 / 4.3)
set_logindefs PASS_MAX_DAYS 99999
set_logindefs PASS_MIN_DAYS 0
set_logindefs PASS_WARN_AGE 7
awk -F: '($3==0 || $3>=1000) && $1!="nobody" {print $1}' /etc/passwd | xargs -r -n1 chage -M 99999
log "login.defs y cuentas existentes: sin caducidad periódica"

# ---------------------------------------------------------------- 5. Bloqueo por intentos (sección 6)
apply_block /etc/security/faillock.conf \
  "dir|deny|fail_interval|unlock_time|even_deny_root|root_unlock_time|audit" \
"dir = /var/run/faillock
deny = 5
fail_interval = 900
unlock_time = 900
even_deny_root
root_unlock_time = 900
audit"
log "faillock: 5 intentos, bloqueo de 15 min (incluye root)"

# ---------------------------------------------------------------- 6. Inactividad 5 min (5.1)
cat > /etc/profile.d/ebc-tmout.sh <<'EOF'
# Política EBC 5.1: cierre de sesión de shell tras 5 min de inactividad
readonly TMOUT=300
export TMOUT
EOF
chmod 644 /etc/profile.d/ebc-tmout.sh

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/50-ebc.conf <<'EOF'
[Login]
StopIdleSessionSec=300
EOF
log "TMOUT=300 y StopIdleSessionSec=300 (aplica en nuevos logins; logind: reinicio o 'systemctl restart systemd-logind')"

# ---------------------------------------------------------------- 7. SSH
SSHD_DROPIN="/etc/ssh/sshd_config.d/00-ebc-password-policy.conf"
if grep -Eqi '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/' /etc/ssh/sshd_config; then
  wheel_members="$(getent group wheel | cut -d: -f4 || true)"
  {
    echo "# Política de contraseñas EBC v1.0"
    echo "# Prefijo 00- para ganar sobre 01-permitrootlogin.conf (sshd usa el primer valor)"
    if [[ -n "$wheel_members" ]]; then
      echo "PermitRootLogin no"
    else
      warn "El grupo wheel no tiene miembros: NO se deshabilita root por SSH para evitar un lockout."
    fi
    cat <<'EOF'
PermitEmptyPasswords no
UsePAM yes
MaxAuthTries 3
LoginGraceTime 60
ClientAliveInterval 60
ClientAliveCountMax 3
EOF
  } > "$SSHD_DROPIN"
  if sshd -t; then
    systemctl reload sshd
    log "SSH endurecido (${SSHD_DROPIN})"
  else
    rm -f "$SSHD_DROPIN"
    die "sshd -t falló; se revirtió el drop-in de SSH."
  fi
else
  warn "sshd_config no incluye sshd_config.d/; se omite el drop-in de SSH."
fi

# ---------------------------------------------------------------- 8. fail2ban (bloqueo escalonado 15 min -> 1 h)
if [[ "$INSTALL_FAIL2BAN" == "yes" ]]; then
  if ! rpm -q fail2ban >/dev/null 2>&1; then
    dnf -y install fail2ban python3-systemd \
      || warn "No se pudo instalar fail2ban. En RHEL, epel-release NO está en los repos base: habilita CodeReady Builder e instala el RPM de EPEL 9 (o usa tu repo interno) y vuelve a correr el script."
  fi
  if rpm -q fail2ban >/dev/null 2>&1; then
    cat > /etc/fail2ban/jail.d/50-ebc.local <<EOF
[DEFAULT]
ignoreip = ${F2B_IGNOREIP}
maxretry = 5
findtime = 15m
bantime = 15m
bantime.increment = true
bantime.multipliers = 1 2 4
bantime.maxtime = 1h
backend = systemd

[sshd]
enabled = true
EOF
    systemctl enable --now fail2ban
    systemctl restart fail2ban
    log "fail2ban: sshd con bloqueo 15 min -> 30 min -> 1 h"
  fi
fi

# ---------------------------------------------------------------- 9. Auditoría (sección 8)
cat > /etc/audit/rules.d/50-ebc-identity.rules <<'EOF'
# Política EBC: registro de actividad de credenciales y recuperación
-w /etc/passwd -p wa -k ebc_identity
-w /etc/shadow -p wa -k ebc_identity
-w /etc/group -p wa -k ebc_identity
-w /etc/gshadow -p wa -k ebc_identity
-w /etc/security/opasswd -p wa -k ebc_identity
-w /etc/sudoers -p wa -k ebc_priv
-w /etc/sudoers.d/ -p wa -k ebc_priv
-w /run/faillock/ -p wa -k ebc_faillock
-w /etc/pam.d/ -p wa -k ebc_pam
-w /etc/security/ -p wa -k ebc_pam
-w /etc/ssh/sshd_config.d/ -p wa -k ebc_ssh
EOF
augenrules --load >/dev/null 2>&1 \
  || warn "augenrules no pudo cargar las reglas (¿auditd en modo inmutable -e 2?). Requiere reinicio."
log "Reglas de auditd cargadas"

# ---------------------------------------------------------------- 10. Aplicar cambios PAM y evidencia
authselect apply-changes >/dev/null
mkdir -p "$EVID_DIR"
{
  echo "=== Evidencia Política de contraseñas EBC v1.0 - $(hostname -f) - $(date -Is) ==="
  echo; echo "--- SO ---";            grep PRETTY_NAME /etc/os-release
  echo; echo "--- authselect ---";    authselect current
  echo; echo "--- pwquality ---";     cat /etc/security/pwquality.conf.d/50-ebc.conf
  echo; echo "--- pwhistory ---";     grep -vE '^\s*#|^\s*$' /etc/security/pwhistory.conf
  echo; echo "--- faillock ---";      grep -vE '^\s*#|^\s*$' /etc/security/faillock.conf
  echo; echo "--- PAM (system-auth) ---"
  grep -E 'pam_(pwquality|pwhistory|faillock)' /etc/pam.d/system-auth /etc/pam.d/password-auth
  echo; echo "--- login.defs ---";    grep -E '^(PASS_|ENCRYPT_METHOD)' /etc/login.defs
  echo; echo "--- TMOUT / logind ---"; cat /etc/profile.d/ebc-tmout.sh /etc/systemd/logind.conf.d/50-ebc.conf
  echo; echo "--- sshd (efectivo) ---"
  sshd -T 2>/dev/null | grep -E '^(permitrootlogin|permitemptypasswords|maxauthtries|logingracetime|clientaliveinterval|clientalivecountmax|usepam) '
  echo; echo "--- fail2ban ---";      fail2ban-client status sshd 2>&1 || echo "fail2ban no activo"
  echo; echo "--- auditd (reglas EBC) ---"; auditctl -l 2>/dev/null | grep -E 'ebc_' || true
  echo; echo "--- Caducidad de cuentas locales ---"
  awk -F: '($3==0 || $3>=1000) && $1!="nobody" {print $1}' /etc/passwd | while read -r u; do
    printf '%s: ' "$u"; chage -l "$u" | awk -F': ' '/Maximum/ {print "max_days=" $2}'
  done
} > "$EVID_FILE"
chmod 600 "$EVID_FILE"
log "Evidencia guardada en ${EVID_FILE}"

cat <<EOF

================ PENDIENTE / MANUAL ================
1. PRUEBA en otra terminal antes de cerrar tu sesión root:
     - Login por SSH con un usuario administrador (sudo).
     - Contraseña débil rechazada:  passwd <usuario_de_prueba>  (probar "Ebc2026!")
     - 5 intentos fallidos y luego:  faillock --user <usuario>
2. Contraseñas TEMPORALES / restablecimientos: fuerza el cambio con
     chage -d 0 <usuario>
3. MFA (sección 7): configurar por usuario (google-authenticator) o, mejor,
   centralizado (IdM/AD + Duo/Entra/RADIUS). Ver notas de la conversación.
4. Cuentas privilegiadas (20 caracteres): pwquality aplica un valor global (15).
   Usa una política por grupo en IdM/AD.
5. Contraseñas expuestas en filtraciones: no las valida PAM; 
6. Alertas de 3 intentos fallidos en sistemas críticos: reenviar /var/log/secure y
   auditd al SIEM y correlacionar allí.
7. Límite de 12 h en aplicaciones: se configura en cada aplicación.
8. Si usas OpenSCAP/CIS, hace falta un tailoring: CIS exige PASS_MAX_DAYS y
   otros valores que contradicen esta política.
====================================================
EOF
