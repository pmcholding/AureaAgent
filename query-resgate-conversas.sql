-- Query para Resgate de Conversas - Grupo Áurea
-- Busca conversas onde Théo foi o último a responder e cliente não retornou
-- ATUALIZADO: Intervalos de 15 minutos e 2 horas (antes era 2h e 4h)

-- CTE 1: Pega a última mensagem de cada conversa (excluindo mensagens de resgate)
WITH ultima_mensagem_nao_resgate AS (
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
    -- Exclui mensagens de resgate já na fonte
    AND NOT (
      m.content ILIKE '%Sim → para prosseguir com um especialista%'
      OR m.content ILIKE '%para prosseguir com um especialista%'
      OR m.content ILIKE '%Seguir → para continuar com um especialista%'
      OR m.content ILIKE '%Encerrar → para finalizar o atendimento%'
    )
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
    ct.phone_number as contact_phone,  -- NOVO: telefone do contato para histórico
    um.created_at as ultima_msg_theo_at,
    um.content as ultima_msg_content,
    EXTRACT(EPOCH FROM (NOW() - um.created_at))/60 as minutos_desde_ultima_msg_theo,
    CASE
      WHEN EXTRACT(EPOCH FROM (NOW() - um.created_at))/60 BETWEEN 14 AND 20 THEN '15_minutos'
      WHEN EXTRACT(EPOCH FROM (NOW() - um.created_at))/60 BETWEEN 115 AND 130 THEN '2_horas'
      ELSE 'fora_do_intervalo'
    END as categoria_tempo
  FROM conversations c
  INNER JOIN ultima_mensagem_nao_resgate um ON c.id = um.conversation_id
  LEFT JOIN contacts ct ON c.contact_id = ct.id  -- NOVO: JOIN para pegar telefone
  WHERE c.status = 0  -- conversa aberta
    AND c.assignee_id IS NULL  -- não atribuída a ninguém
    AND c.team_id IS NULL  -- não atribuída a nenhum time
    AND um.sender_type = 'User'  -- última mensagem enviada por User (bot)
    AND um.sender_id = 16  -- Théo (sender_id = 16)
    AND um.message_type = 1  -- outgoing
    AND (
      (EXTRACT(EPOCH FROM (NOW() - um.created_at))/60 BETWEEN 14 AND 20)  -- 14-20 minutos
      OR
      (EXTRACT(EPOCH FROM (NOW() - um.created_at))/60 BETWEEN 115 AND 130)  -- 1h55 a 2h10
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
)
ORDER BY cta.minutos_desde_ultima_msg_theo ASC
LIMIT 50;

-- Campos retornados:
-- - conversation_id: ID da conversa
-- - account_id: ID da conta (necessário para API)
-- - display_id: Display ID (necessário para API)
-- - inbox_id: ID da inbox
-- - contact_id: ID do contato
-- - contact_phone: Telefone do contato (para salvar no histórico IA)
-- - assignee_id: NULL (não atribuído)
-- - ultima_msg_theo_at: Timestamp da última mensagem do Théo
-- - ultima_msg_content: Conteúdo da última mensagem
-- - minutos_desde_ultima_msg_theo: Minutos decorridos
-- - categoria_tempo: '15_minutos' ou '2_horas'
