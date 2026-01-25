# CLAUDE.md

이 파일은 AI 에이전트(Claude 등)가 프로젝트를 이해하는 데 필요한 컨텍스트를 제공합니다.

## 프로젝트 개요

**Traefik + Prometheus + Grafana Template**

Docker Compose 기반의 Traefik 리버스 프록시 모니터링 스택입니다. Traefik으로 서비스 트래픽을 라우팅하고, Prometheus로 메트릭을 수집하며, Grafana로 시각화합니다.

### 기술 스택
- **Traefik v3.0**: 리버스 프록시 및 로드 밸런서
- **Prometheus v2.50.0**: 메트릭 수집 및 저장 (TSDB)
- **Grafana v10.3.0**: 메트릭 시각화 대시보드
- **Docker Compose**: 컨테이너 오케스트레이션

## 아키텍처

```
                    ┌──────────────────────────────────────────────────┐
                    │                   Docker Network                  │
                    │                   (traefik-net)                   │
┌─────────┐         │  ┌─────────────┐      ┌─────────────────────────┐ │
│ Client  │─────────┼──│   Traefik   │──────│  Backend Services       │ │
│         │   :80   │  │   :80/:443  │      │  (sample-app, etc.)     │ │
└─────────┘   :443  │  │   :8080     │      └─────────────────────────┘ │
                    │  │   :8082     │                                  │
                    │  └──────┬──────┘                                  │
                    │         │ :8082 (metrics)                         │
                    │         ▼                                         │
                    │  ┌─────────────┐      ┌─────────────────────────┐ │
                    │  │ Prometheus  │──────│      Grafana            │ │
                    │  │   :9090     │      │      :3000              │ │
                    │  └─────────────┘      └─────────────────────────┘ │
                    └──────────────────────────────────────────────────┘
```

### 포트 구성
| 포트 | 서비스 | 용도 |
|------|--------|------|
| 80 | Traefik | HTTP 진입점 |
| 443 | Traefik | HTTPS 진입점 |
| 8080 | Traefik | Dashboard (외부 노출) |
| 8082 | Traefik | 메트릭 엔드포인트 (내부 전용) |
| 9090 | Prometheus | Web UI (IP 제한) |
| 3000 | Grafana | Web UI (외부 노출) |

## 핵심 파일 설명

### 설정 파일
| 파일 | 역할 |
|------|------|
| `docker-compose.yml` | 전체 서비스 정의. 네트워크, 볼륨, 서비스 구성 |
| `.env.example` | 환경 변수 템플릿 (PROMETHEUS_ALLOWED_IPS) |
| `traefik/traefik.yml` | Traefik 정적 설정 (entry points, providers, metrics) |
| `traefik/dynamic/middlewares.yml` | 재사용 가능한 미들웨어 정의 |
| `traefik/dynamic/tls.yml` | TLS 설정 (기본 비활성화) |
| `prometheus/prometheus.yml` | 스크래핑 설정, 알림 규칙 경로 |
| `prometheus/alerts/traefik-alerts.yml` | 사전 정의된 알림 규칙 |
| `grafana/provisioning/datasources/datasources.yml` | Prometheus 데이터소스 자동 설정 |
| `grafana/provisioning/dashboards/dashboards.yml` | 대시보드 프로비저닝 설정 |
| `grafana/dashboards/traefik-dashboard.json` | Traefik 모니터링 대시보드 |

### 볼륨
- `prometheus_data`: Prometheus TSDB 데이터 (15일 보관)
- `grafana_data`: Grafana 설정 및 데이터

## 주요 설정 상세

### Traefik Entry Points
```yaml
web: ":80"       # HTTP
websecure: ":443" # HTTPS
metrics: ":8082"  # Prometheus 메트릭
```

### Prometheus 스크래핑
- `prometheus` job: 자기 자신 (localhost:9090)
- `traefik` job: Traefik 메트릭 (traefik:8082, 5초 간격)

### 사전 정의된 미들웨어
1. **rate-limit**: 100 req/s, burst 50
2. **secure-headers**: XSS 필터, HSTS, Content-Type nosniff
3. **compress**: gzip 압축 (SSE 제외)
4. **retry**: 3회 재시도, 100ms 간격
5. **circuit-breaker**: 네트워크 에러 30% 또는 5xx 25% 초과 시 차단
6. **strip-api-prefix**: /api prefix 제거
7. **add-request-id**: 요청 시작 시간 헤더 추가

### Prometheus 알림 규칙
- `TraefikHighErrorRate`: 에러율 > 5%
- `TraefikHighLatency`: P95 > 1초
- `TraefikServiceDown`: 백엔드 다운
- `TraefikHighRequestRate`: > 1000 req/s
- `TraefikTooManyOpenConnections`: > 1000 연결

## 개발 가이드

### 새 서비스 추가
1. `docker-compose.yml`에 서비스 정의
2. `traefik-net` 네트워크에 연결
3. Traefik 라벨 추가:
   - `traefik.enable=true`
   - `traefik.http.routers.<name>.rule=Host(...)`
   - `traefik.http.routers.<name>.entrypoints=web`
   - `traefik.http.services.<name>.loadbalancer.server.port=<port>`

### 미들웨어 적용
```yaml
labels:
  - "traefik.http.routers.my-service.middlewares=rate-limit@file,secure-headers@file"
```

### 커스텀 메트릭 추가
1. `prometheus/prometheus.yml`의 `scrape_configs`에 job 추가
2. 애플리케이션에서 `/metrics` 엔드포인트 노출

### HTTPS 활성화
1. `traefik/dynamic/tls.yml` 주석 해제
2. 인증서 파일 준비 (cert.pem, key.pem)
3. `docker-compose.yml`에 볼륨 마운트 추가

## 명령어

```bash
# 시작
docker compose up -d

# 로그 확인
docker compose logs -f traefik
docker compose logs -f prometheus
docker compose logs -f grafana

# 재시작 (설정 변경 후)
docker compose restart traefik

# 중지
docker compose down

# 데이터 포함 완전 삭제
docker compose down -v
```

## 접속 정보
- Traefik Dashboard: http://traefik.localhost:8080
- Grafana: http://grafana.localhost:3000 (admin/admin)
- Sample App: http://app.localhost
- Prometheus: http://prometheus.localhost (IP 제한)

## 보안 고려사항

1. **Prometheus 접근 제한**: `.env`의 `PROMETHEUS_ALLOWED_IPS`로 IP 기반 접근 제어
2. **Traefik Dashboard**: 프로덕션에서는 Basic Auth 또는 IP 제한 권장
3. **Grafana 비밀번호**: 기본 admin/admin, 프로덕션에서 반드시 변경
4. **TLS**: 프로덕션에서는 HTTPS 활성화 필수

## 트러블슈팅 팁

1. **서비스가 안 보임**: `traefik.enable=true` 라벨과 `traefik-net` 네트워크 확인
2. **메트릭 누락**: `docker compose exec traefik wget -qO- http://localhost:8082/metrics`
3. **Prometheus 타겟 확인**: http://prometheus.localhost/targets
4. **Traefik 로그**: `docker compose logs traefik | grep -i error`
