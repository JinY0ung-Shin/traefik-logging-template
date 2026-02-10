#!/usr/bin/env bash
set -euo pipefail

# Traefik + Loki + Grafana 로깅 스택 설치 스크립트
# 기존 프로젝트에 인프라 파일을 설치합니다.
#
# 사용법:
#   curl -fsSL https://raw.githubusercontent.com/<owner>/traefik-logging-template/main/setup.sh | bash
#   또는
#   bash setup.sh [설치_경로]

REPO_URL="https://github.com/JinY0ung-Shin/traefik-logging-template"
BRANCH="main"
INFRA_DIR="${1:-infra}"
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

info()  { echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"; }
ok()    { echo -e "${COLOR_GREEN}[OK]${COLOR_RESET} $*"; }
warn()  { echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"; }
error() { echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2; }

# ─── 사전 조건 확인 ───────────────────────────────────────
check_prerequisites() {
    local missing=()

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi
    if ! command -v docker &>/dev/null; then
        missing+=("docker")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "필수 도구가 없습니다: ${missing[*]}"
        error "먼저 설치해 주세요."
        exit 1
    fi

    # Docker Compose v2 확인
    if ! docker compose version &>/dev/null; then
        error "Docker Compose v2가 필요합니다. (docker compose 명령어)"
        exit 1
    fi
}

# ─── 메인 설치 ─────────────────────────────────────────────
install() {
    info "Traefik + Loki + Grafana 로깅 스택을 설치합니다..."
    info "설치 경로: ./${INFRA_DIR}/"
    echo ""

    # 이미 존재하는지 확인
    if [ -d "${INFRA_DIR}" ]; then
        warn "'${INFRA_DIR}/' 디렉토리가 이미 존재합니다."
        read -rp "덮어쓰시겠습니까? (y/N): " confirm
        if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
            info "설치를 취소합니다."
            exit 0
        fi
        rm -rf "${INFRA_DIR}"
    fi

    # 임시 디렉토리에 clone
    local tmpdir
    tmpdir=$(mktemp -d)
    trap "rm -rf '${tmpdir}'" EXIT

    info "템플릿을 다운로드합니다..."
    git clone --depth 1 --branch "${BRANCH}" "${REPO_URL}" "${tmpdir}/repo" 2>/dev/null

    # 필요한 파일만 복사
    mkdir -p "${INFRA_DIR}"

    # 설정 디렉토리 복사
    cp -r "${tmpdir}/repo/traefik"  "${INFRA_DIR}/traefik"
    cp -r "${tmpdir}/repo/loki"     "${INFRA_DIR}/loki"
    cp -r "${tmpdir}/repo/promtail" "${INFRA_DIR}/promtail"
    cp -r "${tmpdir}/repo/grafana"  "${INFRA_DIR}/grafana"

    # 인프라 compose 파일 복사
    cp "${tmpdir}/repo/docker-compose.infra.yml" "${INFRA_DIR}/docker-compose.infra.yml"

    # .env.example 복사
    if [ -f "${tmpdir}/repo/.env.example" ]; then
        cp "${tmpdir}/repo/.env.example" "${INFRA_DIR}/.env.example"
    fi

    ok "인프라 파일 설치 완료!"
    echo ""

    # ─── docker-compose.yml 설정 안내 ─────────────────────
    info "다음 단계: docker-compose.yml에 아래 내용을 추가하세요."
    echo ""
    echo -e "${COLOR_GREEN}# ── 방법 1: include (Docker Compose v2.20+ 권장) ──${COLOR_RESET}"
    echo ""
    cat <<'EXAMPLE1'
include:
  - path: ./infra/docker-compose.infra.yml

services:
  my-app:
    build: .
    networks:
      - traefik-net     # infra에서 정의된 네트워크에 연결
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.localhost`)"
      - "traefik.http.routers.my-app.entrypoints=web"
      - "traefik.http.services.my-app.loadbalancer.server.port=8080"
      # 미들웨어 적용 (선택)
      - "traefik.http.routers.my-app.middlewares=rate-limit@file,secure-headers@file"

networks:
  traefik-net:
    external: true    # infra 스택이 생성한 네트워크 사용
EXAMPLE1
    echo ""
    echo -e "${COLOR_GREEN}# ── 방법 2: 다중 compose 파일 (모든 버전) ──${COLOR_RESET}"
    echo ""
    echo "  docker compose -f docker-compose.yml -f ${INFRA_DIR}/docker-compose.infra.yml up -d"
    echo ""

    # ─── .gitignore 안내 ───────────────────────────────────
    if [ -f ".gitignore" ]; then
        if ! grep -q "${INFRA_DIR}/" .gitignore 2>/dev/null; then
            warn ".gitignore에 '${INFRA_DIR}/'을 추가하면 인프라 파일을 추적에서 제외할 수 있습니다."
            warn "또는 함께 커밋하면 팀원들과 공유할 수 있습니다."
        fi
    fi

    echo ""
    ok "설치 완료!"
    echo ""
    info "접속 정보:"
    echo "  - Traefik Dashboard: http://traefik.localhost:8080"
    echo "  - Grafana:           http://grafana.localhost:3000 (admin/admin)"
    echo ""
    info "시작: docker compose up -d"
}

# ─── 실행 ──────────────────────────────────────────────────
check_prerequisites
install
