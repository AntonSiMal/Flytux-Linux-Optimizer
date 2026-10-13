# 🐧 FlyTux Linux Optimizer

> **Sistema Cognitivo Cooperativo de Optimización para Linux (Safe Edition v26.2)**

FlyTux es un script avanzado de optimización, hardening y gestión de energía para sistemas Linux basados en Debian/Ubuntu. Diseñado para ser **inteligente, seguro y 100% reversible**, analiza tu hardware en tiempo real y aplica configuraciones óptimas sin romper tu sistema.

[![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Linux](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
[![Debian/Ubuntu](https://img.shields.io/badge/Debian%2FUbuntu-A81D33?style=for-the-badge&logo=debian&logoColor=white)](https://www.debian.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

---

## ⚠️ Aviso de Seguridad Importante

- **Compatibilidad:** Diseñado exclusivamente para derivados de **Debian/Ubuntu** (Ubuntu, Linux Mint, Pop!_OS, Zorin OS, Debian).
- **Seguridad:** El script **NO** toca el gestor de arranque (GRUB), **NO** desinstala el kernel y **RESPETA** servicios esenciales como Bluetooth e Impresoras (CUPS).
- **Reversible:** Antes de cualquier cambio, crea un backup automático en `/var/backups/`. Incluye un script de reversión de 1 clic.
- **Ejecuta bajo tu propio riesgo.** Si no estás seguro, usa primero el modo `--score` (solo lectura).

---

## ✨ Características Principales

### 🧠 Detección Inteligente de Hardware
- Perfil completo de CPU (Vendor, Family, Model, Stepping, SMT, NUMA, Caché, Virtualización).
- Detección precisa de GPU (Intel, AMD, NVIDIA) con tabla de Device IDs para puntuación.
- Identificación de almacenamiento (NVMe, SSD, HDD) y estado TRIM.

### ⚡ Rendimiento y Energía
- **Gobernadores de CPU dinámicos:** Cambia entre `performance`, `balanced` y `powersave` según la temperatura y la fuente de energía.
- **Gestión de Memoria:** Instalación automática de ZRAM, EarlyOOM y Preload en sistemas con ≤8GB de RAM.
- **Modo Cooperativo:** Trabaja en armonía con `power-profiles-daemon` o `TLP` sin entrar en conflicto.

### 🎮 Optimización de Gráficos
- Instalación selectiva de microcódigo (`intel-microcode`, `amd64-microcode`).
- Drivers de aceleración por hardware (VA-API, Vulkan) para Intel y AMD.
- Soporte para conmutación híbrida (NVIDIA Optimus) vía `prime-select` o `envycontrol`.

### 🛡️ Seguridad y Privacidad
- Configuración automática de **UFW** (Firewall) con reglas seguras por defecto.
- Eliminación de paquetes de telemetría (popularity-contest, whoopsie, apport, ubuntu-report).
- Hardening de AppArmor para contenedores (Flatpak/Bubblewrap).

### 🔄 100% Reversible
- Backup automático de configuraciones críticas antes de iniciar.
- Script dedicado `flytux-revert.sh` para restaurar el sistema a su estado original en segundos.

---

## 🚀 Instalación Rápida

### Método 1: Descarga directa (Recomendado)
```bash
# 1. Descarga el script principal
curl -sL https://raw.githubusercontent.com/AntonSiMal/Flytux-Linux-Optimizer/main/flytux.sh -o flytux.sh

# 2. Dale permisos de ejecución
chmod +x flytux.sh

# 3. (Opcional pero recomendado) Prueba el modo solo-lectura primero
sudo ./flytux.sh --score

# 4. Ejecuta la instalación
sudo ./flytux.sh --install
```

### Método 2: Clonar el repositorio
```bash
git clone https://github.com/AntonSiMal/Flytux-Linux-Optimizer.git
cd Flytux-Linux-Optimizer
chmod +x flytux.sh flytux-revert.sh
sudo ./flytux.sh --install
```

---

## ⚙️ Uso y Comandos

| Comando | Descripción |
| :--- | :--- |
| `sudo ./flytux.sh` o `--install` | Ejecuta el proceso completo de optimización (12 pasos). |
| `sudo ./flytux.sh --score` | **Modo seguro:** Analiza tu hardware y muestra tu "FlyTux Score" sin cambiar nada. |
| `sudo ./flytux.sh --daemon` | Inicia el daemon en segundo plano (gestionado por systemd). |
| `sudo ./flytux.sh --battery-apply` | Aplica manualmente el perfil de ahorro de energía (CPU + GPU). |

---

## 📊 El "FlyTux Score"

El script evalúa tu sistema sobre **100 puntos** basándose en:
- **CPU (35 pts):** Núcleos, frecuencia máxima y arquitectura híbrida.
- **RAM (20 pts):** Cantidad de memoria disponible.
- **GPU (20 pts):** Generación y modelo de la tarjeta gráfica.
- **Disco (10 pts):** Tipo de almacenamiento (NVMe = 10, SSD = 6, HDD = 0).
- **Instrucciones (5 pts):** Soporte AVX2 / AVX-512.
- **Generación (5 pts):** Antigüedad y eficiencia de la arquitectura (ej. Zen 5, Raptor Lake).
- **Temperatura (5 pts):** Estado térmico actual del sistema.

---

## 🚨 ¿Cómo Revertir los Cambios? (Botón de Pánico)

Si algo no funciona como esperas, FlyTux incluye un script de reversión que restaura tu sistema al estado exacto anterior a la instalación.

```bash
# 1. Descarga el script de reversión (si no lo clonaste)
curl -sL https://raw.githubusercontent.com/AntonSiMal/Flytux-Linux-Optimizer/main/flytux-revert.sh -o flytux-revert.sh
chmod +x flytux-revert.sh

# 2. Ejecútalo con sudo
sudo ./flytux-revert.sh
```
*Este script detendrá los servicios, restaurará el backup de `/var/backups/`, eliminará los archivos de FlyTux y recargará systemd/udev.*

---

## 📁 Archivos Generados

- `/etc/flytux/hw.json`: Perfil de hardware detectado en formato JSON.
- `/var/lib/flytux/history/`: Historial de cambios de estado (gobernador, temperatura, batería).
- `/var/log/flytux-AAAA-MM-DD.log`: Registro detallado de la instalación.
- `/var/backups/flytux-AAAA-MM-DD.tar.gz`: **Tu copia de seguridad.** ¡No la borres!

---

## 🤝 Contribuir

Las contribuciones son bienvenidas. Si encuentras un bug, tienes una sugerencia de optimización o deseas agregar soporte para una nueva generación de hardware:
1. Haz un Fork del repositorio.
2. Crea una rama para tu característica (`git checkout -b feature/nueva-funcion`).
3. Haz Commit de tus cambios (`git commit -m 'Añadir soporte para XYZ'`).
4. Haz Push a la rama y abre un Pull Request.

---

## 📜 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

> **Nota:** FlyTux es una herramienta de automatización. El autor no se hace responsable de daños indirectos. Siempre revisa el código antes de ejecutar scripts con privilegios de root.

---
*Hecho con ❤️ y mucho ☕ para la comunidad Linux.*
```
