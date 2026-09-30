#!/bin/bash

CONTAINER_NAME="redis_banco2"

echo "=== CRUD DE ALUNOS COM REDIS ==="
echo "1. Cadastrar/Atualizar Aluno (CREATE/UPDATE)"
echo "2. Buscar Aluno (READ)"
echo "3. Excluir Aluno (DELETE)"
echo -n "Escolha uma opção (1-3): "
read OPCAO

case $OPCAO in
    1)
        echo -n "Digite o número da chamada: "
        read NUMERO
        echo -n "Digite o nome do aluno: "
        read NOME
        
        # Salva no Redis: Chave="aluno:NUMERO" | Valor="NOME"
        docker exec -i "$CONTAINER_NAME" redis-cli SET "aluno:$NUMERO" "$NOME" > /dev/null
        echo "Aluno cadastrado com sucesso!"
        ;;
    2)
        echo -n "Digite o número da chamada para buscar: "
        read NUMERO
        
        # Busca o valor da chave no Redis
        RESULTADO=$(docker exec -i "$CONTAINER_NAME" redis-cli GET "aluno:$NUMERO")
        
        if [ -z "$RESULTADO" ]; then
            echo "Aluno não encontrado!"
        else
            echo "Nome do Aluno: $RESULTADO"
        fi
        ;;
    3)
        echo -n "Digite o número da chamada para excluir: "
        read NUMERO
        
        # Deleta a chave do Redis
        docker exec -i "$CONTAINER_NAME" redis-cli DEL "aluno:$NUMERO" > /dev/null
        echo "Aluno excluído com sucesso!"
        ;;
    *)
        echo "Opção inválida!"
        ;;
esac