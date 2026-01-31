#!/bin/bash

# ==============================================================================
# Script de Automação WordPress Stack PRO
# Versão: 1.1 - Consolidada com correções de WAF, MinIO e Proxy
# ==============================================================================

echo -e "\033[0;36m🚀 Iniciando Consolidação do WordPress Stack (v1.1)...\033[0m"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Subir/Reiniciar containers
echo -e "\n${YELLOW}📦 Garantindo que os containers estão rodando...${NC}"
docker compose up -d

# 2. Corrigir Nginx (WAF desativado e Root/Index configurados)
echo -e "\n${YELLOW}🛠️  Aplicando configuração otimizada no Nginx...${NC}"
cat << 'EOF' > ./nginx/conf.d/default.conf
fastcgi_cache_path /etc/nginx/cache levels=1:2 keys_zone=WORDPRESS:100m inactive=60m;
fastcgi_cache_key "$scheme$request_method$host$request_uri";

# Rate Limiting (Instrução: Desativado conforme solicitado)
# limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

# Bloqueio de Bad Bots (Instrução: Desativado conforme solicitado)
# map $http_user_agent $bad_bot {
#     default 0;
#     ~*(dirbuster|nikto|wpscan|sqlmap|python-requests|curl|wget) 1;
# }

server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    # Bloqueio de Bad Bots
    # if ($bad_bot) {
    #     return 403;
    # }

    # Debug do Cache
    add_header X-Cache-Status $upstream_cache_status;

    # Security Headers (Instrução: Comentados para facilitar testes)
    # add_header X-Frame-Options "SAMEORIGIN" always;
    # add_header X-XSS-Protection "1; mode=block" always;
    # add_header X-Content-Type-Options "nosniff" always;
    # add_header Referrer-Policy "no-referrer-when-downgrade" always;
    # add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline' 'unsafe-eval'; img-src 'self' * data: blob:; font-src 'self' * data:; connect-src 'self' *; frame-src *;" always;

    # Gzip Compression
    gzip on;
    gzip_types text/plain text/css text/xml application/json application/javascript image/svg+xml;

    # Tamanho máximo de upload
    client_max_body_size 64M;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        
        # FastCGI Cache
        fastcgi_cache WORDPRESS;
        fastcgi_cache_valid 200 301 302 60m;
        fastcgi_cache_use_stale error timeout updating invalid_header http_500 http_503;
        fastcgi_cache_bypass $skip_cache;
        fastcgi_no_cache $skip_cache;

        # Timeouts para uploads grandes
        fastcgi_read_timeout 300;
    }

    # Lógica de Cache (Usuários Logados, etc)
    set $skip_cache 0;
    if ($request_method = POST) { set $skip_cache 1; }
    if ($query_string != "") { set $skip_cache 1; }
    if ($request_uri ~* "/wp-admin/|/xmlrpc.php|wp-.*.php|/feed/|index.php") { set $skip_cache 1; }
    if ($http_cookie ~* "comment_author|wordpress_[a-f0-7]+|wp-postpass|wordpress_no_cache|wordpress_logged_in") { set $skip_cache 1; }

    # Proteção de arquivos sensíveis (Instrução: Comentado conforme solicitado)
    # location ~* /(?:uploads|files)/.*\.php$ { deny all; }
    # location = /xmlrpc.php { deny all; access_log off; log_not_found off; }

    # Rate Limit para Login (Instrução: Desativado conforme solicitado)
    location = /wp-login.php {
        # limit_req zone=login burst=5 nodelay;
        fastcgi_pass wordpress:9000;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # Proxy para MinIO (Resolve problemas de porta e Cross-Origin)
    location ^~ /media-wp/ {
        proxy_pass http://minio:9000/media-wp/;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        expires max;
    }

    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }

    location ~* \.(css|gif|ico|jpeg|jpg|js|png|svg|webp|woff|woff2|ttf|otf)$ {
        expires max;
        log_not_found off;
        access_log off;
    }
}
EOF
docker exec nginx_waf nginx -s reload

# 3. Configurar MinIO
echo -e "\n${YELLOW}🪣 Configurando Bucket MinIO...${NC}"
docker exec minio_s3 mkdir -p /data/media-wp
cat << 'EOF' > temp-policy.json
{
    "Version": "2012-10-17",
    "Statement": [{"Effect": "Allow", "Principal": {"AWS": ["*"]}, "Action": ["s3:GetObject"], "Resource": ["arn:aws:s3:::media-wp/*"]}]
}
EOF
docker cp temp-policy.json minio_s3:/tmp/policy.json
docker exec minio_s3 sh -c "mc alias set local http://localhost:9000 admin_minio senha_minio_123 && mc anonymous set-json /tmp/policy.json local/media-wp"
rm temp-policy.json

# 4. Configurar WordPress (Plugins e wp-config.php)
echo -e "\n${YELLOW}🔌 Configurando WordPress e ADVMO...${NC}"

# Garantir plugin instalado
if docker exec wp_app command -v wp &> /dev/null; then
    docker exec wp_app wp plugin install advanced-media-offloader --activate --allow-root
else
    docker exec wp_app sh -c "cd /var/www/html/wp-content/plugins && wget -q https://downloads.wordpress.org/plugin/advanced-media-offloader.latest-stable.zip -O advmo.zip && unzip -oq advmo.zip && rm advmo.zip"
fi

# Script PHP para limpeza e injeção do wp-config.php (Método Infalível)
cat << 'EOF' > fix_config_final.php
<?php
$file = "/var/www/html/wp-config.php";
if (!file_exists($file)) die("wp-config.php not found\n");
$lines = file($file);
$new_lines = [];
foreach ($lines as $line) { if (strpos($line, "ADVMO") === false) { $new_lines[] = $line; } }
$content = implode("", $new_lines);
$config = "
define( 'ADVMO_MINIO_KEY', 'admin_minio' );
define( 'ADVMO_MINIO_SECRET', 'senha_minio_123' );
define( 'ADVMO_MINIO_BUCKET', 'media-wp' );
define( 'ADVMO_MINIO_REGION', 'us-east-1' );
define( 'ADVMO_MINIO_ENDPOINT', 'http://minio:9000' );
define( 'ADVMO_MINIO_DOMAIN', 'https://' . (\$_SERVER['HTTP_HOST'] ?? 'oficial.jaru.ro.gov.br') );
define( 'ADVMO_MINIO_APPEND_BUCKET_TO_DOMAIN', true );
define( 'ADVMO_MINIO_PATH_STYLE_ENDPOINT', true );
";
$content = str_replace("/* That's all, stop editing!", $config . "/* That's all, stop editing!", $content);
file_put_contents($file, $content);
echo "wp-config.php atualizado com sucesso!\n";
?>
EOF
docker cp fix_config_final.php wp_app:/tmp/fix_config.php
docker exec wp_app php /tmp/fix_config.php
rm fix_config_final.php

# 5. Limpar Cache do Redis
echo -e "\n${YELLOW}🧹 Limpando cache do Redis...${NC}"
docker exec wp_redis redis-cli flushall

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✨ AMBIENTE CONSOLIDADO COM SUCESSO!     ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\n${YELLOW}Logs Nginx:${NC}"
docker exec nginx_waf nginx -t
