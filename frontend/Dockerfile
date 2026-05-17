# =========================
# STAGE 1 - BUILD
# =========================
FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN npm install

COPY . .

RUN npm run build

# ... (Stage 1 igual)

# =========================
# STAGE 2 - PRODUCTION
# =========================
FROM nginx:stable-alpine

# Ajustar permisos para que el usuario nginx pueda manejar los logs y el cache
RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid /var/cache/nginx /var/log/nginx /etc/nginx/conf.d

USER nginx

COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]