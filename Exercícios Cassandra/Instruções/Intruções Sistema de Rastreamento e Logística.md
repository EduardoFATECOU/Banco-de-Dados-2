Sistema de Rastreamento e Logística de Entregas (Delivery Geo-Routing).

O script simula a posição de motoboys e o endereço de entrega em uma região utilizando coordenadas geográficas (Latitude e Longitude). A lógica matemática implementada via Bash utiliza a Fórmula de Haversine (Simplificada para Distância Euclidiana Plana) para calcular a distância em linha reta entre os pontos e determinar se a entrega está "Próxima", "Moderada" ou "Muito Distante", além de estimar o tempo de chegada.

Como estamos trabalhando com pontos flutuantes no Debian 13, utilizaremos novamente o bc combinado com a biblioteca matemática do Linux (bc -l) para calcular raízes quadradas (sqrt).

Cenário de teste guiado para você simular:

1. Imagine que seu cliente está no centro de uma cidade. Vamos usar coordenadas reais de exemplo (padrão de São Paulo, mas funciona com qualquer número decimal):
2. Acesse a Opção 1 e cadastre dois entregadores:
- Entregador 1: ID MOTO\_01, Nome Carlos, Lat -23.5500, Lon -46.6330 (Bem no centro).
- Entregador 2: ID MOTO\_02, Nome Ana, Lat -23.5900, Lon -46.6700 (Bairro mais afastado).
3. Acesse a Opção 2 para fazer o pedido de um cliente que está na latitude -23.5520 e longitude -46.6360.
4. Veja a mágica acontecer: O Bash vai extrair a localização de ambos de dentro do Cassandra, aplicar a fórmula de Pitágoras corrigida para graus métricos e apontará que o Carlos está a cerca de 0.40 KM (Excelente), enquanto a Ana estará a mais de 5.90 KM de distância.

