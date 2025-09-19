#!/usr/bin/env bash
# demo_kafka.sh — Demo guiada de Kafka (3 brokers) sobre Podman
# Autor: Alejandra Montaña (para estudiantes)
# Uso: ./demo_kafka.sh [--external]
#  - por defecto usa listeners INTERNOS (kafkaN:29092) desde dentro de contenedores
#  - con --external probará vía localhost:9092 desde dentro del contenedor (útil para comparar)

set -euo pipefail

TOPIC="${TOPIC:-demo}"
PARTS="${PARTS:-3}"
RF="${RF:-3}"
BROKERS=(kafka1 kafka2 kafka3)
INTERNAL_PORT=29092
EXTERNAL_PORTS=(9092 9093 9094)

USE_EXTERNAL=0
if [[ "${1:-}" == "--external" ]]; then
  USE_EXTERNAL=1
fi

blue(){ printf "\033[34m%s\033[0m\n" "$*"; }
green(){ printf "\033[32m%s\033[0m\n" "$*"; }
yellow(){ printf "\033[33m%s\033[0m\n" "$*"; }
red(){ printf "\033[31m%s\033[0m\n" "$*"; }
h1(){ echo; blue "==================== $* ===================="; }
h2(){ yellow "---- $* ----"; }

require_cmd(){ command -v "$1" >/dev/null 2>&1 || { red "Falta comando: $1"; exit 1; }; }

require_cmd podman

# Verificar contenedores
for b in "${BROKERS[@]}"; do
  if ! podman inspect "$b" >/dev/null 2>&1; then
    red "No se encuentra el contenedor $b. Levanta el clúster con: podman-compose up -d"
    exit 1
  fi
done

# Helper para ejecutar en contenedor
in_c(){
  local c="$1"; shift
  podman exec -i "$c" bash -lc "$*"
}

# Esperar a que cada broker responda
wait_broker(){
  local c="$1" host="$2" port="$3" tries=30
  until in_c "$c" "kafka-broker-api-versions --bootstrap-server ${host}:${port} >/dev/null 2>&1"; do
    ((tries--)) || { red "Timeout esperando broker ${c} (${host}:${port})"; return 1; }
    sleep 1
  done
  return 0
}

h1 "Esperando brokers"
if [[ $USE_EXTERNAL -eq 1 ]]; then
  # Probamos que los puertos externos estén abiertos desde *dentro* del contenedor
  for i in "${!BROKERS[@]}"; do
    b="${BROKERS[$i]}"; p="${EXTERNAL_PORTS[$i]}"
    h2 "Broker $b via localhost:${p}"
    wait_broker "$b" "localhost" "$p"
    green "OK $b (localhost:${p})"
  done
else
  for b in "${BROKERS[@]}"; do
    h2 "Broker $b via ${b}:${INTERNAL_PORT}"
    wait_broker "$b" "$b" "$INTERNAL_PORT"
    green "OK $b (${b}:${INTERNAL_PORT})"
  done
fi

BOOTSTRAP_HOST="kafka1"; BOOTSTRAP_PORT="$INTERNAL_PORT"
PROD_HOST="kafka1"; PROD_PORT="$INTERNAL_PORT"
CONS_HOST="kafka2"; CONS_PORT="$INTERNAL_PORT"

if [[ $USE_EXTERNAL -eq 1 ]]; then
  BOOTSTRAP_HOST="localhost"; BOOTSTRAP_PORT="9092"
  PROD_HOST="localhost"; PROD_PORT="9092"
  CONS_HOST="localhost"; CONS_PORT="9092"
fi

h1 "Crear tópico '${TOPIC}' (P=${PARTS}, RF=${RF}) si no existe"
if in_c "kafka1" "kafka-topics --bootstrap-server ${BOOTSTRAP_HOST}:${BOOTSTRAP_PORT} --list | grep -qx '${TOPIC}'"; then
  yellow "El tópico ya existe: ${TOPIC}"
else
  in_c "kafka1" "kafka-topics --create --topic ${TOPIC} --bootstrap-server ${BOOTSTRAP_HOST}:${BOOTSTRAP_PORT} --partitions ${PARTS} --replication-factor ${RF}"
  green "Tópico creado: ${TOPIC}"
fi

h2 "Describe tópico"
in_c "kafka1" "kafka-topics --describe --topic ${TOPIC} --bootstrap-server ${BOOTSTRAP_HOST}:${BOOTSTRAP_PORT}"

h1 "Producir 5 mensajes de prueba"
in_c "kafka1" "cat <<'EOF' | kafka-console-producer --topic ${TOPIC} --bootstrap-server ${PROD_HOST}:${PROD_PORT}
hola
mensaje 2
mensaje 3
mensaje 4
mensaje 5
EOF"
green "Mensajes enviados."

h1 "Consumir desde el comienzo (timeout 5s de inactividad)"
in_c "kafka2" "kafka-console-consumer --topic ${TOPIC} --bootstrap-server ${CONS_HOST}:${CONS_PORT} --from-beginning --timeout-ms 5000 || true"

h1 "Simular caída de broker: kafka3"
podman stop kafka3 >/dev/null
sleep 3
h2 "Describe después de la caída"
in_c "kafka1" "kafka-topics --describe --topic ${TOPIC} --bootstrap-server ${BOOTSTRAP_HOST}:${BOOTSTRAP_PORT}"

h2 "Producir 2 mensajes más durante la caída"
in_c "kafka1" "cat <<'EOF' | kafka-console-producer --topic ${TOPIC} --bootstrap-server ${PROD_HOST}:${PROD_PORT}
con_kafka3_caido_1
con_kafka3_caido_2
EOF"

h2 "Consumir (timeout 5s)"
in_c "kafka2" "kafka-console-consumer --topic ${TOPIC} --bootstrap-server ${CONS_HOST}:${CONS_PORT} --from-beginning --timeout-ms 5000 || true"

h1 "Recuperar kafka3"
podman start kafka3 >/dev/null
wait_broker "kafka3" "kafka3" "${INTERNAL_PORT}"
sleep 2

h2 "Describe con cluster recuperado"
in_c "kafka1" "kafka-topics --describe --topic ${TOPIC} --bootstrap-server ${BOOTSTRAP_HOST}:${BOOTSTRAP_PORT}"

green "Demo completada ✔"
