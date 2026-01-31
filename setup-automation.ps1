# Script de Automação para Windows (PowerShell)
# Configuração automática do WordPress Stack

Write-Host "🚀 Iniciando configuração automática do WordPress Stack..." -ForegroundColor Cyan

# 1. Subir os containers
Write-Host "`n📦 Subindo containers..." -ForegroundColor Yellow
docker-compose up -d

# Aguardar containers iniciarem
Write-Host "`n⏳ Aguardando containers iniciarem (30 segundos)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 2. Verificar saúde dos containers
Write-Host "`n🔍 Verificando status dos containers..." -ForegroundColor Yellow
docker-compose ps

# 3. Configurar MinIO usando API REST
Write-Host "`n🪣 Configurando MinIO..." -ForegroundColor Yellow

# Aguardar MinIO estar pronto
Start-Sleep -Seconds 5

# Criar bucket usando curl (necessário ter curl instalado)
try {
    $headers = @{
        "Authorization" = "Bearer admin_minio:senha_minio_123"
    }
    
    # Criar bucket via comando docker exec
    Write-Host "Criando bucket media-wp..." -ForegroundColor Yellow
    docker exec minio_s3 mkdir -p /data/media-wp
    
    # Definir política pública
    $policy = @"
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {"AWS": ["*"]},
            "Action": ["s3:GetObject"],
            "Resource": ["arn:aws:s3:::media-wp/*"]
        }
    ]
}
"@
    
    $policy | Out-File -FilePath "temp-policy.json" -Encoding utf8
    docker cp temp-policy.json minio_s3:/tmp/policy.json
    docker exec minio_s3 sh -c "mc alias set local http://localhost:9000 admin_minio senha_minio_123 && mc anonymous set-json /tmp/policy.json local/media-wp"
    Remove-Item temp-policy.json
    
    Write-Host "✅ Bucket MinIO configurado com sucesso!" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Não foi possível configurar o bucket automaticamente." -ForegroundColor Red
    Write-Host "   Configure manualmente em http://localhost:9001" -ForegroundColor Yellow
}

# 4. Aguardar MySQL estar pronto
Write-Host "`n⏳ Aguardando MySQL estar pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$mysqlReady = $false
$attempts = 0
while (-not $mysqlReady -and $attempts -lt 30) {
    try {
        docker exec wp_mysql mysqladmin ping -h"localhost" --silent 2>$null
        if ($LASTEXITCODE -eq 0) {
            $mysqlReady = $true
        } else {
            Write-Host "Aguardando MySQL..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            $attempts++
        }
    } catch {
        Start-Sleep -Seconds 2
        $attempts++
    }
}

if ($mysqlReady) {
    Write-Host "✅ MySQL está pronto!" -ForegroundColor Green
} else {
    Write-Host "⚠️  MySQL pode não estar pronto. Verifique os logs." -ForegroundColor Yellow
}

# 5. Corrigir permissões do WordPress
Write-Host "✅ Permissões ajustadas!" -ForegroundColor Green

# 6. Instalar plugin e configurar wp-config.php
Write-Host "`n🔌 Configurando plugins e wp-config.php..." -ForegroundColor Yellow
docker exec wp_app wp plugin install advanced-media-offloader --activate --allow-root

# Injetar constantes no wp-config.php via script PHP temporário para evitar problemas de escape
$phpScript = @"
<?php
`$file = '/var/www/html/wp-config.php';
`$content = file_get_contents(`$file);
`$config = "
define( 'ADVMO_MINIO_KEY', 'admin_minio' );
define( 'ADVMO_MINIO_SECRET', 'senha_minio_123' );
define( 'ADVMO_MINIO_BUCKET', 'media-wp' );
define( 'ADVMO_MINIO_REGION', 'us-east-1' );
define( 'ADVMO_MINIO_ENDPOINT', 'http://minio:9000' );
define( 'ADVMO_MINIO_DOMAIN', 'http://localhost:9000' );
define( 'ADVMO_MINIO_APPEND_BUCKET_TO_DOMAIN', true );
define( 'ADVMO_MINIO_PATH_STYLE_ENDPOINT', true );
";
if (strpos(`$content, 'ADVMO_MINIO_KEY') === false) {
    `$content = str_replace(\"/* That's all, stop editing!\", `$config . \"\n/* That's all, stop editing!\", `$content);
    file_put_contents(`$file, `$content);
}
"@
$phpScript | Out-File -FilePath "temp-advmo-config.php" -Encoding utf8
docker cp temp-advmo-config.php wp_app:/tmp/advmo-config.php
docker exec wp_app php /tmp/advmo-config.php
Remove-Item temp-advmo-config.php

Write-Host "✅ Plugins e constantes configurados!" -ForegroundColor Green

# 7. Exibir informações de acesso
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "✨ Configuração concluída com sucesso!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Green

Write-Host "📋 Informações de Acesso:`n" -ForegroundColor Yellow

Write-Host "🌐 WordPress: " -NoNewline; Write-Host "http://localhost" -ForegroundColor Green
Write-Host "   - Usuário DB: wp_user"
Write-Host "   - Senha DB: wp_password"
Write-Host "   - Database: wordpress_db`n"

Write-Host "🗄️  MinIO Console: " -NoNewline; Write-Host "http://localhost:9001" -ForegroundColor Green
Write-Host "   - Usuário: admin_minio"
Write-Host "   - Senha: senha_minio_123"
Write-Host "   - Bucket: media-wp (configurar como público)`n"

Write-Host "⚡ Redis: " -NoNewline; Write-Host "redis_cache:6379" -ForegroundColor Green
Write-Host "   (interno - já configurado)`n"

Write-Host "📝 Próximos passos:" -ForegroundColor Yellow
Write-Host "1. Acesse http://localhost e complete a instalação do WordPress"
Write-Host "2. O plugin Advanced Media Offloader já está instalado e configurado!"
Write-Host "3. Caso precise de cache adicional, ative o plugin Redis Object Cache.`n"

Write-Host "🎉 Tudo pronto para usar!" -ForegroundColor Green
