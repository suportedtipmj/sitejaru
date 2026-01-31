# 🚀 WordPress Stack Profissional com Docker

Stack completo e profissional para WordPress com camadas de segurança, cache, storage distribuído e banco de dados.

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────┐
│         🌐 Internet / Usuários              │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────▼──────────┐
        │   NGINX + ModSec    │ ← Firewall / WAF
        │   (Porteiro)        │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │   WordPress FPM     │ ← Aplicação
        │   (Operário)        │
        └──┬────────┬────────┬┘
           │        │        │
    ┌──────▼──┐ ┌──▼───┐ ┌──▼─────┐
    │  MySQL  │ │Redis │ │ MinIO  │
    │(Coração)│ │(⚡)  │ │(Cofre) │
    └─────────┘ └──────┘ └────────┘
```

### 📦 Componentes

| Serviço | Imagem | Função | Porta |
|---------|--------|--------|-------|
| **Nginx** | `nginx:alpine` | Proxy Reverso | 80, 443 |
| **WordPress** | `wordpress:fpm-alpine` | Aplicação PHP-FPM | - |
| **Redis** | `redis:alpine` | Cache de objetos | - |
| **MinIO** | `minio/minio` | Storage S3-compatible | 9000, 9001 |
| **MySQL** | `mysql:8.0` | Banco de dados | - |

## 🚀 Como Usar

### 1️⃣ Estrutura de Diretórios

```
sitewordpress/
├── docker-compose.yml
├── nginx/
│   └── conf.d/
│       └── default.conf
├── wordpress/
├── setup-automation.sh    (Linux/Mac)
└── setup-automation.ps1   (Windows)
```

### 2️⃣ Iniciar Stack

#### No Windows (PowerShell):
```powershell
.\setup-automation.ps1
```

#### No Linux/Mac:
```bash
chmod +x setup-automation.sh
./setup-automation.sh
```

#### Manualmente:
```bash
docker-compose up -d
```

### 3️⃣ Acessar Serviços

- **WordPress**: http://localhost
- **MinIO Console**: http://localhost:9001
  - User: `admin_minio`
  - Pass: `senha_minio_123`

### 4️⃣ Configuração do WordPress

1. Acesse http://localhost
2. Complete a instalação básica do WordPress
3. Instale os plugins necessários:

#### Plugin Redis Object Cache
```bash
# No painel do WordPress:
Plugins → Adicionar Novo → Buscar "Redis Object Cache"
Instalar → Ativar → Settings → Enable Object Cache
```

#### Plugin Advanced Media Offloader
Este é o plugin recomendado por sua compatibilidade nativa e estável com MinIO.

**Fácil Configuração:**
O projeto já vem pré-configurado para injetar as credenciais no `wp-config.php`. Se precisar configurar manualmente no arquivo:

```php
define( 'ADVMO_MINIO_KEY', 'admin_minio' );
define( 'ADVMO_MINIO_SECRET', 'senha_minio_123' );
define( 'ADVMO_MINIO_BUCKET', 'media-wp' );
define( 'ADVMO_MINIO_REGION', 'us-east-1' );
define( 'ADVMO_MINIO_ENDPOINT', 'http://minio:9000' );
define( 'ADVMO_MINIO_DOMAIN', 'http://localhost:9000' );
define( 'ADVMO_MINIO_APPEND_BUCKET_TO_DOMAIN', true );
define( 'ADVMO_MINIO_PATH_STYLE_ENDPOINT', true );
```

### 5️⃣ Configuração Manual do MinIO

Se o script de automação não funcionar:

1. Acesse http://localhost:9001
2. Login com as credenciais acima
3. Criar bucket `media-wp`
4. Access Policy → Public
5. Salvar

## 🔧 Comandos Úteis

### Ver logs dos containers
```bash
docker-compose logs -f
```

### Reiniciar um serviço específico
```bash
docker-compose restart wordpress
```

### Acessar shell do WordPress
```bash
docker exec -it wp_app sh
```

### Backup do banco de dados
```bash
docker exec wp_mysql mysqldump -u wp_user -pwp_password wordpress_db > backup.sql
```

### Corrigir permissões
```bash
docker exec wp_app chown -R www-data:www-data /var/www/html
```

## 🛡️ Segurança

- **ModSecurity WAF**: Proteção contra ataques comuns (OWASP Top 10)
- **Redes isoladas**: Frontend vs Backend separation
- **Permissões corretas**: www-data ownership
- **Credenciais**: Altere as senhas padrão em produção!

## ⚡ Performance (Supercharged)

Esta stack foi otimizada para "Excelente Desempenho":

- **Nginx FastCGI Cache**: Armazena páginas prontas para visitantes, reduzindo o tempo de resposta (TTFB) para milissegundos.
- **Gzip Compression**: Compacta HTML, CSS e JS automaticamente para carregamento ultra-rápido em redes móveis.
- **PHP OPcache Tuning**: Configurado com 256MB de memória e otimização de scripts via `performance.ini`.
- **MySQL InnoDB Tuning**: Otimizado para melhor uso de buffer pool e escrita em disco.
- **Redis Object Cache**: Cache de banco de dados para usuários logados e painel admin.
- **MinIO S3 Offload**: Mídia servida de forma independente, liberando o WordPress para focar no conteúdo.

## 🔄 Atualização

```bash
docker-compose pull
docker-compose up -d
```

## 🗑️ Remover Stack

```bash
# Parar containers
docker-compose down

# Remover também os volumes (⚠️ apaga dados)
docker-compose down -v
```

## 📊 Monitoramento

Verificar uso de recursos:
```bash
docker stats
```

## 🆘 Troubleshooting

### WordPress não carrega
```bash
docker-compose logs wordpress
```

### Erro de permissão
```bash
docker exec wp_app chown -R www-data:www-data /var/www/html
```

### MinIO não acessível
```bash
docker-compose logs minio
# Verificar se a porta 9001 está livre
```

### MySQL não conecta
```bash
docker exec wp_mysql mysqladmin ping -h localhost
```

## 📝 Credenciais Padrão

> ⚠️ **IMPORTANTE**: Altere estas credenciais em produção!

**MySQL:**
- Host: `mysql_db`
- Database: `wordpress_db`
- User: `wp_user`
- Password: `wp_password`
- Root Password: `root_password_segura`

**MinIO:**
- User: `admin_minio`
- Password: `senha_minio_123`
- Bucket: `media-wp`

**Redis:**
- Host: `redis_cache`
- Port: `6379`

## 🎯 Próximos Passos

1. ✅ Configurar SSL/TLS com Let's Encrypt
2. ✅ Implementar backup automático
3. ✅ Configurar monitoramento (Prometheus/Grafana)
4. ✅ Otimizar regras do ModSecurity
5. ✅ Implementar CDN na frente do Nginx

## 📚 Documentação

- [WordPress Docker](https://hub.docker.com/_/wordpress)
- [ModSecurity CRS](https://coreruleset.org/)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [Redis Object Cache](https://wordpress.org/plugins/redis-cache/)

---

**Desenvolvido com ❤️ para alta performance e segurança**
