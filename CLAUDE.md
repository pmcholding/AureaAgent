# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains the configuration and automation for **Grupo Áurea's** customer service chatbot ("Théo") and lead recovery workflows. Grupo Áurea is a loan company serving low-income individuals, self-employed workers, and people with negative credit history in the São Paulo metropolitan area.

## Main File

The chatbot behavior is defined in `simple.md`. Always refer to this file for the current rules and responses.

## Chatwoot Automation Rules

The following automation rules trigger actions based on message content. When writing bot responses, use these trigger phrases to automate conversation routing:

### Rule: Assign to Team (ID: 1)
**Triggers** (any of these phrases in message):
- "vou transferir" / "Vou transferir"
- "entrará em contato em breve"
- "Já tenho todos os seus dados cadastrados"
- "cadastro será encaminhado"

**Action**: Assigns conversation to Team ID 1 (human agents)

### Rule: Assign to Team 2 - Specialists (ID: 2)
**Triggers** (any of these phrases in message):
- "estou encaminhando o seu atendimento para um de nossos especialistas!"

**Action**: Assigns conversation to Team ID 2 (specialists for Autônomo/MEI/Comerciante/Outros)

### Rule: Disqualified Lead Removal (ID: 9)
**Triggers** (any of these phrases):
- "Agradecemos o contato!"
- "não conseguiremos prosseguir com sua solicitação"

**Action**: Assigns conversation to Team ID 1 (for cleanup/archive)

### Rule: Re-loan Customer Routing (ID: 10)
**Triggers** (any of these phrases):
- "Vou te direcionar para um dos nossos consultores que cuidará da sua renovação"

**Action**: Assigns conversation directly to Agent ID 17

### Rule: Payment/Collection Redirect (ID: 11)
**Triggers** (any of these phrases):
- "procure falar com o seu consultor"

**Action**: Assigns conversation to Team ID 5 (cobrança)
