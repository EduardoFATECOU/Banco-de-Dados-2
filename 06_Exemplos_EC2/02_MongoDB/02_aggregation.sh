#!/usr/bin/env bash
# =============================================================================
# Exemplo de pipeline de agregação no MongoDB
# Database: loja | Coleção: vendas
#
# O pipeline de agregação processa documentos em estágios sequenciais,
# similar a um "pipe" no Unix. Cada estágio transforma os dados.
#
# Uso: chmod +x 02_aggregation.sh && ./02_aggregation.sh
# Requer: mongosh instalado e MongoDB rodando
# =============================================================================

set -e

echo "================================================================"
echo "  MONGODB — Pipeline de Agregação"
echo "  Database: loja | Coleção: vendas"
echo "================================================================"
echo ""

mongosh << 'EOF'
// ==========================================================================
// 1. Criar e popular a coleção "vendas"
// ==========================================================================
print("================================================================");
print("  1. Criando coleção 'vendas' com documentos de exemplo...");
print("================================================================");

use("loja");

// Limpa dados anteriores (se existirem)
db.vendas.drop();

// Insere documentos de vendas
db.vendas.insertMany([
    { produto: "Notebook",   quantidade: 2,  preco: 4500.00, data: new Date("2025-01-15"), vendedor: "Ana" },
    { produto: "Mouse",      quantidade: 10, preco: 150.00,  data: new Date("2025-01-16"), vendedor: "Carlos" },
    { produto: "Teclado",    quantidade: 5,  preco: 200.00,  data: new Date("2025-01-16"), vendedor: "Ana" },
    { produto: "Monitor",    quantidade: 3,  preco: 1200.00, data: new Date("2025-01-17"), vendedor: "Marina" },
    { produto: "Notebook",   quantidade: 1,  preco: 4500.00, data: new Date("2025-01-18"), vendedor: "Carlos" },
    { produto: "Webcam",     quantidade: 8,  preco: 300.00,  data: new Date("2025-01-18"), vendedor: "Ana" },
    { produto: "Mouse",      quantidade: 6,  preco: 150.00,  data: new Date("2025-01-19"), vendedor: "Marina" },
    { produto: "Monitor",    quantidade: 2,  preco: 1200.00, data: new Date("2025-01-20"), vendedor: "Ana" },
    { produto: "Teclado",    quantidade: 4,  preco: 200.00,  data: new Date("2025-01-20"), vendedor: "Carlos" },
    { produto: "Notebook",   quantidade: 3,  preco: 4500.00, data: new Date("2025-01-21"), vendedor: "Marina" }
]);

print("Documentos inseridos: " + db.vendas.countDocuments());
print("");

// ==========================================================================
// 2. ESTÁGIO $match — Filtrar documentos (similar ao WHERE do SQL)
// ==========================================================================
print("================================================================");
print("  2. ESTÁGIO \$match — Filtrando vendas de Notebook...");
print("================================================================");

const matchStage = [
    { $match: { produto: "Notebook" } }
];

print("\nDocumentos que passaram pelo \$match:");
db.vendas.aggregate(matchStage).forEach(v => {
    print("  " + v.produto + " | Qtd: " + v.quantidade + " | Total: R$ " + (v.quantidade * v.preco).toFixed(2));
});
print("");

// ==========================================================================
// 3. ESTÁGIO $group — Agrupar e calcular (similar ao GROUP BY + funções)
// ==========================================================================
print("================================================================");
print("  3. ESTÁGIO \$group — Agrupando por produto...");
print("================================================================");

const groupStage = [
    {
        $group: {
            _id: "$produto",
            quantidadeTotal: { $sum: "$quantidade" },
            valorTotal: { $sum: { $multiply: ["$quantidade", "$preco"] } },
            precoMedio: { $avg: "$preco" },
            vendas: { $sum: 1 }
        }
    }
];

print("\nVendas agrupadas por produto:");
db.vendas.aggregate(groupStage).forEach(g => {
    print("  " + g._id + " | Qtd: " + g.quantidadeTotal +
          " | Total: R$ " + g.valorTotal.toFixed(2) +
          " | Preço médio: R$ " + g.precoMedio.toFixed(2) +
          " | Vendas: " + g.vendas);
});
print("");

// ==========================================================================
// 4. ESTÁGIO $sort — Ordenar resultados
// ==========================================================================
print("================================================================");
print("  4. ESTÁGIO \$sort — Ordenando por valor total (decrescente)...");
print("================================================================");

const sortStage = [
    {
        $group: {
            _id: "$produto",
            valorTotal: { $sum: { $multiply: ["$quantidade", "$preco"] } },
            quantidadeTotal: { $sum: "$quantidade" }
        }
    },
    { $sort: { valorTotal: -1 } }
];

print("\nProdutos ordenados por valor total (maior para menor):");
db.vendas.aggregate(sortStage).forEach((g, i) => {
    print("  " + (i + 1) + ". " + g._id + " — R$ " + g.valorTotal.toFixed(2));
});
print("");

// ==========================================================================
// 5. ESTÁGIO $project — Projetar campos (similar ao SELECT)
// ==========================================================================
print("================================================================");
print("  5. ESTÁGIO \$project — Projetando campos calculados...");
print("================================================================");

const projectStage = [
    {
        $project: {
            _id: 0,
            produto: 1,
            quantidade: 1,
            precoUnitario: "$preco",
            valorTotal: { $multiply: ["$quantidade", "$preco"] },
            data: { $dateToString: { format: "%Y-%m-%d", date: "$data" } },
            mes: { $month: "$data" },
            ano: { $year: "$data" }
        }
    }
];

print("\nVendas com campos projetados:");
db.vendas.aggregate(projectStage).forEach(v => {
    print("  " + v.data + " | " + v.produto + " | " + v.quantidade +
          " x R$ " + v.precoUnitario.toFixed(2) +
          " = R$ " + v.valorTotal.toFixed(2));
});
print("");

// ==========================================================================
// 6. PIPELINE COMPLETO — Todos os estágios combinados
// ==========================================================================
print("================================================================");
print("  6. PIPELINE COMPLETO — Exemplo real");
print("================================================================");

const pipelineCompleto = [
    // Filtra apenas vendas de 2025
    { $match: { data: { $gte: new Date("2025-01-01"), $lt: new Date("2026-01-01") } } },
    // Agrupa por produto e vendedor
    {
        $group: {
            _id: { produto: "$produto", vendedor: "$vendedor" },
            quantidadeTotal: { $sum: "$quantidade" },
            valorTotal: { $sum: { $multiply: ["$quantidade", "$preco"] } }
        }
    },
    // Ordena por valor total decrescente
    { $sort: { valorTotal: -1 } },
    // Projeta resultado final
    {
        $project: {
            _id: 0,
            produto: "$_id.produto",
            vendedor: "$_id.vendedor",
            quantidadeTotal: 1,
            valorTotal: 1
        }
    },
    // Salva o resultado em uma nova coleção
    { $out: "resumo_vendas" }
];

print("\nExecutando pipeline completo e salvando em 'resumo_vendas'...");
db.vendas.aggregate(pipelineCompleto);

print("\nResumo de vendas por produto e vendedor:");
db.resumo_vendas.find().forEach(r => {
    print("  " + r.vendedor + " vendeu " + r.quantidadeTotal +
          " unidade(s) de " + r.produto +
          " — Total: R$ " + r.valorTotal.toFixed(2));
});

print("\n================================================================");
print("  Agregação concluída! Resultados salvos em 'resumo_vendas'.");
print("================================================================");
EOF
