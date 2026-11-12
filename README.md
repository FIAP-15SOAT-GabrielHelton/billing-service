# billing-service

Microsserviço de **orçamento e pagamento** da Oficina Mecânica (Tech Challenge FIAP, Fase 4).
Extraído do monolito [`api`](https://github.com/FIAP-15SOAT-GabrielHelton/api) conforme a RFC-005.

## Responsabilidade

- Gera o orçamento ao receber o evento `work_order.diagnosed`.
- Envia, aprova e rejeita orçamentos (`/api/v1/quotes` e `/api/v1/webhooks/quotes`).
- Expõe `GET /api/v1/work_orders/:id/quote`, que o OS Service chama para compor o detalhe da OS.
- Publica `quote.approved` e `quote.rejected` para os outros serviços.
- Pagamento via Mercado Pago: **ainda não implementado**.

Banco próprio (PostgreSQL). A comunicação com os outros serviços é só por eventos no RabbitMQ
(exchange de tópico `oficina.events`); os IDs de OS e de cliente são guardados sem chave estrangeira.

## Executar localmente

```bash
cp .env.example .env
docker compose up          # API em http://localhost:3001, RabbitMQ em http://localhost:15673
docker compose run --rm web bin/rails db:prepare
```

O serviço `consumer` do compose (`bin/consumer`) é o processo que escuta os eventos.

## Testes

```bash
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
```

## Pendências

- Manifestos `k8s/`, `infra/` e os workflows de deploy ainda são cópias do `api` e precisam ser renomeados.
- `swagger/v1/swagger.json` precisa ser regenerado (`spec/swagger_helper.rb` ainda descreve recursos do monolito).
