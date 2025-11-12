-- Query para Resgate de Conversas - Grupo Áurea
-- Busca conversas onde Théo foi o último a responder e cliente não retornou

-- CTE 1: Pega a última mensagem de cada conversa
WITH ultima_mensagem_conversa AS (
  SELECT DISTINCT ON (m.conversation_id)
    m.conversation_id,
    m.id as message_id,
    m.created_at,
    m.sender_type,
    m.sender_id,
    m.message_type,
    m.content
  FROM messages m
  WHERE m.message_type IN (0, 1)  -- incoming ou outgoing apenas
  ORDER BY m.conversation_id, m.created_at DESC
),

-- CTE 2: Filtra conversas onde Théo foi o último a responder
conversas_theo_aguardando AS (
  SELECT
    c.id as conversation_id,
    c.account_id,
    c.inbox_id,
    c.contact_id,
    c.cached_label_list,
    c.updated_at,
    c.contact_inbox_id,
    c.display_id,
    c.assignee_id,
    um.created_at as ultima_msg_theo_at,
    um.content as ultima_msg_content,
    EXTRACT(EPOCH FROM (NOW() - um.created_at))/3600 as horas_desde_ultima_msg_theo,
    CASE
      WHEN EXTRACT(EPOCH FROM (NOW() - um.created_at))/3600 BETWEEN 2 AND 2.5 THEN '2_horas'
      WHEN EXTRACT(EPOCH FROM (NOW() - um.created_at))/3600 BETWEEN 4 AND 4.5 THEN '4_horas'
      ELSE 'fora_do_intervalo'
    END as categoria_tempo
  FROM conversations c
  INNER JOIN ultima_mensagem_conversa um ON c.id = um.conversation_id
  WHERE c.status = 0  -- conversa aberta
    AND c.assignee_id IS NULL  -- não atribuída a ninguém
    AND um.sender_type = 'User'  -- última mensagem enviada por User (bot)
    AND um.sender_id = 16  -- Théo (sender_id = 16)
    AND um.message_type = 1  -- outgoing
    AND (
      (EXTRACT(EPOCH FROM (NOW() - um.created_at))/3600 BETWEEN 2 AND 2.5)
      OR
      (EXTRACT(EPOCH FROM (NOW() - um.created_at))/3600 BETWEEN 4 AND 4.5)
    )
)

-- Query final: Remove conversas que já receberam mensagem de resgate
SELECT
  cta.*
FROM conversas_theo_aguardando cta
WHERE NOT EXISTS (
  SELECT 1 FROM messages m
  WHERE m.conversation_id = cta.conversation_id
    AND m.message_type = 1  -- outgoing
    AND m.created_at > cta.ultima_msg_theo_at
    AND (
      m.content ILIKE '%Percebi que iniciamos uma conversa%'
      OR m.content ILIKE '%você não retornou ainda%'
      OR m.content ILIKE '%ainda tem interesse em prosseguir%'
    )
)
ORDER BY cta.horas_desde_ultima_msg_theo ASC
LIMIT 50;

-- Campos retornados:
-- - conversation_id: ID da conversa
-- - account_id: ID da conta (necessário para API)
-- - display_id: Display ID (necessário para API)
-- - inbox_id: ID da inbox
-- - contact_id: ID do contato
-- - assignee_id: NULL (não atribuído)
-- - ultima_msg_theo_at: Timestamp da última mensagem do Théo
-- - ultima_msg_content: Conteúdo da última mensagem
-- - horas_desde_ultima_msg_theo: Horas decorridas
-- - categoria_tempo: '2_horas' ou '4_horas'
