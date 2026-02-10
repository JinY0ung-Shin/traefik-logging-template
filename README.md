# Traefik + Loki + Grafana Template

Docker Compose 기반 Traefik 리버스 프록시 + 로그 기반 엔드포인트 요청 카운팅 스택

## 빠른 시작

```bash
git clone <repository-url> && cd traefik-logging-template
docker compose up -d
```

## 접속 정보

| 서비스 | URL | 비고 |
|--------|-----|------|
| Traefik Dashboard | http://traefik.localhost:8080 | |
| Grafana | http://grafana.localhost:3000 | admin/admin (.env로 변경 가능) |
| Sample App | http://app.localhost | |

## 스택 구성

```
Client → Traefik (리버스 프록시)
              ↓ access log (stdout)
         Promtail (로그 수집)
              ↓
           Loki (로그 저장, 30일 보관)
              ↓
         Grafana (카운팅 대시보드)
```

- **Traefik**: 서비스 라우팅 + JSON access log 출력
- **Promtail**: Traefik 컨테이너 로그 수집, 서비스/라우터/메소드/상태클래스 라벨 추출
- **Loki**: 로그 저장 (30일 보관), LogQL로 정확한 카운팅
- **Grafana**: 일별/주별/월별 엔드포인트 요청 수 대시보드

## 엔드포인트 카운팅

Grafana의 **Endpoint Request Counting** 대시보드에서 확인할 수 있습니다:

- 서비스별 / 라우터(엔드포인트)별 요청 수
- 일별 / 주별 / 월별 집계 전환
- HTTP 상태 클래스(2xx/3xx/4xx/5xx), 메소드별 분포
- 상세 테이블 (정확한 수치)
- 최근 access log 실시간 조회

> 로그 기반이므로 조회 시점에 관계없이 **항상 동일한 값**을 보장합니다.

## 서비스 추가

```yaml
my-service:
  image: my-service:latest
  networks:
    - traefik-net
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.my-service.rule=Host(`my-service.localhost`)"
    - "traefik.http.routers.my-service.entrypoints=web"
    - "traefik.http.services.my-service.loadbalancer.server.port=8080"
    # 미들웨어 적용 (선택)
    - "traefik.http.routers.my-service.middlewares=rate-limit@file,secure-headers@file"
```

## 기존 프로젝트에 설치하기

이미 개발 중인 앱 프로젝트에 이 로깅 스택을 추가하는 방법입니다.

### 방법 A: 설치 스크립트 (권장)

```bash
# 앱 프로젝트 루트에서 실행
curl -fsSL https://raw.githubusercontent.com/JinY0ung-Shin/traefik-logging-template/main/setup.sh | bash
```

이 스크립트는 `./infra/` 디렉토리에 인프라 설정 파일을 설치합니다.

설치 후 `docker-compose.yml`에 `include`를 추가하세요:

```yaml
# docker-compose.yml
include:
  - path: ./infra/docker-compose.infra.yml

services:
  my-app:
    build: .
    networks:
      - traefik-net
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.my-app.rule=Host(`app.localhost`)"
      - "traefik.http.routers.my-app.entrypoints=web"
      - "traefik.http.services.my-app.loadbalancer.server.port=8080"
      - "traefik.http.routers.my-app.middlewares=rate-limit@file,secure-headers@file"

networks:
  traefik-net:
    external: true
```

### 방법 B: 다중 Compose 파일 (Docker Compose 모든 버전)

설치 스크립트 실행 후, `include` 대신 CLI에서 직접 파일을 합쳐서 실행할 수도 있습니다:

```bash
docker compose -f docker-compose.yml -f infra/docker-compose.infra.yml up -d
```

### 방법 C: GitHub Template으로 새 프로젝트 시작

새 프로젝트를 시작하는 경우, GitHub에서 "Use this template" 버튼을 클릭하면 됩니다.

### 설치 후 프로젝트 구조 예시

```
my-app/
├── docker-compose.yml          # 앱 서비스 + include
├── src/                        # 앱 코드
├── Dockerfile
└── infra/                      # setup.sh가 설치한 인프라
    ├── docker-compose.infra.yml
    ├── traefik/
    ├── loki/
    ├── promtail/
    └── grafana/
```

## 미들웨어

| 이름 | 설명 |
|------|------|
| `rate-limit@file` | 100 req/s, burst 50 |
| `secure-headers@file` | XSS, HSTS 등 보안 헤더 |
| `compress@file` | gzip 압축 |
| `retry@file` | 3회 재시도 |
| `circuit-breaker@file` | 에러율 30% 초과 시 차단 |
| `dashboard-auth@file` | Dashboard BasicAuth (프로덕션용, 기본 비활성화) |

## 스케일링

```bash
docker compose up -d --scale sample-app=3
```

> `container_name` 제거 필요

## 주요 명령어

```bash
docker compose up -d          # 시작
docker compose logs -f        # 로그
docker compose down           # 중지
docker compose down -v        # 데이터 포함 삭제
```

---

상세 설정은 [CLAUDE.md](./CLAUDE.md) 참고

## License

MIT
