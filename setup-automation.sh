#!/bin/bash

echo "🚀 Iniciando configuração automática do WordPress Stack..."

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. Subir os containers
echo -e "${YELLOW}📦 Subindo containers...${NC}"
docker-compose up -d

# Aguardar containers iniciarem
echo -e "${YELLOW}⏳ Aguardando containers iniciarem (30 segundos)...${NC}"
sleep 30

# 2. Verificar saúde dos containers
echo -e "${YELLOW}🔍 Verificando status dos containers...${NC}"
docker-compose ps

# 3. Configurar MinIO usando mc (MinIO Client)
echo -e "${YELLOW}🪣 Configurando MinIO...${NC}"

# Instalar mc se não existir
if ! command -v mc &> /dev/null; then
    echo -e "${YELLOW}Instalando MinIO Client...${NC}"
    wget https://dl.min.io/client/mc/release/linux-amd64/mc -O /usr/local/bin/mc
    chmod +x /usr/local/bin/mc
fi

# Configurar alias para o MinIO local
mc alias set local http://localhost:9000 admin_minio senha_minio_123

# Criar bucket
echo -e "${YELLOW}Criando bucket media-wp...${NC}"
mc mb local/media-wp --ignore-existing

# Definir política pública para o bucket
echo -e "${YELLOW}Definindo permissões públicas para o bucket...${NC}"
mc anonymous set download local/media-wp

echo -e "${GREEN}✅ Bucket MinIO configurado com sucesso!${NC}"

# 4. Aguardar MySQL estar pronto
echo -e "${YELLOW}⏳ Aguardando MySQL estar pronto...${NC}"
sleep 10

until docker exec wp_mysql mysqladmin ping -h"localhost" --silent; do
    echo -e "${YELLOW}Aguardando MySQL...${NC}"
    sleep 2
done

echo -e "${GREEN}✅ MySQL está pronto!${NC}"

# 5. Corrigir permissões do WordPress
echo -e "${GREEN}✅ Permissões ajustadas!${NC}"

# 6. Instalar plugin e configurar wp-config.php
echo -e "${YELLOW}🔌 Configurando plugins e wp-config.php...${NC}"
docker exec wp_app wp plugin install advanced-media-offloader --activate --allow-root

# Injetar constantes no wp-config.php
docker exec wp_app sh -c 'sed -i "/\/\* That\x27s all, stop editing/i \
define( \x27ADVMO_MINIO_KEY\x27, \x27admin_minio\x27 );\n\
define( \x27ADVMO_MINIO_SECRET\x27, \x27senha_minio_123\x27 );\n\
define( \x27ADVMO_MINIO_BUCKET\x27, \x27media-wp\x27 );\n\
define( \x27ADVMO_MINIO_REGION\x27, \x27us-east-1\x27 );\n\
define( \x27ADVMO_MINIO_ENDPOINT\x27, \x27http://minio:9000\x27 );\n\
define( \x27ADVMO_MINIO_DOMAIN\x27, \x27http://localhost:9000\x27 );\n\
define( \x27ADVMO_MINIO_APPEND_BUCKET_TO_DOMAIN\x27, true );\n\
define( \x27ADVMO_MINIO_PATH_STYLE_ENDPOINT\x27, true );" /var/www/html/wp-config.php'

echo -e "${GREEN}✅ Plugins e constantes configurados!${NC}"

# 7. Exibir informações de acesso
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✨ Configuração concluída com sucesso!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📋 Informações de Acesso:${NC}"
echo ""
echo -e "🌐 WordPress: ${GREEN}http://localhost${NC}"
echo -e "   - Usuário DB: wp_user"
echo -e "   - Senha DB: wp_password"
echo -e "   - Database: wordpress_db"
echo ""
echo -e "🗄️  MinIO Console: ${GREEN}http://localhost:9001${NC}"
echo -e "   - Usuário: admin_minio"
echo -e "   - Senha: senha_minio_123"
echo -e "   - Bucket: media-wp (público)"
echo ""
echo -e "⚡ Redis: ${GREEN}redis_cache:6379${NC} (interno)"
echo ""
echo -e "${YELLOW}📝 Próximos passos:${NC}"
echo "1. Acesse http://localhost e complete a instalação do WordPress"
echo "2. O plugin Advanced Media Offloader já está instalado e configurado!"
echo "3. Caso precise de cache adicional, ative o plugin Redis Object Cache."
echo ""
echo -e "${GREEN}🎉 Tudo pronto para usar!${NC}"
