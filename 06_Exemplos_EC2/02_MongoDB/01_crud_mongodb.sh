#!/usr/bin/env bash
# =============================================================================
# Exemplo de operações CRUD no MongoDB usando mongosh
# Database: escola | Coleção: alunos
#
# Uso: chmod +x 01_crud_mongodb.sh && ./01_crud_mongodb.sh
# Requer: mongosh instalado e MongoDB rodando
# =============================================================================

set -e

echo "================================================================"
echo "  MONGODB — Operações CRUD (Create, Read, Update, Delete)"
echo "  Database: escola | Coleção: alunos"
echo "================================================================"
echo ""

# Comandos MongoDB executados via mongosh
mongosh << 'EOF'
// ==========================================================================
// 1. CREATE — Inserir documentos
// ==========================================================================
print("================================================================");
print("  1. CREATE — Inserindo 5 alunos...");
print("================================================================");

// Seleciona (ou cria) o banco "escola"
use("escola");

// Insere 5 documentos na coleção "alunos"
db.alunos.insertMany([
    {
        nome: "Ana Beatriz",
        idade: 20,
        curso: "Ciência da Computação",
        notas: [8.5, 9.0, 7.5],
        endereco: { cidade: "São Paulo", estado: "SP" }
    },
    {
        nome: "Carlos Eduardo",
        idade: 22,
        curso: "Engenharia de Software",
        notas: [6.0, 7.5, 8.0],
        endereco: { cidade: "Campinas", estado: "SP" }
    },
    {
        nome: "Marina Oliveira",
        idade: 19,
        curso: "Sistemas de Informação",
        notas: [9.5, 9.0, 8.5],
        endereco: { cidade: "Belo Horizonte", estado: "MG" }
    },
    {
        nome: "Rafael Lima",
        idade: 21,
        curso: "Ciência da Computação",
        notas: [7.0, 6.5, 7.0],
        endereco: { cidade: "Rio de Janeiro", estado: "RJ" }
    },
    {
        nome: "Juliana Costa",
        idade: 23,
        curso: "Engenharia de Software",
        notas: [10.0, 9.5, 9.0],
        endereco: { cidade: "São Paulo", estado: "SP" }
    }
]);

print("\nDocumentos inseridos com sucesso!\n");

// ==========================================================================
// 2. READ — Consultar documentos
// ==========================================================================
print("================================================================");
print("  2. READ — Consultas...");
print("================================================================");

// 2.1 Listar todos os alunos
print("\n--- Todos os alunos ---");
db.alunos.find().forEach(function(aluno) {
    print(aluno.nome + " | " + aluno.curso + " | Média: " +
          (aluno.notas.reduce((a, b) => a + b, 0) / aluno.notas.length).toFixed(2));
});

// 2.2 Filtrar por curso
print("\n--- Alunos de Ciência da Computação ---");
const alunosCC = db.alunos.find({ curso: "Ciência da Computação" });
alunosCC.forEach(a => print(a.nome + " - " + a.endereco.cidade));

// 2.3 Filtrar por cidade
print("\n--- Alunos de São Paulo (cidade) ---");
db.alunos.find({ "endereco.cidade": "São Paulo" }).forEach(a => print(a.nome));

// 2.4 Alunos com nota média > 8.0 (usando expressão $expr)
print("\n--- Alunos com média > 8.0 ---");
db.alunos.find({
    $expr: {
        $gt: [
            { $avg: "$notas" },
            8.0
        ]
    }
}).forEach(a => {
    const media = a.notas.reduce((x, y) => x + y, 0) / a.notas.length;
    print(a.nome + " - Média: " + media.toFixed(2));
});

// 2.5 Contar documentos
print("\n--- Total de alunos: " + db.alunos.countDocuments() + " ---");

// ==========================================================================
// 3. UPDATE — Atualizar documentos
// ==========================================================================
print("\n================================================================");
print("  3. UPDATE — Atualizando dados...");
print("================================================================");

// Atualiza a nota do aluno Carlos Eduardo
print("\nAtualizando nota do Carlos Eduardo...");
db.alunos.updateOne(
    { nome: "Carlos Eduardo" },
    { $set: { notas: [7.0, 8.5, 9.0] } }
);

// Adiciona um campo "ativo" para todos os alunos
print("Adicionando campo 'ativo: true' para todos...");
db.alunos.updateMany(
    {},
    { $set: { ativo: true } }
);

// Verifica a atualização
print("\nCarlos Eduardo após atualização:");
const carlos = db.alunos.findOne({ nome: "Carlos Eduardo" });
print(JSON.stringify(carlos, null, 2));

// ==========================================================================
// 4. DELETE — Remover documentos
// ==========================================================================
print("\n================================================================");
print("  4. DELETE — Removendo um aluno...");
print("================================================================");

// Deleta o aluno Rafael Lima
print("\nRemovendo Rafael Lima...");
db.alunos.deleteOne({ nome: "Rafael Lima" });

print("Total de alunos após deleção: " + db.alunos.countDocuments());

// ==========================================================================
// 5. LISTAR TODOS OS ALUNOS (final)
// ==========================================================================
print("\n================================================================");
print("  ESTADO FINAL DA COLEÇÃO");
print("================================================================");
db.alunos.find().forEach(function(aluno) {
    const media = (aluno.notas.reduce((a, b) => a + b, 0) / aluno.notas.length).toFixed(2);
    print("  " + aluno.nome + " | " + aluno.curso + " | Média: " + media + " | Ativo: " + aluno.ativo);
});

print("\nOperações CRUD concluídas com sucesso!");
EOF

echo ""
echo "Script finalizado."
