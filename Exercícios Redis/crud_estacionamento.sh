#!/bin/sh

CONTAINER_NAME="redis_banco2"

echo "=== CONTROLE DE ESTACIONAMENTO ==="
echo "1. Registrar Entrada de Veículo"
echo "2. Verificar se Veículo está no Pátio"
echo "3. Registrar Saída (Liberar Vaga)"
echo -n "Opção: "
read OPCAO

case $OPCAO in
    1)
        echo -n "Digite a Placa do Carro (ex: ABC1234): "
        read PLACA
        echo -n "Modelo/Cor (ex: Gol Quadrado Azul): "
        read DETALHES
        
        # Salva no Redis
        docker exec -i "$CONTAINER_NAME" redis-cli SET "vaga:$PLACA" "$DETALHES" > /dev/null
        echo "Entrada liberada! Carro estacionado."
        ;;
    2)
        echo -n "Digite a Placa para buscar: "
        read PLACA
        
        CARRO=$(docker exec -i "$CONTAINER_NAME" redis-cli GET "vaga:$PLACA")
        
        if [ -z "$CARRO" ]; then
            echo "Este veículo NÃO está no estacionamento."
        else
            echo "Veículo Localizado: $CARRO"
        fi
        ;;
    3)
        echo -n "Digite a Placa do veículo saindo: "
        read PLACA
        
        # Remove do Redis
        docker exec -i "$CONTAINER_NAME" redis-cli DEL "vaga:$PLACA" > /dev/null
        echo "Saída registrada. Vaga liberada!"
        ;;
    *)
        echo "Opção inválida."
        ;;
esac