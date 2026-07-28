# 🐧 FlyTux Optimizer v15.1
### *Edición "Fuentes Estables + Detección Robusta"*

![Linux](https://img.shields.io/badge/OS-Debian_%7C_Ubuntu_%7C_Mint-FCC624?logo=linux&logoColor=black)
![Version](https://img.shields.io/badge/Version-15.1-blue)
![Shell](https://img.shields.io/badge/Shell-Bash_5.0+-4EAA25?logo=gnubash)
![License](https://img.shields.io/github/license/gridacorp/Flytux-Linux-Optimizer)

> Script de optimización adaptativa profesional para sistemas basados en Debian/Ubuntu. Utiliza detección de hardware de nivel superior (`/sys`, `/proc`, `dmidecode`, tablas de modelos) para aplicar ajustes seguros, estables y personalizados a tu sistema.

---

## ⚠️ Advertencias Críticas (Leer antes de ejecutar)

> [!CAUTION]
> - **Requiere `sudo`**: Este script modifica archivos del sistema. Debe ejecutarse como root.
> - **Desinstalación de Software**: Por defecto, el script **elimina Firefox y LibreOffice** para liberar recursos. Si deseas conservarlos, edita la sección `[9/12]` del script antes de ejecutarlo.
> - **Reinicio Obligatorio**: Los cambios de kernel, microcódigo, drivers y ZRAM requieren un reinicio para surtir efecto.
> - **Solo Debian/Ubuntu**: El script se detendrá automáticamente si detecta Arch, Fedora u otras distribuciones no compatibles.

---

## ✨ Características Principales

### 🔍 1. Detección de Hardware Robusta y Precisa
A diferencia de otros optimizadores, FlyTux no adivina. Consulta fuentes directas del kernel y tablas oficiales:
- **CPU**: Detección de vendor, generación exacta (Intel 12th-14th Gen, AMD Zen 2-5), instrucciones (AVX2/AVX512) y topología híbrida (P-Cores / E-Cores).
- **Almacenamiento**: Identifica HDD, SSD SATA o NVMe, y verifica el soporte real de TRIM vía `lsblk --discard`.
- **GPU**: Detección multinivel (`glxinfo` → `vulkaninfo` → DRM → `lspci`) para identificar el controlador primario en uso.
- **Otros**: RAM ECC, modo de arranque (BIOS/UEFI), estado de Secure Boot y factor de forma (Laptop/Desktop).

### 📊 2. Motor de Perfiles Adaptativos
El script no aplica una receta única. Calcula un perfil basado en tu RAM y tipo de disco:

| Nivel de RAM | Tipo de Disco | Acciones Automáticas |
| :--- | :--- | :--- |
| **≤ 4GB (Low)** | HDD | ZRAM (50%), EarlyOOM, Preload (agresivo) |
| **≤ 4GB (Low)** | SSD/NVMe | ZRAM (50%), EarlyOOM |
| **≤ 8GB (Mid)** | HDD | ZRAM, EarlyOOM, Preload |
| **≤ 8GB (Mid)** | SSD/NVMe | ZRAM, EarlyOOM (si no hay Swap) |
| **> 8GB (High+)** | Cualquiera | EarlyOOM (solo si no hay Swap). Gestión de memoria delegada al kernel. |

### 🛡️ 3. Seguridad y Estabilidad Primero
- **Backup Automático**: Crea un archivo `.tar.gz` de `/etc` (sysctl, systemd, apt, modprobe) en `/var/backups/` antes de cualquier cambio.
- **Sysctl No Intrusivo**: Solo optimiza la red (TCP BBR, Fast Open, buffers). **No** toca parámetros de memoria del kernel, evitando inestabilidad.
- **Validación de Servicios**: Solo habilita servicios (`systemctl enable`) si el archivo `.service` existe físicamente en el sistema.

### 🏭 4. Motor de Drivers Inteligente
- Instala el **microcódigo** correcto (Intel/AMD) si falta.
- **NVIDIA**: Usa `ubuntu-drivers` para instalar la versión *recomendada*, no la más reciente (evita roturas).
- **AMD**: Instala el stack open-source completo (Mesa, Vulkan, VA-API, VDPAU). *Nunca instala AMDGPU-PRO*.
- **Intel**: Instala los drivers de media no-libres para aceleración de video por hardware.

---

## 🚀 Instalación Rápida

```bash
git clone https://github.com/gridacorp/Flytux-Linux-Optimizer.git && \
cd Flytux-Linux-Optimizer && \
chmod +x "FlyTux Optimizer.sh" && \
sudo "./FlyTux Optimizer.sh" && \
sudo reboot
```

---

## 📋 Instalación Paso a Paso con Verificación

Si prefieres tener control total sobre el proceso, sigue estos pasos:

```bash
# ── Paso 1: Clonar repositorio ───────────────────────────────
git clone https://github.com/gridacorp/Flytux-Linux-Optimizer.git
cd Flytux-Linux-Optimizer

# ── Paso 2: Verificar integridad del script (Recomendado) ────
# Verificar que el script existe y tiene tamaño razonable (~30-50KB)
ls -lh "FlyTux Optimizer.sh"

# Verificar sintaxis bash sin ejecutar
bash -n "FlyTux Optimizer.sh" && echo "✅ Sintaxis válida" || echo "❌ Error de sintaxis"

# ── Paso 3: Ejecutar ─────────────────────────────────────────
chmod +x "FlyTux Optimizer.sh"
sudo "./FlyTux Optimizer.sh"

# ── Paso 4: Reiniciar ────────────────────────────────────────
sudo reboot
```

---

## 🔍 Verificación Post-Instalación

Una vez reiniciado, puedes verificar que todo se aplicó correctamente:

```bash
# 1. Verificar que el script se ejecutó hasta el final
grep "COMPLETADO" /var/log/flytux-*.log | tail -n 1

# 2. Verificar el perfil de hardware que se te aplicó
grep "Perfil:" /var/log/flytux-*.log | tail -n 1

# 3. Verificar servicios y configuraciones clave
systemctl is-enabled earlyoom.service      # Debería decir "enabled"
systemctl is-enabled fstrim.timer          # Debería decir "enabled" (si es SSD/NVMe)
wine --version 2>/dev/null || echo "ℹ️ Wine: verificar instalación"
protonvpn status 2>/dev/null || echo "ℹ️ ProtonVPN: requiere login manual"
```

---

## 🔙 Cómo Revertir Cambios (Rollback)

Si algo no funciona como esperas, el script crea un backup de tus archivos de configuración.

```bash
# 1. Identificar y restaurar el backup automático
ls -lh /var/backups/flytux-etc-*.tar.gz
sudo tar xzf /var/backups/flytux-etc-YYYY-MM-DD.tar.gz -C /  # Reemplaza con la fecha real

# 2. Limpiar configuraciones específicas de FlyTux
sudo rm -f /etc/sysctl.d/99-flytux.conf
sudo rm -f /etc/modprobe.d/*flytux*.conf
sudo rm -f /etc/default/earlyoom

# 3. Desactivar servicios añadidos
sudo systemctl disable earlyoom.service
sudo systemctl disable preload.service

# 4. Restaurar GRUB (si se modificó) y reiniciar
sudo update-grub && sudo reboot
```

---

## 🔄 Actualizar FlyTux Optimizer

Si ya tienes el repositorio clonado y quieres aplicar las últimas mejoras:

```bash
cd ~/Flytux-Linux-Optimizer
git pull origin main
chmod +x "FlyTux Optimizer.sh"
sudo "./FlyTux Optimizer.sh"
sudo reboot
```

---

## 📁 Estructura del Repositorio

```text
Flytux-Linux-Optimizer/
├── FlyTux Optimizer.sh      # Script principal de optimización (v15.1)
├── README.md                # Esta documentación completa
├── LICENSE                  # Licencia MIT
└── .github/                 # Configuración de GitHub (issues, workflows)
```

---

## 🤝 Contribuir

¡Las contribuciones son bienvenidas! Sigue estos pasos:

1. Haz un **Fork** del repositorio.
2. Clona tu fork: `git clone https://github.com/TU_USUARIO/Flytux-Linux-Optimizer.git`
3. Crea una rama para tu mejora: `git checkout -b feature/tu-mejora`
4. Prueba el script en una **Máquina Virtual** (VirtualBox/KVM) antes de subir cambios.
5. Haz commit y push: 
   ```bash
   git commit -m "feat: descripción clara de tu mejora"
   git push origin feature/tu-mejora
   ```
6. Abre un **Pull Request** en GitHub describiendo los cambios.

---

## 📄 Licencia

```text
MIT License - FlyTux Optimizer v15.1
Copyright (c) 2026 Gridacorp Contributors

Se concede permiso gratuito para usar, copiar, modificar, fusionar, publicar,
distribuir, sublicenciar y/o vender copias del Software.

EL SOFTWARE SE PROPORCIONA "TAL CUAL", SIN GARANTÍA DE NINGÚN TIPO. 
El uso de este script es bajo tu propia responsabilidad.
```

---

## 🙏 Apoya el Proyecto

[![Donar con PayPal](https://www.paypalobjects.com/es_ES/ES/i/btn/btn_donateCC_LG.gif)](https://www.paypal.com/donate/?hosted_button_id=DMREEX4NSS7V4)

- 🐛 **Reporta bugs**: [Issues](https://github.com/gridacorp/Flytux-Linux-Optimizer/issues) *(Adjunta tu log de `/var/log/flytux-*.log`)*
- 💡 **Sugiere mejoras**: [Discussions](https://github.com/gridacorp/Flytux-Linux-Optimizer/discussions)
- 📝 **Mejora la documentación**: Envía un Pull Request

---

<div align="center">

> 🐧 *"Haz que tu Linux vuele — seguro, compatible y sin límites."*  
> **FlyTux Optimizer v15.1** — Hecho con ❤️ por Gridacorp para la comunidad Linux.

[![GitHub Stars](https://img.shields.io/github/stars/gridacorp/Flytux-Linux-Optimizer?style=flat)](https://github.com/gridacorp/Flytux-Linux-Optimizer/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/gridacorp/Flytux-Linux-Optimizer?style=flat)](https://github.com/gridacorp/Flytux-Linux-Optimizer/network/members)

</div>
```
