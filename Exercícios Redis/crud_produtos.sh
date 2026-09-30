#!/bin/sh

CONTAINER_NAME="redis_banco2"

echo "=== SISTEMA DE PRODUTOS (REDIS) ==="
echo "1. Cadastrar Preço"
echo "2. Consultar Preço"
echo "3. Remover Produto"
echo -n "Escolha uma opção: "
read OPCAO

case $OPCAO in
    1)
        echo -n "Nome do produto (ex: teclado): "
        read PRODUTO
        echo -n "Preço (ex: 150.00): "
        read PRECO
        
        # Salva no Redis: produto:teclado -> 150.00
        docker exec -i "$CONTAINER_NAME" redis-cli SET "produto:$PRODUTO" "$PRECO" > /dev/null
        echo "Preço cadastrado!"
        ;;
    2)
        echo -n "Qual produto deseja consultar?: "
        read PRODUTO
        
        PRECO_ATUAL=$(docker exec -i "$CONTAINER_NAME" redis-cli GET "produto:$PRODUTO")
        
        if [ -z "$PRECO_ATUAL" ]; then
            echo "Produto não cadastrado."
        else
            echo "O preço do(a) $PRODUTO é: R$ $PRECO_ATUAL"
        fi
        ;;
    3)
        echo -n "Nome do produto para remover: "
        read PRODUTO
        
        docker exec -i "$CONTAINER_NAME" redis-cli DEL "produto:$PRODUTO" > /dev/null
        echo "Produto removido do catálogo."
        ;;
    *)
        echo "Opção inválida."
        ;;
esac