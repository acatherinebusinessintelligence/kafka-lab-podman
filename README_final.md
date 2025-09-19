# 🐧 Kafka Lab con Podman (WSL2 + Ubuntu 24.04)

![GitHub last commit](https://img.shields.io/github/last-commit/acatherinebusinessintelligence/kafka-lab-podman?color=blue)
![GitHub repo size](https://img.shields.io/github/repo-size/acatherinebusinessintelligence/kafka-lab-podman?color=success)
![GitHub license](https://img.shields.io/github/license/acatherinebusinessintelligence/kafka-lab-podman?color=yellow)

Laboratorio educativo para comprender y practicar con **Apache Kafka** en un clúster de **3 brokers + Zookeeper**, ejecutados en **Podman** sobre **WSL2 (Ubuntu 24.04)**.  
Incluye simulador visual, guía interactiva en HTML y script automatizado de demo.  
👉 Si no quieres usar el script, aquí tienes el **paso a paso manual**.

---

## 📂 Contenido del repositorio
- `podman-compose.yml` → Stack de **Kafka (3 brokers)** + **Zookeeper** en contenedores Podman.  
- `demo_kafka.sh` → Script de demo: crea tópico, produce/consume mensajes, simula fallos y recuperación.  
- `guia_kafka_podman_nav_fixed.html` → Guía paso a paso con navegación y botones (HTML interactivo).  
- `README.md` → Este documento de referencia.  
- `.gitignore` → Configuración para ignorar archivos innecesarios.  

---

## ✅ Requisitos previos
- Windows 11 con **WSL2** y **Ubuntu 24.04**
- **Podman** y **podman-compose** instalados
- Git configurado (nombre + correo)
- Navegador web para abrir la guía HTML

---

## 🚀 Instalación y uso

Clonar el repositorio:
```bash
git clone https://github.com/acatherinebusinessintelligence/kafka-lab-podman.git
cd kafka-lab-podman
```

Levantar el clúster:
```bash
podman-compose up -d
podman ps
# Debes ver: zookeeper (2181), kafka1 (9092), kafka2 (9093), kafka3 (9094)
```

---

## ▶️ Paso a paso manual (sin usar `demo_kafka.sh`)

### 1) Crear un tópico replicado (RF=3)
```bash
podman exec -it kafka1 bash -lc \
  'kafka-topics --create --topic demo --bootstrap-server kafka1:29092 --partitions 3 --replication-factor 3'
```
👉 Si ya existe, verás `TopicExistsException`. Continúa con el describe.

### 2) Describir el tópico
```bash
podman exec -it kafka1 bash -lc \
  'kafka-topics --describe --topic demo --bootstrap-server kafka1:29092'
```

### 3) Producir mensajes (terminal A)
```bash
podman exec -it kafka1 bash -lc \
  'kafka-console-producer --topic demo --bootstrap-server kafka1:29092'
```
Escribe:
```
hola
mensaje 2
mensaje 3
```
(Ctrl+C para salir).

### 4) Consumir mensajes (terminal B)
```bash
podman exec -it kafka2 bash -lc \
  'kafka-console-consumer --topic demo --bootstrap-server kafka2:29092 --from-beginning'
```

### 5) Simular caída de un broker
```bash
podman stop kafka3
```
Verifica cambios de líder/ISR:
```bash
podman exec -it kafka1 bash -lc \
  'kafka-topics --describe --topic demo --bootstrap-server kafka1:29092'
```

### 6) Producir más mensajes con un broker caído
```bash
podman exec -it kafka1 bash -lc \
  'kafka-console-producer --topic demo --bootstrap-server kafka1:29092'
```
Escribe:
```
con_kafka3_caido_1
con_kafka3_caido_2
```

### 7) Consumir mensajes con timeout (opcional)
```bash
podman exec -it kafka2 bash -lc \
  'kafka-console-consumer --topic demo --bootstrap-server kafka2:29092 --from-beginning --timeout-ms 5000 || true'
```

### 8) Recuperar broker
```bash
podman start kafka3
```
Verifica nuevamente:
```bash
podman exec -it kafka1 bash -lc \
  'kafka-topics --describe --topic demo --bootstrap-server kafka1:29092'
```

---

## 🧠 Conceptos clave
- **Brokers** → procesos Kafka que conforman el clúster.  
- **Particiones** → unidad de paralelismo de un tópico.  
- **Factor de replicación (RF)** → cuántas réplicas mantiene el clúster.  
- **Líder / ISR** → el líder atiende lecturas/escrituras; ISR = réplicas sincronizadas aptas para liderar.  
- **min.insync.replicas** → mínimo de ISR requerido para aceptar escritura y garantizar durabilidad.  

---

## 🔧 Comandos útiles
Limpiar si hay conflictos de puertos o contenedores previos:
```bash
podman stop -a && podman rm -a -f && podman pod rm -a -f
podman network prune -f && podman volume prune -f
```

Ver logs de un broker:
```bash
podman logs -f kafka1
```

Describir un tópico:
```bash
podman exec -it kafka1 bash -lc \
  'kafka-topics --describe --topic demo --bootstrap-server kafka1:29092'
```

---

## 📜 Licencia
Este proyecto se distribuye bajo licencia **MIT**.  
Ver archivo [LICENSE](LICENSE) para más detalles.

---

## 👩‍🏫 Autora
**Alejandra Montaña**  
💡 Consultora, docente y creadora de experiencias educativas con IA y tecnologías de nube.  
🌐 Comparte con propósito en la comunidad como *Dra Corazón IA*.

---

## ⚡ Anexo: Instalación desde PowerShell (Windows 11)

### 1️⃣ Verificar WSL
Abre **PowerShell como Administrador** y ejecuta:
```powershell
wsl --version
```

- Si ves error: *"El Subsistema de Windows para Linux no está instalado"*, instala con:
```powershell
wsl --install
```

Esto descargará e instalará **Ubuntu** (por defecto Ubuntu 24.04 LTS).

⚠️ Una vez completada la instalación, **solo necesitas ejecutar**:
```powershell
wsl
```
para abrir Ubuntu desde PowerShell.

Si tu versión es menor a `1.2.5`, actualiza:
```powershell
wsl --update
```

---

### 2️⃣ Configurar Ubuntu
Cuando abras Ubuntu por primera vez:
- Define tu **usuario** y **contraseña de Linux**.
- Luego actualiza paquetes:
```bash
sudo apt update && sudo apt upgrade -y
```

---

### 3️⃣ Instalar Podman en Ubuntu
Dentro de Ubuntu:
```bash
sudo apt install -y podman
podman --version
```

---

### 4️⃣ Instalar Podman Compose
También en Ubuntu:
```bash
sudo apt install -y podman-compose
podman-compose --version
```

---

### 5️⃣ Instalar Python y utilidades básicas
```bash
sudo apt install -y python3 python3-pip git curl wget unzip build-essential htop
```

---

### 6️⃣ Probar Podman
```bash
podman run --rm hello-world
```

👉 Debes ver el mensaje **"Hello from Docker!"**.

---

✅ Con esto ya tienes **WSL2 + Ubuntu + Podman + Compose + Python** listos.  
Ahora puedes continuar con el laboratorio Kafka descrito en este README.