# 🚀 Guia de Implantação em Produção (WordPress + MinIO + Performance Stack)

Este documento contém os passos exatos para subir este mesmo ambiente em um novo servidor de produção amanhã.

## 📋 Pré-requisitos
- Docker e Docker Compose instalados.
- Git instalado.
- Domínio apontado para o IP do servidor (opcional para teste local).

## 🚚 Passo 1: Clonar o Repositório
No novo servidor, execute:
```bash
git clone https://github.com/sonyjaru/sitejaru.git
cd sitejaru
```

## ⚙️ Passo 2: Configuração Automática
Utilize o script de automação para configurar o banco de dados, o bucket do MinIO e as permissões:

**No Linux:**
```bash
chmod +x setup-automation.sh
./setup-automation.sh
```

**No Windows (PowerShell):**
```powershell
.\setup-automation.ps1
```

O script já irá:
1. Subir todos os containers.
2. Criar o bucket `media-wp` no MinIO e torná-lo público.
3. Instalar o plugin **Advanced Media Offloader**.
4. Injetar todas as constantes de performance e S3 no `wp-config.php`.

## ⚡ Passo 3: Ativação dos Caches (Performance Máxima)
Após o script terminar:
1. Acesse o painel do WordPress.
2. Ative o plugin **Redis Object Cache** e clique em "Enable Object Cache".
3. O **Nginx FastCGI Cache** e a **Compressão Gzip** já estarão ativos via arquivo `nginx/conf.d/default.conf`.

## 🛡️ Passo 4: Verificação de Segurança
O ambiente já sobe com:
- Bloqueio de `xmlrpc.php`.
- Security Headers ativos.
- Edição de arquivos desativada no painel.
- Rate Limiting no login.

## 📦 Passo 5: Migração de Mídias Antigas (2015+)
Se você for subir as pastas de anos anteriores para o MinIO:
1. Use o Console do MinIO em `http://IP-DO-SERVIDOR:9001`.
2. Faça o upload das pastas de anos anteriores para dentro do bucket `media-wp`.
3. Certifique-se de manter a mesma estrutura de pastas (`uploads/2015/...`).

## 🔒 Passo 6: Travas de Histórico (Somente Leitura)
Para proteger suas fotos antigas de serem apagadas ou alteradas por acidente ou vírus:

1. O arquivo `historical-lock-policy.json` já está na raiz do projeto.
2. No servidor, use o comando para aplicar esta política:
```bash
# Definir o alias (se já não estiver definido)
docker exec minio_s3 mc alias set local http://localhost:9000 admin_minio senha_minio_123

# Criar a política de trava
docker exec minio_s3 mc admin policy create local lock-historical /data/historical-lock-policy.json

# Aplicar ao bucket (O WordPress continuará lendo, mas não poderá mudar nada de 2015-2025)
docker exec minio_s3 mc admin policy set local lock-historical group=public
```

*Nota: Esta política usa o efeito 'Deny' para sobrepor qualquer outra permissão de escrita nas pastas selecionadas.*

## 🔍 Comandos de Verificação
- **Logs**: `docker-compose logs -f`
- **Status do Cache**: `curl -I http://localhost` (Procure por `X-Cache-Status: HIT`)
- **Status da Mídia**: Abra o link de uma imagem e verifique se aponta para a porta 9000.

## 🛡️ Dicas de Segurança Avançada
Para uma proteção completa em produção:

1.  **Cloudflare Full (Strict)**: No painel do Cloudflare, mude o SSL de 'Flexible' para 'Full (Strict)'.
2.  **Mudar URL de Login**: Instale o plugin `WPS Hide Login` e mude o `/wp-admin` para uma URL personalizada.
3.  **Auditoria**: Instale o `Wordfence` ou `Activity Log` para monitorar quem mexe no site.
4.  **Permissões**: O Docker já protege os arquivos core, mas evite instalar plugins de procedência duvidosa ("nulled").

---
**Documentação consolidada para o ambiente de produção.**
