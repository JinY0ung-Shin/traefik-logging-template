# Traefik + Prometheus + Grafana Template

Docker Compose 기반의 Traefik 리버스 프록시 템플릿입니다.
서비스별/엔드포인트별 사용량을 Prometheus로 수집하고 Grafana로 시각화합니다.

## 구성 요소

| 서비스 | 버전 | 설명 | 내부 포트 | 외부 접근 |
|--------|------|------|-----------|-----------|
| Traefik | v3.0 | 리버스 프록시 & 로드밸런서 | 80, 443, 8080, 8082 | http://traefik.localhost:8080 |
| Prometheus | v2.50.0 | 메트릭 수집 & 저장 | 9090 | http://prometheus.localhost (IP 제한) |
| Grafana | v10.3.0 | 메트릭 시각화 | 3000 | http://grafana.localhost:3000 |
| Sample App | latest | 테스트용 whoami 서비스 | 80 | http://app.localhost |

> **Note**: Prometheus는 보안을 위해 IP allowlist로 접근이 제한됩니다. 기본값은 `127.0.0.1/32`입니다.

## 빠른 시작

```bash
# 1. 클론
git clone <repository-url>
cd traefik-prometheus-template

# 2. 환경 변수 설정
cp .env.example .env
# 필요시 PROMETHEUS_ALLOWED_IPS 수정

# 3. 실행
docker compose up -d

# 4. 접속
# Traefik Dashboard: http://traefik.localhost:8080
# Grafana: http://grafana.localhost:3000 (admin/admin)
# Sample App: http://app.localhost
# Prometheus: http://prometheus.localhost (IP 제한됨)
```

## 환경 변수

`.env.example`을 `.env`로 복사하여 설정합니다:

| 변수 | 설명 | 기본값 |
|------|------|--------|
| `PROMETHEUS_ALLOWED_IPS` | Prometheus 접근 허용 IP (CIDR) | `127.0.0.1/32` |

예시:
```bash
# 단일 IP 허용
PROMETHEUS_ALLOWED_IPS=192.168.1.100/32

# 여러 IP/대역 허용
PROMETHEUS_ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8
```

## 디렉토리 구조

```
.
├── docker-compose.yml          # 메인 Docker Compose 파일
├── .env.example                # 환경 변수 예시
├── traefik/
│   ├── traefik.yml            # Traefik 정적 설정
│   └── dynamic/               # Traefik 동적 설정
│       ├── middlewares.yml    # 미들웨어 설정
│       └── tls.yml            # TLS 설정 (선택사항)
├── prometheus/
│   ├── prometheus.yml         # Prometheus 설정
│   └── alerts/                # 알림 규칙
│       └── traefik-alerts.yml
└── grafana/
    ├── provisioning/
    │   ├── datasources/       # 데이터소스 자동 설정
    │   └── dashboards/        # 대시보드 프로비저닝
    └── dashboards/            # 대시보드 JSON 파일
        └── traefik-dashboard.json
```

## 서비스 추가 방법

### 1. 기본 서비스 추가

`docker-compose.yml`에 서비스를 추가하고 Traefik labels를 설정합니다:

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
```

### 2. Path 기반 라우팅

```yaml
labels:
  - "traefik.http.routers.my-service.rule=Host(`api.localhost`) && PathPrefix(`/v1/users`)"
```

### 3. 미들웨어 적용

```yaml
labels:
  # Rate limiting 적용
  - "traefik.http.routers.my-service.middlewares=rate-limit@file"

  # 여러 미들웨어 체이닝
  - "traefik.http.routers.my-service.middlewares=rate-limit@file,secure-headers@file"
```

## 사용 가능한 미들웨어

| 미들웨어 | 설명 |
|----------|------|
| `rate-limit@file` | Rate limiting (100 req/s, burst 50) |
| `secure-headers@file` | 보안 헤더 추가 (XSS, HSTS 등) |
| `compress@file` | 응답 압축 (event-stream 제외) |
| `retry@file` | 자동 재시도 (3회, 100ms 간격) |
| `circuit-breaker@file` | Circuit breaker (에러율 30% 또는 5xx 25% 초과 시) |
| `strip-api-prefix@file` | `/api` prefix 제거 |
| `add-request-id@file` | X-Request-Start 헤더 추가 |

## 모니터링 메트릭

Traefik이 자동으로 수집하는 주요 메트릭:

### 서비스별 메트릭
- `traefik_service_requests_total` - 총 요청 수
- `traefik_service_request_duration_seconds` - 요청 처리 시간
- `traefik_service_open_connections` - 열린 연결 수

### 라우터별 메트릭 (엔드포인트)
- `traefik_router_requests_total` - 라우터별 요청 수
- `traefik_router_request_duration_seconds` - 라우터별 처리 시간

### Entry Point 메트릭
- `traefik_entrypoint_requests_total` - 진입점별 요청 수
- `traefik_entrypoint_open_connections` - 진입점별 연결 수

## Grafana 대시보드

자동으로 프로비저닝되는 대시보드에서 확인할 수 있는 정보:

- **Overview**: 전체 요청/s, 에러율, P95 레이턴시, 연결 수
- **Service Metrics**: 서비스별 요청량, 에러율, 레이턴시, 상태코드 분포
- **Router Metrics**: 엔드포인트(라우터)별 요청량
- **Entry Points**: 진입점별 트래픽, 열린 연결 수

## 알림 규칙 (Alerts)

사전 정의된 Prometheus 알림 규칙:

| 알림 | 조건 | 심각도 |
|------|------|--------|
| TraefikHighErrorRate | 서비스 에러율 > 5% (5분간) | warning |
| TraefikHighLatency | P95 레이턴시 > 1초 (5분간) | warning |
| TraefikServiceDown | 백엔드 서비스 다운 | critical |
| TraefikHighRequestRate | 요청 > 1000/s (2분간) | warning |
| TraefikTooManyOpenConnections | 연결 > 1000개 (5분간) | warning |

> Alertmanager 연동 시 `prometheus/prometheus.yml`에서 alertmanager 설정을 활성화하세요.

## 프로덕션 설정

### HTTPS 활성화

1. `traefik/dynamic/tls.yml` 파일의 주석을 해제
2. 인증서 파일 경로 설정
3. `docker-compose.yml`에 인증서 볼륨 마운트 추가

### 보안 강화

```yaml
# Traefik Dashboard 보안 (Basic Auth)
labels:
  - "traefik.http.routers.traefik-dashboard.middlewares=dashboard-auth"
  - "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$..."
```

### 외부 도메인 사용

```yaml
# 실제 도메인으로 변경
labels:
  - "traefik.http.routers.my-service.rule=Host(`api.example.com`)"
```

### Prometheus 접근 허용 IP 설정

```bash
# .env 파일에서 설정
PROMETHEUS_ALLOWED_IPS=10.0.0.0/8,192.168.1.0/24
```

## 유용한 Prometheus 쿼리

```promql
# 서비스별 요청/초
sum(rate(traefik_service_requests_total[5m])) by (service)

# 서비스별 에러율
sum(rate(traefik_service_requests_total{code=~"5.."}[5m])) by (service)
/ sum(rate(traefik_service_requests_total[5m])) by (service)

# 서비스별 P95 레이턴시
histogram_quantile(0.95, sum(rate(traefik_service_request_duration_seconds_bucket[5m])) by (service, le))

# 상태 코드별 분포
sum(rate(traefik_service_requests_total[5m])) by (code)
```

## 트러블슈팅

### 서비스가 Traefik에서 보이지 않음
- `traefik.enable=true` 라벨 확인
- 동일 네트워크(`traefik-net`) 연결 확인
- `docker compose logs traefik` 로그 확인

### 메트릭이 수집되지 않음
- Prometheus targets 페이지에서 상태 확인: http://prometheus.localhost/targets
- Traefik 메트릭 엔드포인트 확인: `docker compose exec traefik wget -qO- http://localhost:8082/metrics`

### Grafana 대시보드가 비어있음
- Prometheus 데이터소스 연결 확인
- 최소 몇 분간 트래픽 발생 후 확인

### Prometheus에 접근할 수 없음
- `.env` 파일에서 `PROMETHEUS_ALLOWED_IPS` 설정 확인
- 접속하려는 IP가 allowlist에 포함되어 있는지 확인

## 라이선스

MIT License
