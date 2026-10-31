-- =====================================================================
-- CRMoveis - Regras que envolvem mais de um registro (RNF13)
-- Projeto Integrador - Modelagem de Dados - Prof. Clovis - Grupo 4
-- PostgreSQL 13 ou superior - depois do 03
-- =====================================================================

-- =====================================================================
-- FUNCOES AUXILIARES
-- =====================================================================
-- Indica se o usuario exerce o papel e o papel nao tem data de fim (RN02, RN32).
CREATE FUNCTION papel_ativo(p_usuario INTEGER, p_papel TEXT) RETURNS BOOLEAN
LANGUAGE plpgsql STABLE AS $$
DECLARE v_ok BOOLEAN;
BEGIN
    IF p_papel NOT IN ('cliente', 'proprietario', 'inquilino', 'corretor', 'financeiro',
                       'fornecedor', 'administrador', 'instituicao_financeira') THEN
        RAISE EXCEPTION 'Papel desconhecido: %', p_papel;
    END IF;
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE id_usuario = $1 AND dt_fim IS NULL)', p_papel)
       INTO v_ok USING p_usuario;
    RETURN v_ok;
END $$;

-- Soma dias uteis (segunda a sexta) a uma data; feriados ficam a cargo da aplicacao (PO05).
CREATE FUNCTION dia_util_apos(p_data DATE, p_dias INTEGER) RETURNS DATE
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_data DATE := p_data; v_contados INTEGER := 0;
BEGIN
    WHILE v_contados < p_dias LOOP
        v_data := v_data + 1;
        IF EXTRACT(ISODOW FROM v_data) < 6 THEN v_contados := v_contados + 1; END IF;
    END LOOP;
    RETURN v_data;
END $$;

-- =====================================================================
-- PONTO 1 - PAPEIS (especializacao total e compartilhada de USUARIO)
-- =====================================================================
-- RN01: todo usuario exerce pelo menos um papel. Conferido no fim da transacao,
-- para permitir gravar o usuario e, em seguida, o(s) subtipo(s).
CREATE FUNCTION tg_especializacao_total() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_usuario INTEGER := CASE WHEN TG_OP = 'DELETE' THEN OLD.id_usuario ELSE NEW.id_usuario END;
BEGIN
    IF EXISTS (SELECT 1 FROM usuario WHERE id_usuario = v_usuario) AND NOT EXISTS (
           SELECT 1 FROM cliente WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM proprietario WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM inquilino WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM corretor WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM financeiro WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM fornecedor WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM administrador WHERE id_usuario = v_usuario UNION ALL
           SELECT 1 FROM instituicao_financeira WHERE id_usuario = v_usuario) THEN
        RAISE EXCEPTION 'RN01: o usuario % precisa exercer pelo menos um papel', v_usuario;
    END IF;
    RETURN NULL;
END $$;

CREATE CONSTRAINT TRIGGER ct_usuario_especializacao AFTER INSERT ON usuario
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_cliente_especializacao AFTER DELETE ON cliente
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_proprietario_especializacao AFTER DELETE ON proprietario
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_inquilino_especializacao AFTER DELETE ON inquilino
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_corretor_especializacao AFTER DELETE ON corretor
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_financeiro_especializacao AFTER DELETE ON financeiro
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_fornecedor_especializacao AFTER DELETE ON fornecedor
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_administrador_especializacao AFTER DELETE ON administrador
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();
CREATE CONSTRAINT TRIGGER ct_instituicao_financeira_especializacao AFTER DELETE ON instituicao_financeira
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_especializacao_total();

-- RN32: novos registros so aceitam pessoas que exercem o papel sem data de fim.
-- Argumentos do gatilho: pares (coluna, papel).
CREATE FUNCTION tg_exige_papel_ativo() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE i INTEGER := 0; v_id TEXT;
BEGIN
    WHILE i < TG_NARGS LOOP
        v_id := to_jsonb(NEW) ->> TG_ARGV[i];
        IF v_id IS NOT NULL
           AND (TG_OP = 'INSERT' OR v_id IS DISTINCT FROM to_jsonb(OLD) ->> TG_ARGV[i])
           AND NOT papel_ativo(v_id::INTEGER, TG_ARGV[i + 1]) THEN
            RAISE EXCEPTION 'RN32: o usuario % nao exerce o papel % (ou o papel tem data de fim) em %.%',
                v_id, TG_ARGV[i + 1], TG_TABLE_NAME, TG_ARGV[i];
        END IF;
        i := i + 2;
    END LOOP;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_perfil_interesse_papel BEFORE INSERT OR UPDATE ON perfil_interesse
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_usuario', 'cliente');
CREATE TRIGGER tg_imovel_papel BEFORE INSERT OR UPDATE ON imovel
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_proprietario', 'proprietario', 'id_corretor_responsavel', 'corretor');
CREATE TRIGGER tg_conversa_papel BEFORE INSERT OR UPDATE ON conversa
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_cliente', 'cliente', 'id_corretor', 'corretor');
CREATE TRIGGER tg_tarefa_papel BEFORE INSERT OR UPDATE ON tarefa
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_corretor', 'corretor');
CREATE TRIGGER tg_visita_papel BEFORE INSERT OR UPDATE ON visita
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_cliente', 'cliente', 'id_corretor', 'corretor');
CREATE TRIGGER tg_proposta_papel BEFORE INSERT OR UPDATE ON proposta
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_cliente', 'cliente', 'id_corretor', 'corretor', 'id_autorizador', 'administrador');
CREATE TRIGGER tg_comissao_papel BEFORE INSERT OR UPDATE ON comissao
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_corretor', 'corretor', 'id_aprovador', 'administrador');
CREATE TRIGGER tg_financiamento_papel BEFORE INSERT OR UPDATE ON financiamento
    FOR EACH ROW EXECUTE FUNCTION tg_exige_papel_ativo('id_instituicao', 'instituicao_financeira');

-- RN27, RN32: o pagador exerce o papel indicado; banco so paga conta de contrato que ele financiou.
CREATE FUNCTION tg_conta_receber_pagador() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'INSERT' OR (NEW.id_pagador, NEW.tp_papel_pagador) IS DISTINCT FROM (OLD.id_pagador, OLD.tp_papel_pagador) THEN
        IF NOT papel_ativo(NEW.id_pagador, NEW.tp_papel_pagador) THEN
            RAISE EXCEPTION 'RN32: o pagador % nao exerce o papel %', NEW.id_pagador, NEW.tp_papel_pagador;
        END IF;
        IF NEW.tp_papel_pagador = 'instituicao_financeira' AND NOT EXISTS (
               SELECT 1 FROM financiamento f
                WHERE f.id_contrato = NEW.id_contrato AND f.id_instituicao = NEW.id_pagador) THEN
            RAISE EXCEPTION 'RN27: o banco % nao financiou o contrato %', NEW.id_pagador, NEW.id_contrato;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_conta_receber_pagador BEFORE INSERT OR UPDATE ON conta_receber
    FOR EACH ROW EXECUTE FUNCTION tg_conta_receber_pagador();

-- RN28, RN32: quem arca com o custo (quando nao e a imobiliaria) exerce o papel indicado.
CREATE FUNCTION tg_conta_pagar_custeio() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.tp_papel_custeio <> 'imobiliaria'
       AND (TG_OP = 'INSERT' OR (NEW.id_custeador, NEW.tp_papel_custeio) IS DISTINCT FROM (OLD.id_custeador, OLD.tp_papel_custeio))
       AND NOT papel_ativo(NEW.id_custeador, NEW.tp_papel_custeio) THEN
        RAISE EXCEPTION 'RN32: quem arca com o custo (%) nao exerce o papel %', NEW.id_custeador, NEW.tp_papel_custeio;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_conta_pagar_custeio BEFORE INSERT OR UPDATE ON conta_pagar
    FOR EACH ROW EXECUTE FUNCTION tg_conta_pagar_custeio();

-- =====================================================================
-- PONTO 2 - TELEFONE COMPARTILHADO COM UM TITULAR
-- =====================================================================
-- RN03: todo numero cadastrado tem exatamente um titular entre as pessoas que o usam (o maximo e garantido
-- pelo indice parcial ux_telefone_titular; o minimo, por este gatilho no fim da transacao, para permitir
-- trocar o titular em dois passos: tira de um e passa para o outro).
CREATE FUNCTION confere_titular(p_numero VARCHAR) RETURNS VOID
LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM telefone WHERE nr_telefone = p_numero)
       AND NOT EXISTS (SELECT 1 FROM telefone WHERE nr_telefone = p_numero AND fl_titular) THEN
        RAISE EXCEPTION 'RN03: o numero % precisa ter exatamente um titular', p_numero;
    END IF;
END $$;

CREATE FUNCTION tg_telefone_titular() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP <> 'INSERT' THEN PERFORM confere_titular(OLD.nr_telefone); END IF;
    IF TG_OP <> 'DELETE' THEN PERFORM confere_titular(NEW.nr_telefone); END IF;
    RETURN NULL;
END $$;
CREATE CONSTRAINT TRIGGER ct_telefone_titular AFTER INSERT OR UPDATE OR DELETE ON telefone
    DEFERRABLE INITIALLY DEFERRED FOR EACH ROW EXECUTE FUNCTION tg_telefone_titular();

-- =====================================================================
-- PONTO 7 - SOMA DAS COMISSOES DE UM CONTRATO ATE 100%
-- =====================================================================
-- RN20: a soma dos percentuais das comissoes nao canceladas do contrato nao passa de 100.
-- A linha do contrato e bloqueada (FOR UPDATE) para que duas gravacoes simultaneas
-- nao passem juntas do limite: a segunda espera a primeira terminar e soma de novo.
CREATE FUNCTION tg_comissao_soma() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_soma NUMERIC(7,2);
BEGIN
    IF NEW.st_comissao = 'cancelada' THEN RETURN NEW; END IF;
    PERFORM 1 FROM contrato WHERE id_contrato = NEW.id_contrato FOR UPDATE;
    SELECT COALESCE(SUM(pc_comissao), 0) INTO v_soma
      FROM comissao
     WHERE id_contrato = NEW.id_contrato
       AND st_comissao <> 'cancelada'
       AND (id_contrato, id_corretor) IS DISTINCT FROM (OLD.id_contrato, OLD.id_corretor);
    IF v_soma + NEW.pc_comissao > 100 THEN
        RAISE EXCEPTION 'RN20: a soma das comissoes do contrato % ficaria em % %% (limite: 100 %%)',
            NEW.id_contrato, v_soma + NEW.pc_comissao;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_comissao_soma BEFORE INSERT OR UPDATE OF id_contrato, pc_comissao, st_comissao ON comissao
    FOR EACH ROW EXECUTE FUNCTION tg_comissao_soma();

-- =====================================================================
-- CATEGORIA FINANCEIRA COMPATIVEL COM A CONTA (RN26)
-- =====================================================================
-- RN26: conta a receber usa categoria de receita; conta a pagar, de despesa. A conta a pagar gerada por um
-- recebimento (repasse, RN30) usa a categoria de codigo 'repasse'. A natureza do lancamento vem da categoria,
-- e nao de uma coluna de tipo na conta, que dependeria da categoria (3FN).
CREATE FUNCTION tg_conta_categoria() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_tipo TEXT; v_codigo TEXT;
        v_esperado TEXT := CASE TG_TABLE_NAME WHEN 'conta_receber' THEN 'receita' ELSE 'despesa' END;
BEGIN
    SELECT tp_categoria, cd_categoria INTO v_tipo, v_codigo FROM categoria_financeira WHERE id_categoria = NEW.id_categoria;
    IF v_tipo <> v_esperado THEN
        RAISE EXCEPTION 'RN26: % precisa de uma categoria de %, mas a categoria % e de %', TG_TABLE_NAME, v_esperado, v_codigo, v_tipo;
    END IF;
    IF TG_TABLE_NAME = 'conta_pagar' AND to_jsonb(NEW) ->> 'nr_recebimento_origem' IS NOT NULL AND v_codigo <> 'repasse' THEN
        RAISE EXCEPTION 'RN30: a conta a pagar gerada por um recebimento usa a categoria de repasse (a categoria % nao e)', v_codigo;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_conta_receber_categoria BEFORE INSERT OR UPDATE OF id_categoria ON conta_receber
    FOR EACH ROW EXECUTE FUNCTION tg_conta_categoria();
CREATE TRIGGER tg_conta_pagar_categoria BEFORE INSERT OR UPDATE OF id_categoria, id_conta_receber_origem, nr_recebimento_origem ON conta_pagar
    FOR EACH ROW EXECUTE FUNCTION tg_conta_categoria();

-- RN26: o codigo da categoria nao muda (as regras a encontram por ele), e o tipo nao muda enquanto houver conta nela.
CREATE FUNCTION tg_categoria_financeira_estavel() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.cd_categoria <> OLD.cd_categoria THEN
        RAISE EXCEPTION 'RN26: o codigo da categoria (%) nao muda; renomeie pelo nome (nm_categoria)', OLD.cd_categoria;
    END IF;
    IF NEW.tp_categoria <> OLD.tp_categoria AND (
           EXISTS (SELECT 1 FROM conta_receber WHERE id_categoria = OLD.id_categoria)
           OR EXISTS (SELECT 1 FROM conta_pagar WHERE id_categoria = OLD.id_categoria)) THEN
        RAISE EXCEPTION 'RN26: a categoria % ja classifica contas e nao pode mudar de % para %', OLD.cd_categoria, OLD.tp_categoria, NEW.tp_categoria;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_categoria_financeira_estavel BEFORE UPDATE ON categoria_financeira
    FOR EACH ROW EXECUTE FUNCTION tg_categoria_financeira_estavel();

-- =====================================================================
-- BAIXAS: SOMA ATE O VALOR DA CONTA, CONCILIACAO E QUEM EFETIVA O PAGAMENTO
-- =====================================================================
-- RN29: a soma das baixas nao passa do valor da conta (a conta e bloqueada durante a soma);
--       conta cancelada nao recebe baixa.
-- RN45: a baixa ligada a um movimento do extrato usa movimento da mesma conta (FK composta),
--       na direcao certa, e a soma das baixas do movimento nao passa do valor dele.
-- RN30: recebimento que ja gerou repasse nao muda de valor.
CREATE FUNCTION tg_recebimento_regras() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_valor NUMERIC(12,2); v_cancelada BOOLEAN; v_soma NUMERIC(14,2); v_tipo TEXT;
BEGIN
    SELECT vl_receber, fl_cancelada INTO v_valor, v_cancelada
      FROM conta_receber WHERE id_conta_receber = NEW.id_conta_receber FOR UPDATE;
    IF v_cancelada AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'RN38: a conta a receber % esta cancelada e nao recebe baixa', NEW.id_conta_receber;
    END IF;
    SELECT COALESCE(SUM(vl_recebido), 0) INTO v_soma FROM recebimento
     WHERE id_conta_receber = NEW.id_conta_receber
       AND (id_conta_receber, nr_recebimento) IS DISTINCT FROM (OLD.id_conta_receber, OLD.nr_recebimento);
    IF v_soma + NEW.vl_recebido > v_valor THEN
        RAISE EXCEPTION 'RN29: os recebimentos da conta % somariam %, acima do valor da conta (%)',
            NEW.id_conta_receber, v_soma + NEW.vl_recebido, v_valor;
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.vl_recebido <> OLD.vl_recebido AND EXISTS (
           SELECT 1 FROM conta_pagar WHERE id_conta_receber_origem = OLD.id_conta_receber
                                       AND nr_recebimento_origem = OLD.nr_recebimento) THEN
        RAISE EXCEPTION 'RN30: o recebimento %/% ja gerou repasse e nao pode mudar de valor',
            OLD.id_conta_receber, OLD.nr_recebimento;
    END IF;
    IF NEW.nr_movimento IS NOT NULL THEN
        SELECT tp_movimento, vl_movimento INTO v_tipo, v_valor FROM movimento_bancario
         WHERE id_conta = NEW.id_conta AND nr_movimento = NEW.nr_movimento FOR UPDATE;
        IF v_tipo <> 'credito' THEN
            RAISE EXCEPTION 'RN45: recebimento so e conciliado com movimento de credito (o movimento % e %)', NEW.nr_movimento, v_tipo;
        END IF;
        SELECT COALESCE(SUM(vl_recebido), 0) INTO v_soma FROM recebimento
         WHERE id_conta = NEW.id_conta AND nr_movimento = NEW.nr_movimento
           AND (id_conta_receber, nr_recebimento) IS DISTINCT FROM (OLD.id_conta_receber, OLD.nr_recebimento);
        IF v_soma + NEW.vl_recebido > v_valor THEN
            RAISE EXCEPTION 'RN45: as baixas ligadas ao movimento % somariam %, acima do valor do extrato (%)',
                NEW.nr_movimento, v_soma + NEW.vl_recebido, v_valor;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_recebimento_regras BEFORE INSERT OR UPDATE ON recebimento
    FOR EACH ROW EXECUTE FUNCTION tg_recebimento_regras();

-- RN39, PO01: quem efetiva o pagamento e administrador ou financeiro; comissao, so administrador.
CREATE FUNCTION tg_pagamento_regras() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_valor NUMERIC(12,2); v_cancelada BOOLEAN; v_despesa TEXT; v_soma NUMERIC(14,2); v_tipo TEXT;
BEGIN
    SELECT cp.vl_pagar, cp.fl_cancelada, cf.cd_categoria INTO v_valor, v_cancelada, v_despesa
      FROM conta_pagar cp JOIN categoria_financeira cf ON cf.id_categoria = cp.id_categoria
     WHERE cp.id_conta_pagar = NEW.id_conta_pagar FOR UPDATE OF cp;
    IF TG_OP = 'INSERT' OR NEW.id_usuario IS DISTINCT FROM OLD.id_usuario THEN
        IF v_despesa = 'comissao' AND NOT papel_ativo(NEW.id_usuario, 'administrador') THEN
            RAISE EXCEPTION 'PO01: o pagamento de comissao so pode ser efetivado pelo administrador';
        ELSIF NOT (papel_ativo(NEW.id_usuario, 'administrador') OR papel_ativo(NEW.id_usuario, 'financeiro')) THEN
            RAISE EXCEPTION 'RN39: o usuario % nao e administrador nem financeiro', NEW.id_usuario;
        END IF;
    END IF;
    IF v_cancelada AND TG_OP = 'INSERT' THEN
        RAISE EXCEPTION 'RN38: a conta a pagar % esta cancelada e nao recebe baixa', NEW.id_conta_pagar;
    END IF;
    SELECT COALESCE(SUM(vl_pago), 0) INTO v_soma FROM pagamento
     WHERE id_conta_pagar = NEW.id_conta_pagar
       AND (id_conta_pagar, nr_pagamento) IS DISTINCT FROM (OLD.id_conta_pagar, OLD.nr_pagamento);
    IF v_soma + NEW.vl_pago > v_valor THEN
        RAISE EXCEPTION 'RN29: os pagamentos da conta % somariam %, acima do valor da conta (%)',
            NEW.id_conta_pagar, v_soma + NEW.vl_pago, v_valor;
    END IF;
    IF NEW.nr_movimento IS NOT NULL THEN
        SELECT tp_movimento, vl_movimento INTO v_tipo, v_valor FROM movimento_bancario
         WHERE id_conta = NEW.id_conta AND nr_movimento = NEW.nr_movimento FOR UPDATE;
        IF v_tipo <> 'debito' THEN
            RAISE EXCEPTION 'RN45: pagamento so e conciliado com movimento de debito (o movimento % e %)', NEW.nr_movimento, v_tipo;
        END IF;
        SELECT COALESCE(SUM(vl_pago), 0) INTO v_soma FROM pagamento
         WHERE id_conta = NEW.id_conta AND nr_movimento = NEW.nr_movimento
           AND (id_conta_pagar, nr_pagamento) IS DISTINCT FROM (OLD.id_conta_pagar, OLD.nr_pagamento);
        IF v_soma + NEW.vl_pago > v_valor THEN
            RAISE EXCEPTION 'RN45: as baixas ligadas ao movimento % somariam %, acima do valor do extrato (%)',
                NEW.nr_movimento, v_soma + NEW.vl_pago, v_valor;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_pagamento_regras BEFORE INSERT OR UPDATE ON pagamento
    FOR EACH ROW EXECUTE FUNCTION tg_pagamento_regras();

-- =====================================================================
-- PONTO 3 - REPASSE A CADA RECEBIMENTO DO ALUGUEL (inclusive parcial)
-- =====================================================================
-- RN30, PO05: cada recebimento de aluguel gera a conta a pagar do repasse ao proprietario:
-- valor recebido menos a taxa de administracao, vencendo 5 dias uteis depois do recebimento.
CREATE FUNCTION tg_recebimento_repasse() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE r RECORD; v_categoria INTEGER;
BEGIN
    SELECT cr.id_contrato, cr.dt_competencia, c.pc_administracao, i.id_proprietario INTO r
      FROM conta_receber cr
      JOIN contrato c ON c.id_contrato = cr.id_contrato
      JOIN proposta p ON p.id_proposta = c.id_proposta
      JOIN imovel   i ON i.id_imovel   = p.id_imovel
      JOIN categoria_financeira cf ON cf.id_categoria = cr.id_categoria
     WHERE cr.id_conta_receber = NEW.id_conta_receber
       AND cf.cd_categoria = 'aluguel' AND c.tp_contrato = 'locacao';
    IF NOT FOUND THEN RETURN NULL; END IF;
    SELECT id_categoria INTO v_categoria FROM categoria_financeira WHERE cd_categoria = 'repasse';
    IF v_categoria IS NULL THEN
        RAISE EXCEPTION 'RN30: cadastre a categoria de despesa de codigo "repasse"';
    END IF;
    INSERT INTO conta_pagar (id_contrato, id_categoria, id_favorecido, id_conta_receber_origem, nr_recebimento_origem,
                             tp_papel_custeio, ds_conta, dt_competencia, vl_pagar, dt_vencimento)
    VALUES (r.id_contrato, v_categoria, r.id_proprietario, NEW.id_conta_receber, NEW.nr_recebimento,
            'imobiliaria',
            format('Repasse do recebimento %s/%s', NEW.id_conta_receber, NEW.nr_recebimento),
            r.dt_competencia,
            round(NEW.vl_recebido * (1 - r.pc_administracao / 100), 2),
            dia_util_apos(NEW.dt_recebimento, 5));
    RETURN NULL;
END $$;
CREATE TRIGGER tg_recebimento_repasse AFTER INSERT ON recebimento
    FOR EACH ROW EXECUTE FUNCTION tg_recebimento_repasse();

-- =====================================================================
-- PONTO 4 - CANCELAMENTO, RESCISAO E ENCERRAMENTO DO CONTRATO
-- =====================================================================
-- RN33: a assinatura da locacao torna o cliente tambem INQUILINO.
CREATE FUNCTION tg_contrato_inquilino() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_cliente INTEGER;
BEGIN
    IF NEW.tp_contrato = 'locacao' AND NEW.st_contrato = 'vigente'
       AND (TG_OP = 'INSERT' OR OLD.st_contrato <> 'vigente') THEN
        SELECT id_cliente INTO v_cliente FROM proposta WHERE id_proposta = NEW.id_proposta;
        INSERT INTO inquilino (id_usuario, dt_inicio) VALUES (v_cliente, COALESCE(NEW.dt_inicio, CURRENT_DATE))
        ON CONFLICT (id_usuario) DO UPDATE SET dt_fim = NULL;
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER tg_contrato_inquilino AFTER INSERT OR UPDATE OF st_contrato ON contrato
    FOR EACH ROW EXECUTE FUNCTION tg_contrato_inquilino();

-- Fim do papel de inquilino, se a pessoa nao tiver outra locacao vigente (RN43, RN44).
CREATE FUNCTION encerra_inquilino(p_contrato INTEGER, p_data DATE) RETURNS VOID
LANGUAGE plpgsql AS $$
DECLARE v_cliente INTEGER;
BEGIN
    SELECT p.id_cliente INTO v_cliente FROM contrato c JOIN proposta p ON p.id_proposta = c.id_proposta
     WHERE c.id_contrato = p_contrato;
    UPDATE inquilino SET dt_fim = p_data
     WHERE id_usuario = v_cliente AND dt_fim IS NULL
       AND NOT EXISTS (SELECT 1 FROM contrato c JOIN proposta p ON p.id_proposta = c.id_proposta
                        WHERE p.id_cliente = v_cliente AND c.tp_contrato = 'locacao'
                          AND c.st_contrato = 'vigente' AND c.id_contrato <> p_contrato);
END $$;

-- RN37: cancelar desfaz o contrato antes de produzir efeitos.
CREATE PROCEDURE cancelar_contrato(p_contrato INTEGER, p_data DATE, p_motivo TEXT)
LANGUAGE plpgsql AS $$
DECLARE c RECORD;
BEGIN
    SELECT * INTO c FROM contrato WHERE id_contrato = p_contrato FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'Contrato % nao existe', p_contrato; END IF;
    IF c.st_contrato NOT IN ('rascunho', 'vigente') THEN
        RAISE EXCEPTION 'RN37: so contrato em rascunho ou vigente pode ser cancelado (situacao atual: %)', c.st_contrato;
    END IF;
    -- comissoes ainda nao pagas sao canceladas
    UPDATE comissao cm SET st_comissao = 'cancelada'
     WHERE cm.id_contrato = p_contrato AND cm.st_comissao <> 'cancelada'
       AND NOT EXISTS (SELECT 1 FROM pagamento pg WHERE pg.id_conta_pagar = cm.id_conta_pagar);
    -- contas sem nenhuma baixa sao canceladas; o que ja foi recebido ou pago e mantido
    UPDATE conta_receber cr SET fl_cancelada = TRUE
     WHERE cr.id_contrato = p_contrato AND NOT cr.fl_cancelada
       AND NOT EXISTS (SELECT 1 FROM recebimento r WHERE r.id_conta_receber = cr.id_conta_receber);
    UPDATE conta_pagar cp SET fl_cancelada = TRUE
     WHERE NOT cp.fl_cancelada AND cp.id_conta_receber_origem IS NULL
       AND (cp.id_contrato = p_contrato
            OR cp.id_conta_pagar IN (SELECT id_conta_pagar FROM comissao WHERE id_contrato = p_contrato AND st_comissao = 'cancelada'))
       AND NOT EXISTS (SELECT 1 FROM pagamento pg WHERE pg.id_conta_pagar = cp.id_conta_pagar);
    UPDATE imovel SET st_imovel = 'disponivel'
     WHERE id_imovel = (SELECT id_imovel FROM proposta WHERE id_proposta = c.id_proposta);
    UPDATE contrato SET st_contrato = 'cancelado', dt_termino = p_data, ds_motivo_termino = p_motivo
     WHERE id_contrato = p_contrato;
END $$;

-- RN43: rescindir termina antes do prazo um contrato vigente.
CREATE PROCEDURE rescindir_contrato(p_contrato INTEGER, p_data DATE, p_motivo TEXT, p_iniciativa TEXT,
                                    p_vl_multa NUMERIC DEFAULT NULL, p_vencimento_multa DATE DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE c RECORD; v_pagador INTEGER; v_papel TEXT; v_categoria INTEGER;
BEGIN
    SELECT ct.*, p.id_cliente, p.id_imovel, i.id_proprietario INTO c
      FROM contrato ct JOIN proposta p ON p.id_proposta = ct.id_proposta JOIN imovel i ON i.id_imovel = p.id_imovel
     WHERE ct.id_contrato = p_contrato FOR UPDATE OF ct;
    IF NOT FOUND THEN RAISE EXCEPTION 'Contrato % nao existe', p_contrato; END IF;
    IF c.st_contrato <> 'vigente' THEN
        RAISE EXCEPTION 'RN43: so contrato vigente pode ser rescindido (situacao atual: %)', c.st_contrato;
    END IF;
    -- contas de periodos futuros e sem baixa sao canceladas; as vencidas continuam devidas
    UPDATE conta_receber cr SET fl_cancelada = TRUE
     WHERE cr.id_contrato = p_contrato AND NOT cr.fl_cancelada
       AND COALESCE(cr.dt_competencia, cr.dt_vencimento) > p_data
       AND NOT EXISTS (SELECT 1 FROM recebimento r WHERE r.id_conta_receber = cr.id_conta_receber);
    UPDATE conta_pagar cp SET fl_cancelada = TRUE
     WHERE cp.id_contrato = p_contrato AND NOT cp.fl_cancelada
       AND cp.id_categoria NOT IN (SELECT id_categoria FROM categoria_financeira WHERE cd_categoria IN ('comissao', 'repasse'))
       AND COALESCE(cp.dt_competencia, cp.dt_vencimento) > p_data
       AND NOT EXISTS (SELECT 1 FROM pagamento pg WHERE pg.id_conta_pagar = cp.id_conta_pagar);
    -- comissoes ja liberadas sao mantidas; as pendentes sao canceladas
    UPDATE comissao SET st_comissao = 'cancelada' WHERE id_contrato = p_contrato AND st_comissao = 'pendente';
    -- multa rescisoria, se prevista, cobrada de quem pediu a rescisao
    IF p_vl_multa IS NOT NULL THEN
        IF p_iniciativa = 'cliente' THEN
            v_pagador := c.id_cliente;
            v_papel := CASE WHEN c.tp_contrato = 'locacao' THEN 'inquilino' ELSE 'cliente' END;
        ELSIF p_iniciativa = 'proprietario' THEN
            v_pagador := c.id_proprietario; v_papel := 'proprietario';
        ELSE
            RAISE EXCEPTION 'RN43: rescisao de comum acordo nao gera multa';
        END IF;
        SELECT id_categoria INTO v_categoria FROM categoria_financeira WHERE cd_categoria = 'multa_rescisoria';
        INSERT INTO conta_receber (id_contrato, id_categoria, id_pagador, tp_papel_pagador,
                                   ds_conta, dt_competencia, vl_receber, dt_vencimento)
        VALUES (p_contrato, v_categoria, v_pagador, v_papel,
                'Multa rescisoria do contrato ' || p_contrato, p_data, p_vl_multa,
                COALESCE(p_vencimento_multa, dia_util_apos(p_data, 5)));
    END IF;
    UPDATE imovel SET st_imovel = 'disponivel' WHERE id_imovel = c.id_imovel;
    IF c.tp_contrato = 'locacao' THEN PERFORM encerra_inquilino(p_contrato, p_data); END IF;
    UPDATE contrato SET st_contrato = 'rescindido', dt_termino = p_data, ds_motivo_termino = p_motivo,
                        tp_iniciativa_rescisao = p_iniciativa
     WHERE id_contrato = p_contrato;
END $$;

-- RN44: encerrar e o termino normal; nenhum lancamento e cancelado.
CREATE PROCEDURE encerrar_contrato(p_contrato INTEGER, p_data DATE)
LANGUAGE plpgsql AS $$
DECLARE c RECORD;
BEGIN
    SELECT ct.*, p.id_imovel INTO c FROM contrato ct JOIN proposta p ON p.id_proposta = ct.id_proposta
     WHERE ct.id_contrato = p_contrato FOR UPDATE OF ct;
    IF NOT FOUND THEN RAISE EXCEPTION 'Contrato % nao existe', p_contrato; END IF;
    IF c.st_contrato <> 'vigente' THEN
        RAISE EXCEPTION 'RN44: so contrato vigente pode ser encerrado (situacao atual: %)', c.st_contrato;
    END IF;
    IF c.tp_contrato = 'locacao' THEN
        IF p_data < c.dt_fim THEN
            RAISE EXCEPTION 'RN44: a locacao so e encerrada a partir da data de termino (%); antes disso e rescisao', c.dt_fim;
        END IF;
        UPDATE imovel SET st_imovel = 'disponivel' WHERE id_imovel = c.id_imovel;
        PERFORM encerra_inquilino(p_contrato, p_data);
    ELSE
        IF EXISTS (SELECT 1 FROM vw_conta_receber WHERE id_contrato = p_contrato AND st_conta <> 'cancelada' AND vl_baixado < vl_receber)
           OR EXISTS (SELECT 1 FROM vw_conta_pagar WHERE id_contrato = p_contrato AND st_conta <> 'cancelada' AND vl_baixado < vl_pagar) THEN
            RAISE EXCEPTION 'RN44: a venda so e encerrada com todas as contas do contrato quitadas';
        END IF;
        UPDATE imovel SET st_imovel = 'vendido' WHERE id_imovel = c.id_imovel;
    END IF;
    UPDATE contrato SET st_contrato = 'encerrado', dt_termino = p_data WHERE id_contrato = p_contrato;
END $$;

-- =====================================================================
-- PONTO 6 - AUDITORIA LIGADA AO REGISTRO AFETADO
-- =====================================================================
-- RN40: cada criacao, alteracao ou cancelamento gera um registro de auditoria ligado ao registro
-- por exatamente uma das sete referencias, e cada campo alterado vira uma linha de AUDITORIA_CAMPO.
-- A aplicacao informa quem esta agindo com:  SET LOCAL crmoveis.id_usuario = '<id>';
CREATE FUNCTION tg_auditoria() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE v_usuario INTEGER; v_acao TEXT := 'criacao'; v_id INTEGER;
        v_new JSONB := to_jsonb(NEW); v_old JSONB;
BEGIN
    v_usuario := NULLIF(current_setting('crmoveis.id_usuario', TRUE), '')::INTEGER;
    IF v_usuario IS NULL THEN
        RAISE EXCEPTION 'RN40: informe o usuario responsavel (SET LOCAL crmoveis.id_usuario) antes de gravar em %', TG_TABLE_NAME;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        v_old := to_jsonb(OLD);
        IF v_old = v_new THEN RETURN NULL; END IF;
        IF (v_new ->> 'fl_cancelada' = 'true' AND v_old ->> 'fl_cancelada' = 'false')
           OR (v_new ->> 'st_contrato' = 'cancelado' AND v_old ->> 'st_contrato' <> 'cancelado')
           OR (v_new ->> 'st_comissao' = 'cancelada' AND v_old ->> 'st_comissao' <> 'cancelada') THEN
            v_acao := 'cancelamento';
        ELSE
            v_acao := 'alteracao';
        END IF;
    END IF;
    INSERT INTO auditoria (id_usuario, tp_acao, id_contrato, id_proposta, id_comissao_contrato, id_comissao_corretor,
                           id_conta_receber, id_recebimento_conta, nr_recebimento,
                           id_conta_pagar, id_pagamento_conta, nr_pagamento)
    VALUES (v_usuario, v_acao,
            CASE WHEN TG_TABLE_NAME = 'contrato'      THEN (v_new ->> 'id_contrato')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'proposta'      THEN (v_new ->> 'id_proposta')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'comissao'      THEN (v_new ->> 'id_contrato')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'comissao'      THEN (v_new ->> 'id_corretor')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'conta_receber' THEN (v_new ->> 'id_conta_receber')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'recebimento'   THEN (v_new ->> 'id_conta_receber')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'recebimento'   THEN (v_new ->> 'nr_recebimento')::SMALLINT END,
            CASE WHEN TG_TABLE_NAME = 'conta_pagar'   THEN (v_new ->> 'id_conta_pagar')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'pagamento'     THEN (v_new ->> 'id_conta_pagar')::INTEGER END,
            CASE WHEN TG_TABLE_NAME = 'pagamento'     THEN (v_new ->> 'nr_pagamento')::SMALLINT END)
    RETURNING id_auditoria INTO v_id;
    IF TG_OP = 'UPDATE' THEN
        INSERT INTO auditoria_campo (id_auditoria, nm_campo, ds_valor_anterior, ds_valor_novo)
        SELECT v_id, n.key, v_old ->> n.key, n.value #>> '{}'
          FROM jsonb_each(v_new) n
         WHERE n.value IS DISTINCT FROM v_old -> n.key;
    END IF;
    RETURN NULL;
END $$;

-- RN40, PO04: registros auditados nao sao excluidos, so cancelados.
CREATE FUNCTION tg_bloqueia_exclusao() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'PO04/RN40: registros de % nao sao excluidos; use o cancelamento', TG_TABLE_NAME;
END $$;

-- RNF04: a auditoria e somente de inclusao.
CREATE FUNCTION tg_auditoria_imutavel() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'RNF04: registros de % nao podem ser alterados nem excluidos', TG_TABLE_NAME;
END $$;
CREATE TRIGGER tg_contrato_auditoria AFTER INSERT OR UPDATE ON contrato
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_contrato_sem_exclusao BEFORE DELETE ON contrato
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_proposta_auditoria AFTER INSERT OR UPDATE ON proposta
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_proposta_sem_exclusao BEFORE DELETE ON proposta
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_comissao_auditoria AFTER INSERT OR UPDATE ON comissao
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_comissao_sem_exclusao BEFORE DELETE ON comissao
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_conta_receber_auditoria AFTER INSERT OR UPDATE ON conta_receber
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_conta_receber_sem_exclusao BEFORE DELETE ON conta_receber
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_recebimento_auditoria AFTER INSERT OR UPDATE ON recebimento
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_recebimento_sem_exclusao BEFORE DELETE ON recebimento
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_conta_pagar_auditoria AFTER INSERT OR UPDATE ON conta_pagar
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_conta_pagar_sem_exclusao BEFORE DELETE ON conta_pagar
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_pagamento_auditoria AFTER INSERT OR UPDATE ON pagamento
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria();
CREATE TRIGGER tg_pagamento_sem_exclusao BEFORE DELETE ON pagamento
    FOR EACH ROW EXECUTE FUNCTION tg_bloqueia_exclusao();
CREATE TRIGGER tg_auditoria_imutavel BEFORE UPDATE OR DELETE ON auditoria
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria_imutavel();
CREATE TRIGGER tg_auditoria_campo_imutavel BEFORE UPDATE OR DELETE ON auditoria_campo
    FOR EACH ROW EXECUTE FUNCTION tg_auditoria_imutavel();

-- =====================================================================
-- LOCALIZACAO: O BAIRRO E DA CIDADE CERTA (RN51, RN52)
-- =====================================================================
-- RN51: o bairro do imovel e da cidade do CEP do imovel. Um CHECK nao resolve: ele so enxerga a linha que
-- esta sendo gravada, e a cidade esta em outras tabelas (bairro e cep). As FKs garantem que o bairro e o CEP
-- existem; o gatilho confere se os dois sao da mesma cidade.
CREATE FUNCTION tg_imovel_bairro_da_cidade() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_bairro        VARCHAR;
    v_cidade_bairro INTEGER;
    v_nome_cb       VARCHAR;
    v_cidade_cep    INTEGER;
    v_nome_cc       VARCHAR;
BEGIN
    SELECT b.nm_bairro, b.id_cidade, ci.nm_cidade INTO v_bairro, v_cidade_bairro, v_nome_cb
      FROM bairro b JOIN cidade ci ON ci.id_cidade = b.id_cidade WHERE b.id_bairro = NEW.id_bairro;
    SELECT c.id_cidade, ci.nm_cidade INTO v_cidade_cep, v_nome_cc
      FROM cep c JOIN cidade ci ON ci.id_cidade = c.id_cidade WHERE c.nr_cep = NEW.nr_cep;
    IF v_cidade_bairro <> v_cidade_cep THEN
        RAISE EXCEPTION 'RN51: o bairro % fica em %, mas o CEP % e de %', v_bairro, v_nome_cb, NEW.nr_cep, v_nome_cc;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_imovel_bairro BEFORE INSERT OR UPDATE OF id_bairro, nr_cep ON imovel
    FOR EACH ROW EXECUTE FUNCTION tg_imovel_bairro_da_cidade();

-- RN52: os bairros aceitos pelo perfil de interesse sao da cidade do perfil (o perfil sem cidade nao aceita bairro).
CREATE FUNCTION tg_perfil_bairro_da_cidade() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    v_cidade_perfil INTEGER;
    v_cidade_bairro INTEGER;
    v_bairro        VARCHAR;
BEGIN
    SELECT id_cidade INTO v_cidade_perfil FROM perfil_interesse WHERE id_usuario = NEW.id_usuario AND nr_perfil = NEW.nr_perfil;
    SELECT id_cidade, nm_bairro INTO v_cidade_bairro, v_bairro FROM bairro WHERE id_bairro = NEW.id_bairro;
    IF v_cidade_bairro IS NOT NULL AND v_cidade_perfil IS DISTINCT FROM v_cidade_bairro THEN
        RAISE EXCEPTION 'RN52: o bairro % nao e da cidade do perfil de interesse', v_bairro;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_perfil_interesse_bairro BEFORE INSERT OR UPDATE ON perfil_interesse_bairro
    FOR EACH ROW EXECUTE FUNCTION tg_perfil_bairro_da_cidade();

-- A cidade nao muda por baixo das duas regras: a do perfil que tem bairros aceitos, a do bairro que ja tem
-- imovel ou perfil e a do CEP que ja tem imovel ficam fixas (RN51, RN52).
CREATE FUNCTION tg_cidade_estavel() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_cidade IS NOT DISTINCT FROM OLD.id_cidade THEN
        RETURN NEW;
    END IF;
    IF TG_TABLE_NAME = 'perfil_interesse' THEN
        IF EXISTS (SELECT 1 FROM perfil_interesse_bairro WHERE id_usuario = NEW.id_usuario AND nr_perfil = NEW.nr_perfil) THEN
            RAISE EXCEPTION 'RN52: tire os bairros aceitos antes de trocar a cidade do perfil';
        END IF;
    ELSIF TG_TABLE_NAME = 'bairro' THEN
        IF EXISTS (SELECT 1 FROM imovel WHERE id_bairro = NEW.id_bairro)
           OR EXISTS (SELECT 1 FROM perfil_interesse_bairro WHERE id_bairro = NEW.id_bairro) THEN
            RAISE EXCEPTION 'RN51: o bairro % tem imoveis ou perfis e nao pode mudar de cidade', NEW.nm_bairro;
        END IF;
    ELSIF TG_TABLE_NAME = 'cep' THEN
        IF EXISTS (SELECT 1 FROM imovel WHERE nr_cep = NEW.nr_cep) THEN
            RAISE EXCEPTION 'RN51: o CEP % tem imoveis e nao pode mudar de cidade', NEW.nr_cep;
        END IF;
    END IF;
    RETURN NEW;
END $$;
CREATE TRIGGER tg_perfil_interesse_cidade BEFORE UPDATE OF id_cidade ON perfil_interesse
    FOR EACH ROW EXECUTE FUNCTION tg_cidade_estavel();
CREATE TRIGGER tg_bairro_cidade BEFORE UPDATE OF id_cidade ON bairro
    FOR EACH ROW EXECUTE FUNCTION tg_cidade_estavel();
CREATE TRIGGER tg_cep_cidade BEFORE UPDATE OF id_cidade ON cep
    FOR EACH ROW EXECUTE FUNCTION tg_cidade_estavel();
