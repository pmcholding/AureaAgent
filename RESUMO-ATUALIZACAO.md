# 🔄 Atualização do Workflow - Resgate de Conversas

## ✅ Mudanças Implementadas

### Filtro Corrigido ✨

**ANTES (incorreto):**
- Buscava conversas onde cliente foi o último a responder
- Calculava tempo baseado em `updated_at` da conversa

**AGORA (correto):**
- ✅ Busca conversas onde **Théo foi o último a responder**
- ✅ Filtra apenas conversas **não atribuídas** a nenhum agente
- ✅ Usa `sender_type = 'User'` e `sender_id = 16` (Théo)
- ✅ Calcula tempo baseado na **última mensagem do Théo**

---

## 🎯 Lógica Atualizada

### Critérios de Seleção:

1. **Última mensagem foi do Théo**
   - `sender_type = 'User'`
   - `sender_id = 16`
   - `message_type = 1` (outgoing)

2. **Conversa aberta e não atribuída**
   - `status = 0` (aberta)
   - `assignee_id IS NULL` (não atribuída)

3. **Tempo desde última mensagem do Théo**
   - 2-2.5 horas → Mensagem de resgate 1
   - 4-4.5 horas → Mensagem de resgate 2

4. **Não recebeu resgate anteriormente**
   - Verifica se já enviou mensagens de resgate
   - Evita spam ao cliente

---

## 📊 Exemplo Real

Baseado na mensagem ID 58929:

```
sender_type: "User"
sender_id: 16
message_type: 1 (outgoing)
content: "Entendo, Gabriel!

Trabalhamos com *empréstimos de até R$ 1.000,00.*

Podemos seguir com um valor dentro dessa faixa? Por exemplo, R$ 800,00 ou R$ 1.000,00? 💰"
```

Se Gabriel não responder em:
- **2 horas** → Envia mensagem de resgate 1
- **4 horas** → Envia mensagem de resgate 2

---

## 🧪 Como Testar a Query

### 1. Teste Direto no Banco

```bash
# Conecte ao PostgreSQL
psql -h [host] -U [user] -d [database]

# Execute a query
\i /caminho/para/query-resgate-conversas.sql
```

### 2. Teste no n8n (sem ativar)

1. Importe o workflow
2. Clique em **Execute Workflow** (não ative!)
3. Verifique os resultados retornados
4. Valide os campos:
   - `sender_id` deve ser **16**
   - `assignee_id` deve ser **NULL**
   - `categoria_tempo` deve ser **2_horas** ou **4_horas**

### 3. Teste de Envio (controlado)

1. Ajuste o LIMIT da query para **1**
2. Execute o workflow manualmente
3. Verifique no Chatwoot se a mensagem foi enviada corretamente
4. Confirme que não duplicou mensagens

---

## 📁 Arquivos Atualizados

| Arquivo | Descrição |
|---------|-----------|
| `n8n-workflow-resgate-conversas.json` | Workflow completo para importar no n8n |
| `query-resgate-conversas.sql` | Query SQL isolada para testes |
| `EXPLICACAO-WORKFLOW.md` | Documentação técnica detalhada |
| `RESUMO-ATUALIZACAO.md` | Este arquivo (resumo das mudanças) |

---

## ⚙️ Configurações Necessárias

### 1. Credenciais PostgreSQL
```
Host: [seu_host]
Database: [seu_database]
User: [seu_user]
Password: [seu_password]
```

### 2. Credenciais Chatwoot
```
Header: api_access_token
Value: [seu_token_api]
```

### 3. Configurar sender_id

**IMPORTANTE:** Confirme o `sender_id` do Théo no seu banco:

```sql
SELECT DISTINCT sender_id, sender_type
FROM messages
WHERE sender_type = 'User'
  AND message_type = 1
ORDER BY sender_id;
```

Se o `sender_id` do Théo for diferente de **16**, ajuste na linha 37 da query:

```sql
AND um.sender_id = 16  -- AJUSTE AQUI se necessário
```

---

## 🔍 Validações Recomendadas

### Antes de Ativar:

- [ ] Confirmar `sender_id` do Théo
- [ ] Testar query no banco de dados
- [ ] Executar workflow manualmente (1 conversa apenas)
- [ ] Verificar mensagem enviada no Chatwoot
- [ ] Confirmar que não duplicou
- [ ] Validar horários (2h e 4h)

### Após Ativar:

- [ ] Monitorar primeiras execuções
- [ ] Verificar taxa de resposta
- [ ] Ajustar mensagens se necessário
- [ ] Acompanhar conversões

---

## 📊 Monitoramento

### Queries úteis para acompanhamento:

```sql
-- Quantidade de resgates enviados hoje
SELECT COUNT(*)
FROM messages
WHERE sender_id = 16
  AND created_at >= CURRENT_DATE
  AND (
    content ILIKE '%Percebi que iniciamos uma conversa%'
    OR content ILIKE '%você não retornou ainda%'
  );

-- Taxa de resposta após resgate
WITH resgates AS (
  SELECT
    conversation_id,
    created_at as resgate_at
  FROM messages
  WHERE sender_id = 16
    AND created_at >= CURRENT_DATE - INTERVAL '7 days'
    AND (
      content ILIKE '%Percebi que iniciamos uma conversa%'
      OR content ILIKE '%você não retornou ainda%'
    )
)
SELECT
  COUNT(DISTINCT r.conversation_id) as total_resgates,
  COUNT(DISTINCT CASE
    WHEN EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = r.conversation_id
        AND m.created_at > r.resgate_at
        AND m.message_type = 0  -- cliente respondeu
    ) THEN r.conversation_id
  END) as responderam,
  ROUND(100.0 * COUNT(DISTINCT CASE
    WHEN EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = r.conversation_id
        AND m.created_at > r.resgate_at
        AND m.message_type = 0
    ) THEN r.conversation_id
  END) / NULLIF(COUNT(DISTINCT r.conversation_id), 0), 2) as taxa_resposta_pct
FROM resgates r;
```

---

## 🚀 Próximos Passos

1. **Testar a query** no banco de dados
2. **Validar sender_id** do Théo
3. **Importar workflow** no n8n
4. **Configurar credenciais**
5. **Testar manualmente** (1 conversa)
6. **Ativar workflow**
7. **Monitorar resultados**

---

## 💡 Dicas

- **Horário Comercial:** Considere adicionar filtro para enviar apenas das 9h às 18h
- **Mensagens:** Ajuste o tom conforme feedback dos clientes
- **Intervalo:** Considere adicionar um terceiro resgate após 8h se necessário
- **A/B Test:** Teste diferentes mensagens para ver qual performa melhor

---

**Desenvolvido para Grupo Áurea** 💙

*"Resgatar leads, transformar oportunidades"*
