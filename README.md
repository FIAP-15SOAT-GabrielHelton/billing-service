# Billing Service — 15SOAT - Fase 4 - Tech Challenge - Grupo 183

Microsserviço de **orçamento e pagamento** da Oficina Mecânica. Gera o orçamento de cada Ordem de Serviço, registra a aprovação ou rejeição do cliente e cobra pelo **Mercado Pago** quando a execução termina.

Faz parte de um conjunto de três microsserviços coordenados por uma Saga coreografada. A visão geral — arquitetura, diagrama e todos os repositórios — está no README do [`os-service`](https://github.com/FIAP-15SOAT-GabrielHelton/os-service#arquitetura).

## Responsabilidade

- Gera o orçamento a partir dos itens e valores recebidos no evento `work_order.diagnosed`.
- Envia, aprova e rejeita orçamentos, pela API autenticada ou pelo webhook de aprovação externa.
- Cria a cobrança no Mercado Pago quando a execução termina e confirma o pagamento pelo webhook.
- Responde ao OS Service o orçamento de uma OS (`GET /api/v1/work_orders/:id/quote`) — a única chamada REST entre serviços.

**Banco próprio:** PostgreSQL, com o usuário `billing_service`, que só enxerga os bancos deste serviço. Os IDs de OS e de cliente são guardados sem chave estrangeira; nenhum outro serviço acessa este banco.

## Papel na Saga

A Saga é **coreografada**: cada serviço reage a eventos e publica os seus, sem orquestrador central. A justificativa e o diagrama completo estão no [README do `os-service`](https://github.com/FIAP-15SOAT-GabrielHelton/os-service#saga) e na [RFC-005](https://github.com/FIAP-15SOAT-GabrielHelton/os-service/blob/main/docs/fase4/RFC-005-microsservicos-e-saga.md).

| Consome | Reação |
| :--- | :--- |
| `work_order.diagnosed` | Cria o orçamento da OS |
| `execution.completed` | Cria a cobrança no Mercado Pago e guarda o link de pagamento |
| `work_order.cancelled` | **Compensação:** cancela o orçamento |

| Publica | Quando |
| :--- | :--- |
| `quote.approved` | O cliente aprova o orçamento |
| `quote.rejected` | O cliente rejeita o orçamento |
| `payment.approved` | O Mercado Pago confirma o pagamento |

Status do orçamento: `created → sent → approved → paid`, com as saídas `rejected` e `cancelled`.

## Pagamento (Mercado Pago)

1. Ao receber `execution.completed`, o serviço cria uma preferência de pagamento (Checkout Pro) e expõe o link em `payment_url` no orçamento.
2. O cliente paga pelo link.
3. O Mercado Pago chama `POST /api/v1/webhooks/mercado_pago`. O corpo da notificação **nunca é tomado como verdade**: o serviço busca o pagamento na API do Mercado Pago pelo id e só então decide.
4. Se o pagamento está aprovado e cobre o total do orçamento, o orçamento vira `paid` e o evento `payment.approved` libera a entrega no OS Service. Notificações repetidas não geram efeito duplicado.

Se o pagamento não é aprovado, não há o que compensar: a OS continua aguardando pagamento e o cliente tenta de novo.

## Execução local

```bash
cp .env.example .env
docker compose up -d --wait db rabbitmq
docker compose run --rm web bin/rails db:prepare
docker compose up web consumer
```

A API sobe em `http://localhost:3001`. O serviço `consumer` (`bin/consumer`) é o processo que escuta os eventos da Saga. Para gerar cobranças, preencha `MERCADO_PAGO_ACCESS_TOKEN` no `.env` com o token de uma conta de teste.

## Documentação da API

- Swagger UI: `http://localhost:3001/api-docs`.
- Spec OpenAPI versionada: [`swagger/v1/swagger.json`](swagger/v1/swagger.json).

## Testes e qualidade

```bash
docker compose run --rm -e RAILS_ENV=test -e COVERAGE=1 web bundle exec rspec
```

- RSpec com cobertura mínima de 80% exigida pelo SimpleCov (hoje acima de 95%). O cliente do Mercado Pago é testado sem chamadas reais.
- O fluxo completo em BDD, que atravessa os três serviços, fica no [`os-service`](https://github.com/FIAP-15SOAT-GabrielHelton/os-service/blob/main/spec/features/fluxo_da_ordem_de_servico.feature).
- SonarQube Cloud: [painel do projeto](https://sonarcloud.io/project/overview?id=FIAP-15SOAT-GabrielHelton_billing-service), com quality gate no CI.

## CI/CD

- **CI** ([`ci.yml`](.github/workflows/ci.yml)): a cada PR, roda RuboCop, os testes e a análise do SonarQube. A `main` é protegida: só recebe código por PR com `lint` e `test` verdes.
- **CD** ([`cd_deploy.yml`](.github/workflows/cd_deploy.yml)): publica a imagem e implanta no EKS — migrations, `web`, `jobs`, `consumer`, Service e HPA (manifests em [`k8s/`](k8s/)). Depois que o endereço público existe, o deploy configura sozinho a URL do webhook do Mercado Pago. O disparo é manual, pelas credenciais temporárias da AWS Academy, normalmente via [`deploy-orchestrator-fase4`](https://github.com/FIAP-15SOAT-GabrielHelton/deploy-orchestrator-fase4).

## Observabilidade

New Relic (APM com rastreamento distribuído), configurado em [`config/newrelic.yml`](config/newrelic.yml).

## Limitações conhecidas

- A integração usa a **API de Preferences** do Mercado Pago, que o painel informa que será descontinuada em favor da API de Orders. Foi mantida por ser a do Checkout Pro disponível para a conta de teste; a migração fica como próximo passo.
- O webhook não valida a assinatura `x-signature`. O risco é contido porque o corpo da notificação não é usado como fonte de verdade — o pagamento é sempre consultado na API do Mercado Pago.
- O endereço público do ambiente da AWS Academy é HTTP, sem certificado.
