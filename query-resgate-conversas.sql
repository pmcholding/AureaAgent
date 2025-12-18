-- Query para Resgate de Conversas - Grupo Áurea
-- Busca conversas onde Théo foi o último a responder e cliente não retornou
-- ATUALIZADO: Intervalos de 15 minutos e 2 horas
-- CORRIGIDO: Padrões ILIKE ajustados para ignorar formatação markdown (*Sim* vs Sim)

WITH
-- Última mensagem NORMAL do Théo (exclui mensagens de resgate)
ultima_msg_normal AS (
  SELECT DISTINCT ON (m.conversation_id)
    m.conversation_id,
    m.created_at as ultima_msg_at,
    m.content
  FROM messages m
  WHERE m.message_type = 1
    AND m.sender_type = 'User'
    AND m.sender_id = 16
    AND NOT (
      m.content ILIKE '%alto volume de atendimentos diários%'
      OR m.content ILIKE '%gostaria de seguir com o processo%'
    )
  ORDER BY m.conversation_id, m.created_at DESC
),

-- Última mensagem de RESGATE 1 (15 min)
ultima_msg_resgate1 AS (
  SELECT DISTINCT ON (m.conversation_id)
    m.conversation_id,
    m.created_at as ultima_msg_at
  FROM messages m
  WHERE m.message_type = 1
    AND m.sender_type = 'User'
    AND m.sender_id = 16
    AND m.content ILIKE '%alto volume de atendimentos diários%'
  ORDER BY m.conversation_id, m.created_at DESC
),

-- Conversas elegíveis para RESGATE 15 MINUTOS
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
  WHERE c.status = 0
    AND c.assignee_id IS NULL
    AND c.team_id IS NULL
    AND EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 BETWEEN 14 AND 20
    -- Verifica se NÃO existe mensagem de resgate 1 já enviada
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 1
        AND m.created_at > um.ultima_msg_at
        AND m.content ILIKE '%alto volume de atendimentos diários%'
    )
    -- Verifica se cliente NÃO respondeu após última msg do Théo
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 0
        AND m.created_at > um.ultima_msg_at
    )
),

-- Conversas elegíveis para RESGATE 2 HORAS
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
  WHERE c.status = 0
    AND c.assignee_id IS NULL
    AND c.team_id IS NULL
    AND EXTRACT(EPOCH FROM (NOW() - um.ultima_msg_at))/60 BETWEEN 115 AND 130
    -- Verifica se NÃO existe mensagem de resgate 2 já enviada
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 1
        AND m.created_at > um.ultima_msg_at
        AND m.content ILIKE '%gostaria de seguir com o processo%'
    )
    -- Verifica se cliente NÃO respondeu após msg de resgate 1
    AND NOT EXISTS (
      SELECT 1 FROM messages m
      WHERE m.conversation_id = c.id
        AND m.message_type = 0
        AND m.created_at > um.ultima_msg_at
    )
)

SELECT * FROM conversas_15min
UNION ALL
SELECT * FROM conversas_2h
ORDER BY minutos_desde_ultima_msg ASC
LIMIT 50
