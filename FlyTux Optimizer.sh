#!/usr/bin/env bash
#=============================================================================
# 🐧 FlyTux v26.3 - Enterprise Resilient Edition
#=============================================================================

set -Eeuo pipefail
shopt -s inherit_errexit 2>/dev/null || true

# Configuración Global
readonly FX="/etc/flytux"
readonly FV="/var/lib/flytux"
readonly LOG="/var/log/flytux-$(date +%F-%H%M).log"
readonly BKP="/var/backups/flytux-$(date +%F).tar.gz"

declare -a ERRORS=()
declare -a WARNINGS=()

# Helpers de Mensajería y Registro
log()   { echo "✅ $*"; logger -t flytux "$*"; }
info()  { echo "ℹ️  $*"; }
warn()  { echo "⚠️  $*" >&2; WARNINGS+=("$*"); logger -t flytux "WARN: $*"; }
error() { echo "❌ $*" >&2; ERRORS+=("$*"); logger -t flytux "ERROR: $*"; }
fatal() { echo "💀 $*" >&2; logger -t flytux "FATAL: $*"; exit 1; }

# Ejecución Defensiva
run() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        return 0
    else
        local rc=$?
        error "[$desc] falló (rc=$rc): $*"
        return $rc
    fi
}

run_visible() {
    local desc="$1"; shift
    if "$@"; then
        return 0
    else
        local rc=$?
        error "[$desc] falló (rc=$rc): $*"
        return $rc
    fi
}

pkg_exists() {
    apt-cache madison "$1" 2>/dev/null | grep -q '|' || return 1
}

safe_inst() {
    local desc="$1"; shift
    info "📦 $desc: $*"
    DEBIAN_FRONTEND=noninteractive run "inst:$desc" apt-get install -y \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" "$@" || warn "$desc: problemas durante la instalación"
}

svc_on() {
    local unit="$1"
    if systemctl list-unit-files "${unit}.service" "${unit}.timer" &>/dev/null; then
        run "svc_on:$unit" systemctl enable --now "$unit" || true
    fi
}

svc_off() {
    local unit="$1"
    if systemctl list-unit-files "${unit}.service" &>/dev/null; then
        run "svc_off:$unit" systemctl disable --now "$unit" || true
    fi
}

# Funciones de Serialización JSON
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    echo "$s"
}

json_write() {
    local file="$1"; shift
    local json="{"
    local first=true
    while [ $# -ge 2 ]; do
        local key="$1" val="$2"; shift 2
        $first || json+=","
        first=false
        if [[ "$val" == "true" || "$val" == "false" || "$val" =~ ^[0-9]+$ ]]; then
            json+="\"$key\":$val"
        else
            json+="\"$key\":\"$(json_escape "$val")\""
        fi
    done
    json+="}"
    echo "$json" > "$file"
}

# Inspección de Arquitectura y Hardware
read_cpuinfo() {
    CV="unknown"; CF="0"; CM="0"; CS="0"; CN="unknown"; FLG=""
    CPU_CUR_MHZ=0; CPU_PHYS_CORES=1; CPU_SIBLINGS=1; CPU_CACHE="unknown"; CPU_SOCKETS=1

    eval "$(awk -F: '
        /^vendor_id/ && !v {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CV=" tolower($2); v=1}
        /^cpu family/ && !f {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CF=" $2; f=1}
        /^model[ \t]*:/ && !m {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CM=" $2; m=1}
        /^stepping/ && !s {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CS=" $2; s=1}
        /^model name/ && !n {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CN=\"" $2 "\""; n=1}
        /^flags/ && !fl {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "FLG=\"" $2 "\""; fl=1}
        /^cpu MHz/ && !mhz {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CPU_CUR_MHZ=" int($2); mhz=1}
        /^cpu cores/ && !cores {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CPU_PHYS_CORES=" $2; cores=1}
        /^siblings/ && !sib {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CPU_SIBLINGS=" $2; sib=1}
        /^physical id/ && !pid {gsub(/^[ \t]+|[ \t]+$/, "", $2); SOCKETS[$2]=1}
        /^cache size/ && !cache {gsub(/^[ \t]+|[ \t]+$/, "", $2); print "CPU_CACHE=\"" $2 "\""; cache=1}
        END {
            print "CPU_SOCKETS=" (length(SOCKETS) ? length(SOCKETS) : 1)
        }
    ' /proc/cpuinfo 2>/dev/null || true)"

    CC=$(nproc 2>/dev/null || echo 1)
    AVX2=false; echo "$FLG" | grep -qw avx2 && AVX2=true
    AVX512=false; echo "$FLG" | grep -qw avx512f && AVX512=true

    SMT=false
    if [[ -n "${CPU_PHYS_CORES:-}" && -n "${CPU_SIBLINGS:-}" ]]; then
        if (( CPU_SIBLINGS > CPU_PHYS_CORES )); then
            SMT=true
        fi
    fi

    CPU_MAX_MHZ=2000
    CPU_MIN_MHZ=800
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq ]; then
        CPU_MAX_MHZ=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null || echo 2000000) / 1000 ))
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq ]; then
            CPU_MIN_MHZ=$(( $(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq 2>/dev/null || echo 800000) / 1000 ))
        fi
    fi

    HYB=false
    if ls /sys/devices/system/cpu/cpu*/cpu_capacity &>/dev/null; then
        local caps
        caps=$(cat /sys/devices/system/cpu/cpu*/cpu_capacity 2>/dev/null | sort -u | wc -l || echo 1)
        (( caps > 1 )) && HYB=true
    fi

    VIRT="none"
    if command -v systemd-detect-virt &>/dev/null; then
        VIRT=$(systemd-detect-virt 2>/dev/null || echo "none")
    fi

    NUMA_NODES=1
    if [ -d /sys/devices/system/node ]; then
        NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l || echo 1)
    fi
}

detect_cpu_generation() {
    CG="unknown"; TLE=100
    if [[ "$CV" == *"intel"* && "$CF" == "6" ]]; then
        case "$CM" in
            198) CG="ArrowLake-S"; TLE=105;; 185) CG="LunarLake"; TLE=105;; 183) CG="ArrowLake-H"; TLE=105;;
            173) CG="MeteorLake"; TLE=105;; 170|171) CG="RaptorLake-R"; TLE=100;; 167) CG="RocketLake"; TLE=100;;
            158|165) CG="RaptorLake"; TLE=100;; 151|154|155) CG="AlderLake"; TLE=100;; 140|141) CG="TigerLake"; TLE=100;;
            142) CG="KabyLake-R"; TLE=100;; 126) CG="CometLake-U"; TLE=100;; 125) CG="IceLake-Y"; TLE=100;;
            102) CG="CannonLake"; TLE=100;; 150) CG="AlderLake-N"; TLE=105;; 166) CG="CometLake-H"; TLE=100;;
            162) CG="CoffeeLake-R"; TLE=100;; 152) CG="CoffeeLake"; TLE=100;; 122) CG="GeminiLake"; TLE=105;;
            92) CG="ApolloLake"; TLE=105;; 78|94) CG="Skylake"; TLE=100;; 61|71) CG="Broadwell"; TLE=100;;
            60|69|70) CG="Haswell"; TLE=100;; 58) CG="IvyBridge"; TLE=105;; 42) CG="SandyBridge"; TLE=100;;
            37|44|53) CG="Westmere"; TLE=105;; 26|30|31|46) CG="Nehalem"; TLE=100;; 23|29) CG="Penryn"; TLE=105;;
            15) CG="Merom"; TLE=100;; *) CG="Intel-F6-M$CM";;
        esac
    elif [[ "$CV" == *"amd"* ]]; then
        case "$CF" in
            26) CG="Zen5"; TLE=95;;
            25)
                if (( CM >= 112 )); then CG="Zen4-Dragon"; TLE=95
                elif (( CM >= 96 )); then CG="Zen4-Phoenix"; TLE=95
                elif (( CM >= 80 )); then CG="Zen4-Raphael"; TLE=95
                elif (( CM >= 64 )); then CG="Zen3+-Rembrandt"; TLE=95
                elif (( CM >= 32 )); then CG="Zen3-Vermeer"; TLE=90
                elif (( CM >= 16 )); then CG="Zen3-Cezanne"; TLE=90
                else CG="Zen3"; TLE=90; fi;;
            23)
                if (( CM >= 112 )); then CG="Zen2-Vermeer"; TLE=95
                elif (( CM >= 96 )); then CG="Zen2-Matisse"; TLE=95
                elif (( CM >= 48 )); then CG="Zen2-Renoir"; TLE=95
                elif (( CM >= 16 )); then CG="Zen+-Picasso"; TLE=95
                else CG="Zen-Summit"; TLE=95; fi;;
            21) CG="Bulldozer/Piledriver"; TLE=90;; *) CG="AMD-F$CF";;
        esac
    fi
}

cache_lspci() {
    LSPCI_NN=$(lspci -nn 2>/dev/null || true)
    LSPCI_NNK=$(lspci -nnk 2>/dev/null || true)
}

detect_gpu() {
    GV=""; HI=false; HA=false; HN=false; GC=0; PD="unknown"; HYB_GPU=false
    if [[ -n "$LSPCI_NN" ]]; then
        echo "$LSPCI_NN" | grep -iE "vga|3d|display" | grep -q "\[8086:" && { GV+="intel,"; HI=true; ((GC++)); } || true
        echo "$LSPCI_NN" | grep -iE "vga|3d|display" | grep -q "\[1002:" && { GV+="amd,"; HA=true; ((GC++)); } || true
        echo "$LSPCI_NN" | grep -iE "vga|3d|display" | grep -q "\[10de:" && { GV+="nvidia,"; HN=true; ((GC++)); } || true
        (( GC > 1 )) && HYB_GPU=true
        PD=$(echo "$LSPCI_NNK" | grep -iE "vga compatible controller|3d controller" -A2 | grep "Kernel driver in use:" | awk '{print $4}' | head -n1 || echo "unknown")
        [[ -z "$PD" ]] && PD="unknown"
    fi
    GV="${GV%,}"; [[ -z "$GV" ]] && GV="unknown"
}

detect_storage() {
    DN=""; DT="hdd"; TRIM="false"
    eval "$(lsblk -ndo NAME,TYPE,ROTA,DISC-GRAN 2>/dev/null | awk '
        $2=="disk" && !found {
            print "DN=" $1
            print "DT=" ($3 == "0" ? ($1 ~ /nvme/ ? "nvme" : "ssd") : "hdd")
            print "TRIM=" ($4 != "0B" && $4 != "0" && $4 != "" ? "true" : "false")
            found=1
        }
    ' || true)"
    [[ -z "$DT" ]] && DT="hdd"
    [[ -z "$TRIM" ]] && TRIM="false"
}

detect_peripherals() {
    BT=false
    if lsusb 2>/dev/null | grep -qi bluetooth; then BT=true; fi
    if ! $BT && echo "$LSPCI_NN" | grep -qi bluetooth; then BT=true; fi
    MD=false
    if lsusb 2>/dev/null | grep -qiE "modem|lte|4g|5g"; then MD=true; fi
}

detect_system() {
    RAM=0; SWAP=0
    eval "$(awk '
        /^MemTotal:/ {print "RAM=" int($2/1024)}
        /^SwapTotal:/ {print "SWAP=" int($2/1024)}
    ' /proc/meminfo 2>/dev/null || true)"

    LAPTOP=false
    if ls /sys/class/power_supply/BAT* &>/dev/null; then LAPTOP=true; fi

    BOOT="bios"
    [ -d /sys/firmware/efi ] && BOOT="uefi"

    SB="off"
    if command -v mokutil &>/dev/null; then
        mokutil --sb-state 2>/dev/null | grep -qi "enabled" && SB="on" || true
    fi

    AU=$(logname 2>/dev/null || who | awk '{print $1; exit}' || echo "root")
    DE="${XDG_CURRENT_DESKTOP:-unknown}"
    DE=$(echo "$DE" | tr '[:upper:]' '[:lower:]')

    AM=""
    systemctl is-active -q power-profiles-daemon 2>/dev/null && AM+="ppd," || true
    systemctl is-active -q tlp 2>/dev/null && AM+="tlp," || true
    systemctl is-active -q thermald 2>/dev/null && AM+="thermald," || true
    AM="${AM%,}"; [[ -z "$AM" ]] && AM="none"
    FM=$([ "$AM" = "none" ] && echo "exclusive" || echo "cooperative")
}

# Gobernanza Energética y Térmica
thermal_get_temp() {
    local T=0
    for H in /sys/class/hwmon/hwmon*/temp1_input; do
        [ -f "$H" ] || continue
        local label
        label=$(cat "${H%temp1_input}/name" 2>/dev/null || true)
        case "$label" in coretemp*|k10temp*|cpu*|zen*|acpitz*) ;; *) continue;; esac
        local v
        v=$(cat "$H" 2>/dev/null || echo 0)
        v=$(( v / 1000 ))
        (( v > T )) && T=$v
    done
    echo "$T"
}

thermal_profile() {
    local t
    t=$(thermal_get_temp)
    local l=${TLE:-100}
    local p=$(( t * 100 / l ))
    if (( p < 75 )); then echo "performance"
    elif (( p < 88 )); then echo "balanced"
    else echo "powersave"; fi
}

cpu_set_governor() {
    local req="$1"
    local now
    now=$(date +%s)
    local sf="/var/lib/flytux/history/cpu-state"
    local last="" lc=0
    if [ -f "$sf" ]; then
        last=$(cut -d'|' -f1 "$sf" 2>/dev/null || true)
        lc=$(cut -d'|' -f2 "$sf" 2>/dev/null || echo 0)
    fi
    [[ "$last" == "$req" ]] && return 0
    (( now - lc < 30 )) && return 0

    local drv=""
    [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver ] && \
        drv=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || true)

    local gov="powersave"
    case "$drv" in
        intel_pstate|amd_pstate*)
            case "$req" in performance) gov="performance";; *) gov="powersave";; esac
            ;;
        *)
            case "$req" in performance) gov="performance";; balanced) gov="schedutil";; *) gov="powersave";; esac
            ;;
    esac

    if grep -qw "$gov" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
        for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
            [ -w "$g" ] && echo "$gov" > "$g" 2>/dev/null || true
        done
        mkdir -p /var/lib/flytux/history
        echo "${req}|${now}" > "$sf"
        logger -t flytux "Gobernador CPU configurado: $gov ($req) bajo driver $drv"
    fi
}

battery_get_source() {
    for p in /sys/class/power_supply/*/type; do
        [ -f "$p" ] || continue
        if grep -q "Mains" "$p" 2>/dev/null; then
            local online
            online=$(cat "${p%type}online" 2>/dev/null || echo 0)
            if [ "$online" = "1" ]; then
                echo "ac"
                return 0
            fi
        fi
    done
    echo "battery"
}

battery_apply_profile() {
    local src
    src=$(battery_get_source)
    local gov="balanced"
    [ "$src" = "battery" ] && gov="powersave"
    cpu_set_governor "$gov"
}

# Demonio de Supervisión
daemon_main() {
    local pf="/run/flytuxd.pid"
    local hd="/var/lib/flytux/history"
    local lock="/run/lock/flytuxd.lock"

    mkdir -p "$hd" /run/lock
    exec 9>"$lock"
    if ! flock -n 9; then
        logger -t flytuxd "Instancia de FlyTux ya activa."
        exit 0
    fi

    trap 'logger -t flytuxd "Daemon finalizado"; rm -f "$pf"; exit 0' SIGTERM SIGINT
    echo $$ > "$pf"

    [ -n "${NOTIFY_SOCKET:-}" ] && systemd-notify --ready 2>/dev/null || true

    local fm="cooperative"
    if [ -f "$FX/hw.json" ]; then
        fm=$(grep -o '"mode":"[^"]*"' "$FX/hw.json" 2>/dev/null | cut -d'"' -f4 || echo "cooperative")
    fi

    logger -t flytuxd "Daemon iniciado (PID $$, modo: $fm)"

    local last_ps=""
    local cy=0
    while true; do
        local ps
        ps=$(battery_get_source)
        if [[ "$ps" != "$last_ps" ]]; then
            battery_apply_profile
            last_ps="$ps"
        fi

        if [[ "$fm" == "exclusive" ]]; then
            local tp
            tp=$(thermal_profile)
            cpu_set_governor "$tp"
        fi

        ((cy++))
        if (( cy >= 4 )); then
            cy=0
            local temp
            temp=$(thermal_get_temp)
            local mem_avail
            mem_avail=$(awk '/MemAvailable/{printf "%d",$2/1024}' /proc/meminfo 2>/dev/null || echo 0)
            local load
            load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo "0.0")
            echo "$(date -Iseconds)|t=$temp|p=$ps|m=$mem_avail|l=$load" >> "$hd/sys.log"

            if [ -f "$hd/sys.log" ]; then
                local sz
                sz=$(stat -c%s "$hd/sys.log" 2>/dev/null || echo 0)
                if (( sz > 1048576 )); then
                    tail -n 1000 "$hd/sys.log" > "$hd/sys.log.tmp" && mv "$hd/sys.log.tmp" "$hd/sys.log"
                fi
            fi
        fi

        # Latido garantizado al Watchdog de Systemd
        [ -n "${NOTIFY_SOCKET:-}" ] && systemd-notify WATCHDOG=1 2>/dev/null || true
        sleep 15
    done
}

# Fases de Aprovisionamiento e Instalación
install_backup() {
    info "🔐 [1/11] Creando respaldo de configuraciones de sistema..."
    mkdir -p /var/backups
    tar czf "$BKP" \
        /etc/sysctl.d \
        /etc/systemd/system \
        /etc/udev/rules.d \
        /etc/default \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d \
        2>/dev/null || true
}

install_repos() {
    info "🔓 [2/11] Actualizando fuentes de repositorios..."
    if [[ "${ID:-}" =~ ubuntu|linuxmint|pop|zorin ]]; then
        if command -v add-apt-repository &>/dev/null; then
            add-apt-repository -y universe 2>/dev/null || true
            add-apt-repository -y restricted 2>/dev/null || true
            add-apt-repository -y multiverse 2>/dev/null || true
        fi
    fi
    DEBIAN_FRONTEND=noninteractive apt-get update -o Acquire::Retries=3 || warn "apt-get update finalizó con avisos"
}

install_detect() {
    info "🔍 [3/11] Analizando topología y dispositivos..."
    read_cpuinfo
    cache_lspci
    detect_cpu_generation
    detect_gpu
    detect_storage
    detect_peripherals
    detect_system

    info "CPU: $CV $CG (Cores: $CC, SMT: $SMT, Virtualización: $VIRT)"
    info "RAM: ${RAM} MB | Almacenamiento: $DT (TRIM: $TRIM) | Gráficos: $GV"
}

install_profile() {
    info "💾 [4/11] Registrando identificador y perfil de plataforma..."
    mkdir -p "$FX"
    local du mi uuid
    du=$(cat /sys/class/dmi/id/product_uuid 2>/dev/null || echo "none")
    mi=$(cat /etc/machine-id 2>/dev/null || echo "none")
    uuid=$(echo -n "$du-$mi" | sha256sum | cut -c1-32 | sed 's/\(........\)\(....\)\(....\)\(....\)\(.*\)/\1-\2-4\3-8\4-\5/')

    json_write "$FX/hw.json" \
        v "26.3" uuid "$uuid" \
        cpu_vendor "$CV" cpu_gen "$CG" cpu_family "$CF" cpu_model "$CM" \
        cpu_cores "$CC" cpu_smt "$SMT" numa_nodes "$NUMA_NODES" \
        ram "$RAM" disk "$DT" trim "$TRIM" gpu "$GV" hyb_gpu "$HYB_GPU" \
        laptop "$LAPTOP" bt "$BT" modem "$MD" sb "$SB" de "$DE" mode "$FM"
}

install_daemon() {
    info "🤖 [5/11] Configurando servicio supervisado en systemd..."
    cp "$0" /usr/local/bin/flytux
    chmod 755 /usr/local/bin/flytux

    cat > /etc/systemd/system/flytuxd.service <<EOF
[Unit]
Description=FlyTux Enterprise Cooperative Daemon
After=multi-user.target
Wants=network.target

[Service]
Type=notify
WatchdogSec=60
ExecStart=/usr/local/bin/flytux --daemon
Restart=on-failure
RestartSec=15

ProtectSystem=full
ProtectHome=yes
PrivateTmp=yes
NoNewPrivileges=yes
ProtectControlGroups=yes
RestrictRealtime=yes
ReadWritePaths=/var/lib/flytux /etc/flytux /run /sys/devices/system/cpu

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    svc_on flytuxd
}

install_kernel() {
    info "⚙️  [6/11] Ajustando parámetros del subsistema de red del kernel..."
    cat > /etc/sysctl.d/99-flytux.conf <<EOF
net.core.somaxconn = 4096
net.ipv4.tcp_fastopen = 3
net.core.netdev_max_backlog = 4096
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
vm.vfs_cache_pressure = 50
EOF

    if sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qw bbr; then
        echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.d/99-flytux.conf
    fi

    sysctl -p /etc/sysctl.d/99-flytux.conf 2>/dev/null || true
}

install_memory() {
    info "⚡ [7/11] Configurando compresión de páginas e intercambio en memoria..."
    if (( RAM <= 8192 )); then
        # Desactivación preventiva de Zswap para impedir compresión redundante en CPU
        if [ -w /sys/module/zswap/parameters/enabled ]; then
            echo 0 > /sys/module/zswap/parameters/enabled 2>/dev/null || true
        fi

        if pkg_exists systemd-zram-generator; then
            safe_inst "ZRAM Generator" systemd-zram-generator
            cat > /etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
EOF
            systemctl daemon-reload
            systemctl restart /dev/zram0 2>/dev/null || true
        fi

        safe_inst "EarlyOOM" earlyoom
        if [ -f /etc/default/earlyoom ]; then
            # Umbrales conservadores de seguridad y lista explícita de exclusión de procesos vitales
            cat > /etc/default/earlyoom <<EOF
EARLYOOM_ARGS="-m 5 -s 5 --avoid '^(Xorg|gnome-shell|kwin_wayland|plasmashell|cinnamon|lightdm|gdm3|sshd|firefox|chrome)$'"
EOF
            systemctl restart earlyoom 2>/dev/null || true
        fi
    fi
}

install_power() {
    info "🌡️  [8/11] Armonizando perfiles de consumo energético..."
    if $LAPTOP; then
        [[ "$CV" == *"intel"* ]] && safe_inst "Thermald" thermald
        if [[ ! "${ID:-}" =~ debian ]]; then
            safe_inst "PPD" power-profiles-daemon
            svc_on power-profiles-daemon
        else
            if ! systemctl is-active -q power-profiles-daemon 2>/dev/null; then
                safe_inst "TLP" tlp
                svc_on tlp
            fi
        fi
    fi
}

install_drivers() {
    info "🏭 [9/11] Desplegando controladores y aceleración de hardware..."
    [[ "$CV" == *"intel"* ]] && safe_inst "Intel Microcode" intel-microcode
    [[ "$CV" == *"amd"* ]] && safe_inst "AMD Microcode" amd64-microcode

    $HI && safe_inst "Intel Media" intel-media-driver mesa-va-drivers mesa-vulkan-drivers
    $HA && safe_inst "AMD Vulkan" mesa-vulkan-drivers mesa-va-drivers

    # Configuración estática y segura para gráficos híbridos (Offload / On-Demand)
    if $HN; then
        if [[ "$SB" == "on" ]]; then
            warn "Secure Boot activo. Se omite el controlador privativo para evitar rechazo de módulos sin firmar."
        else
            safe_inst "NVIDIA Driver" nvidia-driver nvidia-prime
            if $HYB_GPU && command -v prime-select &>/dev/null; then
                prime-select on-demand 2>/dev/null || true
            fi
        fi
    fi

    $TRIM && svc_on fstrim.timer
    $MD || svc_off ModemManager
}

install_security() {
    info "🛡️  [10/11] Aplicando directivas de protección y cortafuegos..."
    if command -v ufw &>/dev/null; then
        run "ufw-default-in" ufw default deny incoming
        run "ufw-default-out" ufw default allow outgoing
        # Apertura de seguridad incondicional para evitar el bloqueo remoto de SSH
        run "ufw-allow-ssh" ufw allow 22/tcp
        run "ufw-enable" ufw --force enable
        svc_on ufw
    fi

    # Eliminación conservadora sin tocar paquetes que arrastren dependencias de escritorio
    for p in popularity-contest; do
        if dpkg -l "$p" &>/dev/null; then
            DEBIAN_FRONTEND=noninteractive apt-get remove -y "$p" 2>/dev/null || true
        fi
    done
}

install_cleanup() {
    info "🧹 [11/11] Depuración de paquetes huérfanos y registros de auditoría..."
    DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null || true
    DEBIAN_FRONTEND=noninteractive apt-get clean 2>/dev/null || true
    journalctl --vacuum-size=150M --vacuum-time=14d &>/dev/null || true
}

install_flytux() {
    echo "🐧 Iniciando instalación de FlyTux v26.3..."
    [ "$(id -u)" -ne 0 ] && fatal "El script requiere privilegios administrativos de superusuario (sudo)."

    if [ -f /etc/os-release ]; then
        . /etc/os-release
    else
        fatal "No se detectó el archivo estándar de distribución /etc/os-release."
    fi

    exec > >(tee -a "$LOG") 2>&1

    install_backup
    install_repos
    install_detect
    install_profile
    install_daemon
    install_kernel
    install_memory
    install_power
    install_drivers
    install_security
    install_cleanup

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "✅ FlyTux v26.3 DESPLEGADO EXITOSAMENTE"
    echo "════════════════════════════════════════════════════════"
    echo "Microarquitectura: $CV $CG | Cores: $CC | Memoria: ${RAM} MB"
    echo "Topología Gráfica: $GV | Confinamiento: Cooperativo ($FM)"
    echo "Registro del despliegue: $LOG"
    echo "════════════════════════════════════════════════════════"
}

# Entrada Principal
case "${1:-}" in
    --daemon)
        read_cpuinfo
        detect_cpu_generation
        detect_system
        daemon_main
        ;;
    --battery-apply)
        battery_apply_profile
        ;;
    --install|"")
        install_flytux
        ;;
    *)
        echo "Uso: $0 [--daemon|--battery-apply|--install]"
        exit 1
        ;;
esac
