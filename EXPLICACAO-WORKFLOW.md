# Explicação do Workflow de Resgate de Conversas - Grupo Áurea

## 🎯 Resumo da Lógica

Este workflow identifica e resgata conversas onde:
1. ✅ **Théo foi o último a responder** (`sender_type = 'User'` e `sender_id = 16`)
2. ✅ **Cliente não respondeu de volta** (última mensagem é do Théo)
3. ✅ **Conversa não está atribuída** a nenhum agente humano (`assignee_id IS NULL`)
4. ✅ **Tempo decorrido:** 2-2.5h ou 4-4.5h desde a última mensagem do Théo
5. ✅ **Não recebeu mensagem de resgate** anteriormente

**Objetivo:** Resgatar leads que pararam de responder ao Théo antes de completar o cadastro.

---

## 📊 Melhorias na Query SQL

### Baseado no DDL fornecido e exemplo real, implementei as seguintes otimizações:

### 1. **CTEs (Common Table Expressions) para Performance**

```sql
WITH ultima_msg_cliente AS (...)
WITH ultima_msg_bot AS (...)
WITH conversas_qualificadas AS (...)
```

**Por quê?** Organiza a lógica em etapas claras e melhora a performance com índices.

---

### 2. **Filtro por Última Mensagem do Théo**

**Critérios de busca:**
- ✅ Última mensagem foi enviada pelo **Théo** (`sender_type = 'User'` e `sender_id = 16`)
- ✅ Conversa **não está atribuída** a ninguém (`assignee_id IS NULL`)
- ✅ Mensagem é do tipo **outgoing** (`message_type = 1`)

**Por quê esse filtro?**
- Garante que o **Théo foi o último a responder**
- Cliente **não respondeu de volta** (aguardando interação)
- Nenhum **agente humano assumiu** o atendimento ainda
- Evita interferir em conversas já sendo tratadas por humanos

**Estrutura do sender:**
Segundo o DDL e exemplo fornecido:
- `sender_type = 'User'` → Usuário do sistema (bot ou agente)
- `sender_id = 16` → ID do Théo no Chatwoot
- `message_type = 1` → Mensagem outgoing (saída)

---

### 3. **Verificação Inteligente de Duplicação**

```sql
WHERE NOT EXISTS (
  SELECT 1 FROM messages m
  WHERE m.conversation_id = cq.conversation_id
    AND m.message_type = 1  -- outgoing
    AND m.created_at > cq.ultima_msg_incoming
    AND (
      m.content ILIKE '%Percebi que iniciamos uma conversa%'
      OR m.content ILIKE '%você não retornou ainda%'
      OR m.content ILIKE '%ainda tem interesse em prosseguir%'
    )
)
```

**O que faz:**
- Verifica se já enviamos uma mensagem de resgate após a última mensagem do cliente
- Procura por trechos das mensagens de 2h e 4h
- Evita spam ao cliente

---

### 4. **DISTINCT ON para Performance**

```sql
SELECT DISTINCT ON (m.conversation_id)
  m.conversation_id,
  m.created_at,
  m.sender_type,
  m.sender_id
FROM messages m
ORDER BY m.conversation_id, m.created_at DESC
```

**O que faz:**
- Pega apenas a **última mensagem de cada conversa**
- Usa `DISTINCT ON` do PostgreSQL (super eficiente!)
- Ordena por data decrescente para pegar a mais recente

---

### 5. **Uso de Índices Existentes**

A query aproveita os índices do DDL:
- ✅ `index_messages_on_conversation_id` (linha 53 do DDL)
- ✅ `index_messages_on_created_at` (linha 54 do DDL)
- ✅ `index_conversations_on_status_and_account_id` (linha 119 do DDL)

---

## 🎯 Fluxo de Execução

### Passo a Passo:

1. **Trigger (A cada 1 hora)**
   - Executa automaticamente a cada hora
   - Captura tanto o momento de 2h quanto de 4h

2. **Busca SQL**
   - Identifica conversas abertas (`status = 0`)
   - Calcula tempo desde última mensagem do **cliente**
   - Filtra apenas conversas entre 2-2.5h ou 4-4.5h
   - Remove conversas que já receberam resgate

3. **Loop por Conversa**
   - Processa cada conversa individualmente
   - Evita sobrecarga no Chatwoot

4. **Switch por Tempo**
   - Verifica campo `categoria_tempo`
   - Direciona para mensagem de 2h ou 4h

5. **Envio de Mensagem**
   - Chama API do Chatwoot
   - Envia mensagem personalizada

6. **Wait (Aguardar 3s)**
   - Rate limiting
   - Evita bloqueio por spam

7. **Retorna ao Loop**
   - Processa próxima conversa

---

## 📝 Campos Retornados pela Query

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `conversation_id` | int4 | ID da conversa |
| `account_id` | int4 | ID da conta (necessário para API) |
| `display_id` | int4 | Display ID (necessário para API) |
| `inbox_id` | int4 | ID da inbox |
| `contact_id` | int8 | ID do contato |
| `assignee_id` | int4 | ID do agente atribuído (NULL = não atribuído) |
| `ultima_msg_theo_at` | timestamp | Data/hora da última msg do Théo |
| `ultima_msg_content` | text | Conteúdo da última mensagem |
| `horas_desde_ultima_msg_theo` | numeric | Horas desde última msg do Théo |
| `categoria_tempo` | text | `2_horas` ou `4_horas` |

---

## ⚙️ Configurações Importantes

### Credenciais Necessárias:

1. **PostgreSQL** (`Cordex.ai - Chatwoot`)
   - Host: [seu_host]
   - Database: [seu_database]
   - User: [seu_user]
   - Password: [seu_password]

2. **Chatwoot API** (`Chatwoot - Flora`)
   - Header: `api_access_token`
   - Value: [seu_token]

### Ajustes Recomendados:

- **Intervalo do Trigger:** 1 hora (padrão)
- **Limite de Conversas:** 50 por execução (ajustar conforme volume)
- **Wait Time:** 3 segundos entre envios
- **Janelas de Tempo:**
  - 2h: entre 2.0h e 2.5h
  - 4h: entre 4.0h e 4.5h

---

## 🚀 Próximos Passos

1. Importar o JSON no n8n
2. Configurar credenciais
3. Testar com workflow desativado primeiro (Execute Workflow)
4. Validar mensagens enviadas
5. Ativar workflow

---

## 📊 Monitoramento

Recomendo criar um dashboard para monitorar:
- Quantidade de resgates enviados por dia
- Taxa de resposta após resgate (2h vs 4h)
- Conversões após resgate
- Conversas que não responderam mesmo após 4h

---

## ⚠️ Considerações Importantes

### Status da Conversa:
- `0` = open (aberta)
- `1` = resolved (resolvida)
- `2` = pending (pendente)

Apenas conversas com `status = 0` recebem resgate.

### Message Types:
- `0` = incoming (cliente)
- `1` = outgoing (bot/agente)
- `2` = activity (sistema)

### Horário Comercial:
O workflow roda 24/7, mas você pode adicionar um filtro adicional para enviar apenas em horário comercial se desejar.

Exemplo de filtro adicional na query:
```sql
AND EXTRACT(HOUR FROM NOW()) BETWEEN 8 AND 18  -- 8h às 18h
AND EXTRACT(DOW FROM NOW()) BETWEEN 1 AND 5     -- Segunda a Sexta
```

---

**Desenvolvido para Grupo Áurea** 💙
*Atendimento humanizado com tecnologia inteligente*
