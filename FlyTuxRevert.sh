#!/usr/bin/env bash
#=============================================================================
# 🚨 FlyTux Revert v1.0 - Botón de Pánico
# Desactiva FlyTux y restaura el sistema al estado anterior
# Uso: sudo bash flytux-revert.sh
#=============================================================================

set -Eeuo pipefail

# ═══════════════════════════════════════════════════════════════════════════
# COLORES Y HELPERS
# ═══════════════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}✅ $*${NC}"; }
info()  { echo -e "${BLUE}ℹ️  $*${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; }
fatal() { echo -e "${RED}💀 $*${NC}"; exit 1; }

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICACIONES INICIALES
# ═══════════════════════════════════════════════════════════════════════════

[ "$(id -u)" -ne 0 ] && fatal "Ejecutar con: sudo bash $0"

echo ""
echo "════════════════════════════════════════════════════════"
echo "🚨 FlyTux Revert v1.0 - Botón de Pánico"
echo "════════════════════════════════════════════════════════"
echo ""
info "Este script hará lo siguiente:"
echo "   1. Detener y desactivar los servicios de FlyTux"
echo "   2. Restaurar el backup más reciente de tu sistema"
echo "   3. Eliminar todos los archivos de FlyTux"
echo "   4. Recargar systemd y udev"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# BUSCAR BACKUP MÁS RECIENTE
# ═══════════════════════════════════════════════════════════════════════════

BKP_DIR="/var/backups"
BKP_FILE=$(ls -t "$BKP_DIR"/flytux-*.tar.gz 2>/dev/null | head -1)

if [ -z "$BKP_FILE" ]; then
  warn "No se encontró ningún backup de FlyTux en $BKP_DIR"
  warn "Continuando con la desinstalación manual..."
else
  info "Backup encontrado: $BKP_FILE"
  BKP_SIZE=$(du -h "$BKP_FILE" | cut -f1)
  BKP_DATE=$(stat -c %y "$BKP_FILE" | cut -d'.' -f1)
  info "Tamaño: $BKP_SIZE | Fecha: $BKP_DATE"
fi

echo ""
read -p "¿Continuar con la reversión? (s/N): " -n 1 -r
echo ""
[[ ! $REPLY =~ ^[Ss]$ ]] && { info "Operación cancelada."; exit 0; }

echo ""
echo "════════════════════════════════════════════════════════"
echo "🔄 Iniciando reversión..."
echo "════════════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# PASO 1: DETENER SERVICIOS
# ═══════════════════════════════════════════════════════════════════════════

info "[1/5] Deteniendo servicios de FlyTux..."

if systemctl is-active --quiet flytuxd 2>/dev/null; then
  systemctl stop flytuxd && log "flytuxd detenido" || warn "flytuxd no estaba activo"
fi

if systemctl is-active --quiet flytux-battery 2>/dev/null; then
  systemctl stop flytux-battery && log "flytux-battery detenido" || warn "flytux-battery no estaba activo"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 2: DESACTIVAR Y ELIMINAR SERVICIOS
# ═══════════════════════════════════════════════════════════════════════════

info "[2/5] Desactivando y eliminando servicios..."

if [ -f /etc/systemd/system/flytuxd.service ]; then
  systemctl disable flytuxd 2>/dev/null || true
  rm -f /etc/systemd/system/flytuxd.service
  log "flytuxd.service eliminado"
fi

if [ -f /etc/systemd/system/flytux-battery.service ]; then
  systemctl disable flytux-battery 2>/dev/null || true
  rm -f /etc/systemd/system/flytux-battery.service
  log "flytux-battery.service eliminado"
fi

if [ -f /etc/udev/rules.d/99-flytux-power.rules ]; then
  rm -f /etc/udev/rules.d/99-flytux-power.rules
  log "99-flytux-power.rules eliminado"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 3: RESTAURAR BACKUP
# ═══════════════════════════════════════════════════════════════════════════

if [ -n "$BKP_FILE" ] && [ -f "$BKP_FILE" ]; then
  info "[3/5] Restaurando backup: $BKP_FILE"
  if tar xzf "$BKP_FILE" -C / 2>/dev/null; then
    log "Backup restaurado correctamente"
  else
    error "Error al restaurar el backup. Continuando con la limpieza..."
  fi
else
  warn "[3/5] Sin backup para restaurar. Saltando..."
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 4: ELIMINAR ARCHIVOS DE FLYTUX
# ═══════════════════════════════════════════════════════════════════════════

info "[4/5] Eliminando archivos de FlyTux..."

# Binario
if [ -f /usr/local/bin/flytux ]; then
  rm -f /usr/local/bin/flytux
  log "/usr/local/bin/flytux eliminado"
fi

# Configuración
if [ -d /etc/flytux ]; then
  rm -rf /etc/flytux
  log "/etc/flytux eliminado"
fi

# Datos
if [ -d /var/lib/flytux ]; then
  rm -rf /var/lib/flytux
  log "/var/lib/flytux eliminado"
fi

# Logs
if ls /var/log/flytux-*.log 1> /dev/null 2>&1; then
  rm -f /var/log/flytux-*.log
  log "Logs de FlyTux eliminados"
fi

# ═══════════════════════════════════════════════════════════════════════════
# PASO 5: RECARGAR SERVICIOS
# ═══════════════════════════════════════════════════════════════════════════

info "[5/5] Recargando systemd y udev..."

systemctl daemon-reload && log "systemd recargado" || warn "Error al recargar systemd"
udevadm control --reload-rules && log "udev recargado" || warn "Error al recargar udev"
udevadm trigger && log "udev trigger ejecutado" || warn "Error en udev trigger"

# ═══════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════"
echo "✅ REVERSIÓN COMPLETADA"
echo "════════════════════════════════════════════════════════"
echo ""
echo "🗑️  FlyTux ha sido completamente desinstalado:"
echo "   • Servicios detenidos y eliminados"
if [ -n "$BKP_FILE" ] && [ -f "$BKP_FILE" ]; then
  echo "   • Sistema restaurado desde: $BKP_FILE"
else
  echo "   • Archivos de FlyTux eliminados"
fi
echo "   • Configuraciones recargadas"
echo ""
echo "💡 Recomendaciones:"
echo "   • Reinicia tu sistema para aplicar todos los cambios"
echo "   • Verifica que todo funcione correctamente después del reinicio"
echo ""
echo "📋 Comandos útiles post-reversión:"
echo "   • Verificar servicios: systemctl list-unit-files | grep flytux"
echo "   • Verificar archivos: ls /etc/flytux /var/lib/flytux 2>/dev/null"
echo ""

read -p "¿Reiniciar ahora? (s/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Ss]$ ]]; then
  info "Reiniciando en 5 segundos..."
  sleep 5
  reboot
else
  info "Reinicio cancelado. Puedes reiniciar manualmente cuando quieras."
fi

echo ""
echo "════════════════════════════════════════════════════════"
