# 🐧 FlyTux Optimizer v26.0
### *Sistema Cognitivo Cooperativo (Refined Edition)*

![Linux](https://img.shields.io/badge/OS-Debian_%7C_Ubuntu_%7C_Mint-FCC624?logo=linux&logoColor=black)
![Version](https://img.shields.io/badge/Version-26.0_Refined-blue)
![Shell](https://img.shields.io/badge/Shell-Bash_5.0+-4EAA25?logo=gnubash)
![License](https://img.shields.io/github/license/gridacorp/Flytux-Linux-Optimizer)

> Sistema de optimización adaptativa de nueva generación. Utiliza telemetría de hardware en tiempo real, puntuación ponderada y un daemon cognitivo para ajustar dinámicamente el rendimiento, la energía y la seguridad de tu sistema Linux.

---

## ⚠️ Advertencias Críticas (Leer antes de ejecutar)

> [!CAUTION]
> - **Requiere `sudo`**: Modifica configuraciones a nivel de kernel, systemd y red.
> - **NVIDIA + Secure Boot**: Si Secure Boot está activo, la instalación de drivers NVIDIA se omitirá automáticamente (requiere enrollamiento manual de claves MOK).
> - **Telemetría**: El script elimina paquetes de telemetría de Ubuntu/Debian (`popularity-contest`, `whoopsie`, `apport`).
> - **Solo Debian/Ubuntu**: Compatible nativamente con Debian 11/12, Ubuntu 20.04-24.04, Linux Mint, Pop!_OS y Zorin OS.

---

## ✨ Características Principales (Novedades v26.0)

### 🔍 1. Detección de Hardware de Precisión (Sin conjeturas)
- **CPU**: Lectura optimizada de `/proc/cpuinfo` y `lscpu -J`. Detecta generación exacta (Intel Core Ultra, AMD Zen 4/5), topología híbrida (P/E-Cores), SMT, NUMA, cachés y virtualización (VMX/SVM).
- **GPU**: Identificación por **Device ID** real (tabla ampliada con RTX 50xx/40xx, RX 7000, Intel Arc) para una puntuación precisa.
- **Almacenamiento**: Detección de NVMe/SSD/HDD y validación real de soporte TRIM vía `lsblk --discard`.

### 📊 2. FlyTux Score™ (Sistema de Puntuación Ponderado)
Evalúa tu hardware en una escala de **0 a 100 puntos** basada en 7 factores:
- **CPU** (hasta 35 pts): Núcleos, frecuencia máxima y topología híbrida.
- **RAM** (hasta 20 pts): Cantidad total de memoria.
- **GPU** (hasta 20 pts): Basado en Device ID específico (ej. RTX 4090 = 18 pts).
- **Disco** (10 pts), **Instrucciones** (5 pts), **Generación** (5 pts) y **Temperatura** (5 pts).

### 🧠 3. Daemon Cognitivo Cooperativo (`flytuxd`)
Un servicio en segundo plano que monitorea el sistema cada 30 segundos:
- **Modo Cooperativo**: Respeta gestores de energía existentes (Power Profiles Daemon, TLP) y solo actúa si es necesario.
- **Ajuste Dinámico**: Cambia automáticamente el `governor` de la CPU y el modo de la GPU (Integrated/On-Demand/NVIDIA) según si estás conectado a la corriente o con batería, y según la temperatura térmica en tiempo real.

### 🛡️ 4. Hardening y Seguridad Documentada
- **Systemd Hardening**: `ProtectSystem=strict`, `NoNewPrivileges=yes`, `MemoryDenyWriteExecute=yes` (con rutas de escritura explícitas documentadas para evitar fallos en distros antiguas).
- **Red**: UFW configurado con política *Deny Incoming / Allow Outgoing* y puertos vulnerables (135, 139, 445, 3389) bloqueados.
- **AppArmor**: Refuerzo de perfiles de Flatpak y Bubblewrap si están presentes.

### ⚡ 5. Instalación Modular y Optimizada
- Código refactorizado en **8 subfunciones** independientes de ~100 líneas.
- Consultas al sistema optimizadas con `awk` único (eliminando cadenas ineficientes de `grep | awk | cat`).
- Generación automática de un perfil de hardware en formato JSON (`/etc/flytux/hw.json`).

---

## 🚀 Instalación Rápida

```bash
git clone https://github.com/gridacorp/Flytux-Linux-Optimizer.git && \
cd Flytux-Linux-Optimizer && \
chmod +x "FlyTux Optimizer.sh" && \
sudo "./FlyTux Optimizer.sh" --install && \
sudo reboot
```

---

## 📋 Instalación Paso a Paso con Verificación

```bash
# ── Paso 1: Clonar repositorio ───────────────────────────────
git clone https://github.com/gridacorp/Flytux-Linux-Optimizer.git
cd Flytux-Linux-Optimizer

# ── Paso 2: Verificar integridad del script ──────────────────
ls -lh "FlyTux Optimizer.sh"
bash -n "FlyTux Optimizer.sh" && echo "✅ Sintaxis válida" || echo "❌ Error de sintaxis"

# ── Paso 3: Ejecutar instalación ─────────────────────────────
chmod +x "FlyTux Optimizer.sh"
sudo "./FlyTux Optimizer.sh" --install

# ── Paso 4: Reiniciar para activar el daemon y el kernel ─────
sudo reboot
```

---

## 🔍 Verificación Post-Instalación

Una vez reiniciado, verifica que el sistema cognitivo esté funcionando:

```bash
# 1. Verificar el FlyTux Score de tu hardware
flytux --score

# 2. Verificar que el daemon cognitivo está activo
systemctl status flytuxd.service

# 3. Consultar el perfil de hardware detectado (JSON)
cat /etc/flytux/hw.json | jq .  # (Instala 'jq' si quieres verlo formateado)

# 4. Verificar que UFW está activo y configurado
sudo ufw status verbose

# 5. Verificar el historial de telemetría local
tail -n 5 /var/lib/flytux/history/sys.log
```

---

## 🔙 Cómo Revertir Cambios (Rollback Seguro)

El script crea un backup completo de las configuraciones críticas antes de tocar nada.

```bash
# 1. Identificar el archivo de backup más reciente
ls -lh /var/backups/flytux-*.tar.gz

# 2. Restaurar las configuraciones de /etc (Reemplaza el nombre del archivo)
sudo tar xzf /var/backups/flytux-YYYY-MM-DD.tar.gz -C /

# 3. Limpiar servicios y configuraciones específicas de FlyTux
sudo systemctl disable --now flytuxd.service
sudo rm -f /etc/systemd/system/flytuxd.service /etc/systemd/system/flytux-battery.service
sudo rm -f /etc/udev/rules.d/99-flytux-power.rules
sudo rm -f /etc/sysctl.d/99-flytux.conf
sudo rm -rf /etc/flytux /var/lib/flytux

# 4. Resetear firewall a estado predeterminado
sudo ufw --force reset

# 5. Recargar systemd y reiniciar
sudo systemctl daemon-reload
sudo udevadm control --reload-rules
sudo reboot
```

---

## 🔄 Actualizar FlyTux Optimizer

Para obtener las últimas mejoras en la detección de hardware o nuevos perfiles:

```bash
cd ~/Flytux-Linux-Optimizer
git pull origin main
chmod +x "FlyTux Optimizer.sh"
sudo "./FlyTux Optimizer.sh" --install
sudo reboot
```

---

## 📁 Estructura del Repositorio

```text
Flytux-Linux-Optimizer/
├── FlyTux Optimizer.sh      # Script principal (v26.0 Refined Edition)
├── README.md                # Esta documentación
├── LICENSE                  # Licencia MIT
└── .github/                 # Configuración de GitHub (Issues, Workflows)
```

---

## 🤝 Contribuir

El desarrollo de detectores de hardware y perfiles de energía es una tarea comunitaria.

1. Haz un **Fork** del repositorio.
2. Crea una rama: `git checkout -b feature/nuevo-device-id-gpu`
3. Prueba los cambios en una **Máquina Virtual** o hardware de prueba.
4. Abre un **Pull Request** describiendo el hardware utilizado para las pruebas.

---

## 📄 Licencia

```text
MIT License - FlyTux Optimizer v26.0
Copyright (c) 2026 Gridacorp Contributors

Se concede permiso gratuito para usar, copiar, modificar, fusionar, publicar,
distribuir, sublicenciar y/o vender copias del Software.

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO.
```

---

## 🙏 Apoya el Proyecto

[![Donar con PayPal](https://www.paypalobjects.com/es_ES/ES/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=DMREEX4NSS7V4)

- 🐛 **Reporta bugs**: [Issues](https://github.com/gridacorp/Flytux-Linux-Optimizer/issues) *(Adjunta siempre tu `/var/log/flytux-*.log`)*
- 💡 **Sugiere mejoras**: [Discussions](https://github.com/gridacorp/Flytux-Linux-Optimizer/discussions)

---

<div align="center">

> 🐧 *"Haz que tu Linux vuele — inteligente, adaptativo y sin límites."*  
> **FlyTux Optimizer v26.0** — Hecho con ❤️ por Gridacorp para la comunidad Linux.

[![GitHub Stars](https://img.shields.io/github/stars/gridacorp/Flytux-Linux-Optimizer?style=flat)](https://github.com/gridacorp/Flytux-Linux-Optimizer/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/gridacorp/Flytux-Linux-Optimizer?style=flat)](https://github.com/gridacorp/Flytux-Linux-Optimizer/network/members)

</div>
```
te con las nuevas funciones del script.
