-- Query para Resgate de Conversas - Grupo Áurea
-- Busca conversas onde Théo foi o último a responder e cliente não retornou
-- ATUALIZADO: Intervalos de 15 minutos e 2 horas
-- CORRIGIDO: Lógica separada para cada tipo de resgate, evitando duplicatas

WITH
-- Última mensagem NORMAL do Théo (exclui mensagens de resgate)
ultima_msg_normal AS (
  SELECT DISTINCT ON (m.conversation_id)
    m.conversation_id,
    m.created_at as ultima_msg_at,
    m.content
  FROM messages m
  WHERE m.message_type = 1  -- outgoing
    AND m.sender_type = 'User'
    AND m.sender_id = 16  -- Théo
    AND NOT (
      m.content ILIKE '%Sim → para prosseguir com um especialista%'
      OR m.content ILIKE '%Seguir → para continuar com um especialista%'
    )
  ORDER BY m.conversation_id, m.created_at DESC
),

-- Última mensagem de RESGATE 1 (15 min) - para calcular intervalo do resgate 2
ultima_msg_resgate1 AS (
  SELECT DISTINCT ON (m.conversation_id)
    m.conversation_id,
    m.created_at as ultima_msg_at
  FROM messages m
  WHERE m.message_type = 1  -- outgoing
    AND m.sender_type = 'User'
    AND m.sender_id = 16  -- Théo
    AND m.content ILIKE '%Sim → para prosseguir com um especialista%'
  ORDER BY m.conversation_id, m.created_at DESC
),

-- Conversas elegíveis para RESGATE 15 MINUTOS
-- Critérios:
--   1. Última msg normal do Théo foi há 14-20 minutos
--   2. Mensagem de resgate 1 ainda NÃO foi enviada
--   3. Cliente NÃO respondeu após última msg do Théo
conversas_15min AS (
  SELECT
    c.id as conversation_id,
    c.account_id,
    c.inbox_id,
    c.contact_id,
    c.display_id,
    c.assignee_id,
    ct.phone_number as contact_phone,
    um.ultima_msg_at as ultima_msg_theo_at,
    um.content as ultima_msg_content,
    EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 as minutos_desde_ultima_msg,
    '15_minutos' as categoria_tempo
  FROM conversations c
  INNER JOIN ultima_msg_normal um ON c.id = um.conversation_id
  LEFT JOIN contacts ct ON c.contact_id = ct.id
  WHERE c.status = 0  -- conversa aberta
    AND c.assignee_id IS NULL  -- não atribuída a agente
    AND c.team_id IS NULL  -- não atribuída a time
    AND EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 BETWEEN 14 AND 20
    -- Verifica se NÃO existe mensagem de resgate 1 já enviada
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 1
        AND m.created_at > um.ultima_msg_at
        AND m.content ILIKE '%Sim → para prosseguir com um especialista%'
    )
    -- Verifica se cliente NÃO respondeu após última msg do Théo
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 0  -- incoming (resposta do cliente)
        AND m.created_at > um.ultima_msg_at
    )
),

-- Conversas elegíveis para RESGATE 2 HORAS
-- Critérios:
--   1. Mensagem de resgate 1 foi enviada há 115-130 minutos (~2h)
--   2. Mensagem de resgate 2 ainda NÃO foi enviada
--   3. Cliente NÃO respondeu após mensagem de resgate 1
conversas_2h AS (
  SELECT
    c.id as conversation_id,
    c.account_id,
    c.inbox_id,
    c.contact_id,
    c.display_id,
    c.assignee_id,
    ct.phone_number as contact_phone,
    um.ultima_msg_at as ultima_msg_theo_at,
    NULL as ultima_msg_content,
    EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 as minutos_desde_ultima_msg,
    '2_horas' as categoria_tempo
  FROM conversations c
  INNER JOIN ultima_msg_resgate1 um ON c.id = um.conversation_id
  LEFT JOIN contacts ct ON c.contact_id = ct.id
  WHERE c.status = 0  -- conversa aberta
    AND c.assignee_id IS NULL  -- não atribuída a agente
    AND c.team_id IS NULL  -- não atribuída a time
    AND EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 BETWEEN 115 AND 130
    -- Verifica se NÃO existe mensagem de resgate 2 já enviada
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 1
        AND m.created_at > um.ultima_msg_at
        AND m.content ILIKE '%Seguir → para continuar com um especialista%'
    )
    -- Verifica se cliente NÃO respondeu após msg de resgate 1
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 0  -- incoming (resposta do cliente)
        AND m.created_at > um.ultima_msg_at
    )
)

-- Combina os dois tipos de resgate
SELECT * FROM conversas_15min
UNION ALL
SELECT * FROM conversas_2h
ORDER BY minutos_desde_ultima_msg ASC
LIMIT 50;

-- ============================================
-- CAMPOS RETORNADOS:
-- ============================================
-- conversation_id: ID da conversa
-- account_id: ID da conta (necessário para API)
-- display_id: Display ID (necessário para API)
-- inbox_id: ID da inbox
-- contact_id: ID do contato
-- contact_phone: Telefone do contato (para salvar no histórico IA)
-- assignee_id: NULL (não atribuído)
-- ultima_msg_theo_at: Timestamp da última mensagem relevante
-- ultima_msg_content: Conteúdo da última mensagem (NULL para resgate 2h)
-- minutos_desde_ultima_msg: Minutos decorridos
-- categoria_tempo: '15_minutos' ou '2_horas'

-- ============================================
-- LÓGICA DE PROTEÇÃO CONTRA DUPLICATAS:
-- ============================================
--
-- RESGATE 15 MINUTOS:
--   - Referência: última mensagem NORMAL do Théo
--   - Verifica: msg de resgate 1 NÃO existe após ela
--   - Verifica: cliente NÃO respondeu após ela
--
-- RESGATE 2 HORAS:
--   - Referência: última mensagem de RESGATE 1
--   - Verifica: msg de resgate 2 NÃO existe após ela
--   - Verifica: cliente NÃO respondeu após ela
--
-- Isso garante que:
--   1. Cada tipo de mensagem só é enviada UMA vez
--   2. Se o cliente responder, NÃO envia mais mensagens de resgate
--   3. A mensagem de 2h só é enviada 2h após a de 15min (não após a original)
