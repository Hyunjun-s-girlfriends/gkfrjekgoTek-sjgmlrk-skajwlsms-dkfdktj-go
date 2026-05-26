# ────────────────────────────────────────────────
# Stage 1: 프로덕션 의존성만 설치
# ────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app/server
COPY server/package*.json ./
RUN npm ci --only=production

# ────────────────────────────────────────────────
# Stage 2: 실행 이미지 (최소화)
# ────────────────────────────────────────────────
FROM node:20-alpine AS runner

# 보안: 전용 비루트 유저 생성
RUN addgroup -g 1001 -S nodejs \
 && adduser  -u 1001 -S nodejs -G nodejs

WORKDIR /app

# 의존성 + 소스 복사 (build context = 프로젝트 루트)
COPY --from=deps         --chown=nodejs:nodejs /app/server/node_modules ./server/node_modules
COPY --chown=nodejs:nodejs server/src    ./server/src
COPY --chown=nodejs:nodejs server/package.json ./server/package.json
COPY --chown=nodejs:nodejs public        ./public

USER nodejs
WORKDIR /app/server

EXPOSE 3000

# /health 엔드포인트로 컨테이너 헬스 체크
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/app.js"]
