FROM node:22-alpine

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile

COPY . .

ARG FORTIS_API_BASE_URL=http://backend:8090
ARG BACKEND_URL=http://backend:8090/api/v1
ARG NEXT_PUBLIC_DEFENSE_RUNTIME=api

ENV NEXT_TELEMETRY_DISABLED=1
ENV FORTIS_API_BASE_URL=$FORTIS_API_BASE_URL
ENV BACKEND_URL=$BACKEND_URL
ENV NEXT_PUBLIC_DEFENSE_RUNTIME=$NEXT_PUBLIC_DEFENSE_RUNTIME

RUN pnpm build

EXPOSE 3000

CMD ["pnpm", "exec", "next", "start", "-H", "0.0.0.0"]
