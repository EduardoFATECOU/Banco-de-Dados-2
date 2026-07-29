#!/usr/bin/env bash
# =============================================================================
# Exemplo de PostGIS — Banco de Dados Espacial (Spatial)
#
# PostGIS é uma extensão do PostgreSQL que adiciona suporte a objetos
# geográficos (pontos, linhas, polígonos). Permite consultas espaciais
# como distância, área, interseção e buffers.
#
# Uso: chmod +x 08_postgis.sh && ./08_postgis.sh
# Requer: Docker instalado
# =============================================================================

set -e

echo "================================================================"
echo "  POSTGIS — Banco de Dados Espacial (PostgreSQL + GIS)"
echo "================================================================"
echo ""

PG_CONTAINER="postgis_banco2"
PG_PORT=5432
PG_USER="admin"
PG_PASS="senha123"
PG_DB="geodados"

# ------------------------------------------------------------------
# 1. Iniciar PostGIS
# ------------------------------------------------------------------
echo ">>> Iniciando PostGIS..."

if docker ps --format '{{.Names}}' | grep -q "^$PG_CONTAINER$"; then
    echo "    Container '$PG_CONTAINER' já está rodando."
elif docker ps -a --format '{{.Names}}' | grep -q "^$PG_CONTAINER$"; then
    echo "    Container existe mas está parado. Iniciando..."
    docker start "$PG_CONTAINER"
else
    docker run -d \
        --name "$PG_CONTAINER" \
        -p $PG_PORT:5432 \
        -e POSTGRES_USER=$PG_USER \
        -e POSTGRES_PASSWORD=$PG_PASS \
        -e POSTGRES_DB=$PG_DB \
        postgis/postgis:16-3.4
fi

echo "    Aguardando PostGIS iniciar..."
sleep 8
echo ""

# ------------------------------------------------------------------
# 2. Criar tabela espacial
# ------------------------------------------------------------------
echo ">>> Criando tabela 'cidades' com coluna geográfica..."
echo "    (geometry(Point, 4326) = ponto no sistema WGS84)"

docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" << 'SQL'
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS cidades (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    estado VARCHAR(2),
    populacao INTEGER,
    geom GEOMETRY(Point, 4326)
);

CREATE TABLE IF NOT EXISTS rodovias (
    id SERIAL PRIMARY KEY,
    nome VARCHAR(100),
    geom GEOMETRY(LineString, 4326)
);
SQL

echo "    Tabelas criadas."
echo ""

# ------------------------------------------------------------------
# 3. Inserir dados espaciais
# ------------------------------------------------------------------
echo "=============================================================="
echo "  INSERINDO DADOS GEOGRÁFICOS"
echo "=============================================================="
echo ""

# Coordenadas aproximadas de cidades brasileiras
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" << 'SQL'
-- Cidades como pontos geográficos (longitude, latitude)
INSERT INTO cidades (nome, estado, populacao, geom) VALUES
    ('São Paulo',    'SP', 12300000, ST_SetSRID(ST_MakePoint(-46.6333, -23.5505), 4326)),
    ('Rio de Janeiro','RJ',  6748000, ST_SetSRID(ST_MakePoint(-43.1729, -22.9068), 4326)),
    ('Belo Horizonte','MG',  2523000, ST_SetSRID(ST_MakePoint(-43.9378, -19.9208), 4326)),
    ('Campinas',     'SP',  1214000, ST_SetSRID(ST_MakePoint(-47.0608, -22.9058), 4326)),
    ('Curitiba',     'PR',  1949000, ST_SetSRID(ST_MakePoint(-49.2731, -25.4297), 4326));

INSERT INTO rodovias (nome, geom) VALUES
    ('BR-116 (Via Dutra)', ST_SetSRID(ST_MakeLine(
        ST_MakePoint(-46.6333, -23.5505),  -- São Paulo
        ST_MakePoint(-43.1729, -22.9068)   -- Rio de Janeiro
    ), 4326));
SQL

echo "    Cidades e rodovias inseridas."
echo ""

# ------------------------------------------------------------------
# 4. Consultas espaciais
# ------------------------------------------------------------------
echo "=============================================================="
echo "  CONSULTAS ESPACIAIS"
echo "=============================================================="
echo ""

echo ">>> 4.1. Distância entre São Paulo e Rio de Janeiro:"
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -t -A << 'SQL'
SELECT ROUND(
    ST_Distance(
        (SELECT geom FROM cidades WHERE nome = 'São Paulo')::geography,
        (SELECT geom FROM cidades WHERE nome = 'Rio de Janeiro')::geography
    ) / 1000
) || ' km' AS distancia;
SQL
echo ""

echo ">>> 4.2. Cidades a menos de 400 km de São Paulo:"
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -t -A << 'SQL'
SELECT nome, estado,
    ROUND(ST_Distance(geom::geography,
        (SELECT geom FROM cidades WHERE nome = 'São Paulo')::geography
    ) / 1000) || ' km' AS distancia
FROM cidades
WHERE nome != 'São Paulo'
  AND ST_DWithin(geom::geography,
       (SELECT geom FROM cidades WHERE nome = 'São Paulo')::geography, 400000)
ORDER BY distancia;
SQL
echo ""

echo ">>> 4.3. Cidades que cruzam a BR-116:"
docker exec -i "$PG_CONTAINER" psql -U "$PG_USER" -d "$PG_DB" -t -A << 'SQL'
SELECT c.nome, c.estado
FROM cidades c, rodovias r
WHERE r.nome = 'BR-116 (Via Dutra)'
  AND ST_Distance(c.geom::geography, r.geom::geography) < 50000;
SQL
echo ""

# ------------------------------------------------------------------
# 5. Explicação
# ------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "  EXPLICAÇÃO"
echo "=============================================================="
echo ""
echo "  PostGIS é uma extensão espacial do PostgreSQL. Adiciona:"
echo ""
echo "  Tipos geográficos:"
echo "  - POINT: ponto (latitude, longitude)"
echo "  - LINESTRING: linha (rodovia, rio)"
echo "  - POLYGON: polígono (área, município, país)"
echo "  - GEOMETRY: tipo genérico (SRID 4326 = WGS84 lat/lon)"
echo ""
echo "  Funções espaciais:"
echo "  - ST_Distance: distância entre geometrias"
echo "  - ST_DWithin: geometrias dentro de uma distância"
echo "  - ST_Area / ST_Length: área e comprimento"
echo "  - ST_Intersects / ST_Contains: relações topológicas"
echo "  - ST_Buffer: área de influência ao redor"
echo ""
echo "  Casos de uso:"
echo "  - Mapas e geolocalização"
echo "  - Logística (rotas, entregas)"
echo "  - Urbanismo (zoneamento, áreas verdes)"
echo "  - Agricultura (propriedades, biomas)"
echo "=============================================================="
echo ""

echo "Script PostGIS concluído."
