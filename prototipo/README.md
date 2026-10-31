# CRMoveis — prototipo

Prototipo navegavel do CRMoveis, feito para **analisar de perto o modelo logico**: cada tela le e grava nas 50 tabelas do banco da entrega final, e as regras de negocio sao as do proprio PostgreSQL. Quando uma gravacao viola uma regra (chave, CHECK ou gatilho), o prototipo mostra a mensagem do banco, com o codigo da regra (RN, PO) e a justificativa da restricao.

> **Base:** o app **SP Imoveis CRM** (Flask + SQLite) do nosso amigo, que deu a ideia inicial do projeto. Vieram dele o layout (barra lateral, area de trabalho, painel de detalhes), o estilo (`static/styles.css`, copiado sem alteracao), o funil em colunas com cards arrastaveis, as mensagens Nota / Recebida / Enviada, a selecao de imoveis por perfil e a API de integracao com o N8N (`/api/integration/...`). O que mudou: o SQLite com 5 tabelas deu lugar ao PostgreSQL com o nosso modelo logico, e tudo o que era texto livre (papel, corretor, imoveis de interesse, etapa, bairro) virou chave estrangeira.

## Como rodar (Windows)

1. Instale o **PostgreSQL 13 ou superior** e o **Python 3** (marque “Add python.exe to PATH”).
2. Na pasta do repositorio, rode **`executar_tudo.bat`**: ele cria o banco `crmoveis` vazio, as tabelas, as restricoes, a massa de dados, as consultas e os testes (pede a senha do PostgreSQL uma vez).
3. Nesta pasta (`prototipo/`), rode **`INICIAR_PROTOTIPO.bat`**. Na primeira vez ele cria o ambiente Python, instala `flask` e `psycopg`, pergunta a senha do PostgreSQL (grava em `.env`) e abre o navegador em **http://127.0.0.1:5003**.

Linux/macOS: `../executar_tudo.sh` e depois `./iniciar_prototipo.sh`.

Para voltar aos dados originais, basta rodar `executar_tudo` de novo: o banco e recriado do zero.

### Abrir direto no Chrome, sem o INICIAR toda vez

Depois que o `INICIAR_PROTOTIPO.bat` funcionou uma vez, rode **`INSTALAR_INICIAR_COM_WINDOWS.bat`** (o mesmo recurso do app original). Ele faz o prototipo iniciar sozinho, sem janela, sempre que o Windows liga, e cria o atalho **CRMoveis** na Area de Trabalho. A partir dai, basta abrir o atalho ou digitar **http://127.0.0.1:5003** no Chrome (vale salvar nos favoritos). Para desligar e desfazer: **`REMOVER_INICIAR_COM_WINDOWS.bat`**. Se algo der errado com ele rodando sem janela, as mensagens ficam em `prototipo.log`, nesta pasta.

Antes de rodar `executar_tudo` de novo, desligue o prototipo com o `REMOVER_INICIAR_COM_WINDOWS.bat`: o banco nao pode ser recriado enquanto o prototipo estiver conectado a ele.

## O que cada tela mostra do modelo logico

| Tela | Tabelas | O que da para ver e testar |
|---|---|---|
| **Painel** | visoes `vw_*`, contas, conversas | Indicadores e as consultas de auditoria rodando ao vivo |
| **CRM (funil)** | `funil_estagio`, `conversa`, `historico_estagio`, `mensagem`, `conversa_tag`, `conversa_imovel`, `tarefa`, `automacao_*` | Arrastar o card grava a etapa e o historico na mesma transacao (RN14); corretor que saiu e recusado (RN32); etiqueta repetida e recusada (PK da N:N) |
| **Pessoas e papeis** | `usuario` + 8 subtipos, `origem_contato`, `telefone`, `perfil_interesse`, `perfil_interesse_tipo`, `perfil_interesse_bairro` | A mesma pessoa com varios papeis (RN02); encerrar papel (dt_fim); sem papel o banco recusa (RN01); telefone como entidade fraca da pessoa, numero compartilhado com um titular (RN03); perfil que aceita varios tipos de imovel (RN47) e varios bairros da sua cidade, escolhidos da tabela `bairro` (RN52); anonimizacao, que tambem apaga os telefones e passa a titularidade adiante (PO07) |
| **Imoveis → Buscar e cadastrar** | `imovel`, `tipo_imovel`, `bairro`, `cep`, `cidade`, `uf`, `foto`, `caracteristica`, `imovel_caracteristica` | Busca dos imoveis cadastrados por tipo (da tabela `tipo_imovel`), cidade, bairro (da tabela `bairro`), finalidade, situacao, quartos e texto; botao **Novo imovel** com o tipo escolhido da lista (FK, RN48), o bairro escolhido entre os da cidade do CEP (FK e gatilho, RN51), proprietario no papel certo (RN32), valor exigido pela finalidade (CHECK) e CEP novo com a cidade (3FN) |
| **Seletor por perfil** | `perfil_interesse`, `perfil_interesse_tipo`, `perfil_interesse_bairro`, `imovel` | A “Selecao Interna” do app original, agora sobre o banco: soma pontos o imovel de qualquer tipo e de qualquer bairro aceito pelo perfil (o bairro e comparado pela chave, nao pelo texto) |
| **Negociacao** | `visita`, `proposta`, `contrato`, `comissao`, `financiamento`, `documento`, `tipo_documento` | Desconto acima de 10% so com o administrador (PO03); contraproposta (RESPONDE); contrato em rascunho → assinatura (RN36) → cancelar, rescindir ou encerrar pelos procedimentos do banco (RN37, RN43, RN44); comissoes acima de 100% recusadas (RN20); documentos do contrato com o tipo da tabela `tipo_documento` (RN53) |
| **Financeiro** | `conta_receber`, `recebimento`, `conta_pagar`, `pagamento`, `categoria_financeira`, `forma_pagamento` | Categoria de despesa numa conta a receber recusada (RN26); forma de pagamento da lista (RN50); baixa acima do valor recusada (RN29); recebimento de aluguel gera o repasse pelo gatilho (RN30); comissao so paga pelo administrador (PO01); situacao calculada na visao (derivado) |
| **Conciliacao** | `conta_bancaria`, `movimento_bancario`, baixas | Conciliar com movimento da direcao errada ou acima do valor e recusado (RN45) |
| **Automacao N8N** | `automacao_execucao`, `automacao_log`, `mensagem` | A API herdada do app original; a mesma demanda ou a mesma mensagem (wamid) nao e gravada duas vezes (RN31) |
| **Auditoria** | `auditoria`, `auditoria_campo` | Quem fez o que, campo por campo, gravado pelos gatilhos (RN40) |
| **Consultas** | todas | As 15 gerenciais e as 13 de auditoria, com pergunta, decisao e SQL |
| **Modelo logico** | catalogo do PostgreSQL | Cada tabela: colunas, chaves, FKs com o relacionamento do DER e a politica ON DELETE, CHECKs com a justificativa, gatilhos, indices e os dados, com **busca** na aba Dados (texto em todas as colunas; na tabela `imovel`, tambem por tipo, finalidade, situacao, cidade, bairro, quartos e valor) e o SQL executado; diagramas e a evolucao desde o app original; console SQL somente leitura |

## Roteiro de demonstracao (5 minutos)

1. **Agindo como** Carla (administradora). Abra **CRM**, arraste uma conversa de “Qualificacao” para “Visita” e abra o card: o historico ganhou uma linha.
2. No card, troque o corretor para **Sergio Dias (saiu)**: o banco recusa (RN32).
3. **Negociacao → Contratos → contrato 5**: inclua uma comissao de 95% para o Paulo Nunes. O banco recusa (RN20: a soma ficaria em 135%) e nada e gravado.
4. No mesmo contrato, **libere** a comissao pendente de Rui: nasce a conta a pagar. Troque **Agindo como** para Renata (financeiro), abra a conta e tente pagar: recusado (PO01). Volte para Carla e pague.
5. **Financeiro → Contas a receber**, filtre “atrasada”, abra um aluguel e registre um recebimento parcial: o aviso mostra o repasse gerado pelo gatilho (RN30).
6. **Modelo logico → conta_pagar → Chaves estrangeiras**: os relacionamentos do DER (GERA DESPESA, FAVORECE, CUSTEIA, REPASSA…), a cardinalidade e o que acontece ao excluir.
7. **Auditoria**: as gravacoes dos passos 4 e 5 aparecem com o usuario que agiu. A do passo 3 nao aparece, porque o banco recusou e nada foi gravado.
8. **Imoveis → Buscar e cadastrar**: filtre o tipo **Cobertura** e depois clique em **Novo imovel**. Cadastre uma cobertura para a Ana Souza no CEP 07061000: a lista de bairros mostra so os de Guarulhos, a cidade do CEP. Tente antes deixar o valor de venda vazio (o banco recusa: CHECK) e escolher como proprietario o Bruno Lima, que e so cliente (RN32). Depois de cadastrado, o imovel aparece na busca.
9. **Pessoas → Bruno Lima → Novo perfil**: marque **Apartamento** e **Cobertura**, escolha **Sao Paulo** e marque os bairros **Tatuape** e **Mooca**. O perfil grava dois registros em `perfil_interesse_tipo` e dois em `perfil_interesse_bairro` (N:N), e o **Seletor por perfil** passa a pontuar os dois tipos e os dois bairros.
10. **Modelo logico → imovel → Dados**: procure por texto (Tatuape, IMB-3519) ou filtre por tipo, finalidade, cidade, bairro, quartos e valor. O resultado mostra as colunas da tabela `imovel` e, com ponto no nome (`bairro.nm_bairro`), as que vem das tabelas ligadas pelas FKs; abra **SQL executado** para ver o SELECT com os JOINs. Clique numa linha para abrir o imovel.

Na apresentacao final, a demonstracao usa os passos 3, 5 e 7 (veja [`../apresentacao/README.md`](../apresentacao/README.md)). Antes de apresentar, rode o `executar_tudo` de novo para voltar aos dados originais.

## Limites (e um prototipo)

- Nao tem login: “Agindo como” escolhe o usuario que o banco usa para a auditoria e as permissoes de pagamento.
- As fotos e documentos da massa de dados apontam para enderecos ficticios; as imagens sao ilustrativas.
- O console SQL roda numa transacao somente leitura: gravacoes sao recusadas pelo proprio PostgreSQL.
- O envio real pelo WhatsApp (o Selenium do app original) nao faz parte do prototipo; a API de integracao grava o resultado como o N8N faria.

## Arquivos

| Arquivo | Conteudo |
|---|---|
| `app.py` | Servidor Flask: telas, API e a API de integracao com o N8N. Cada requisicao e uma transacao; o usuario que esta agindo vai para `crmoveis.id_usuario`, que a auditoria grava |
| `templates/index.html`, `static/app.js` | A pagina unica e o JavaScript (sem frameworks, como no app original) |
| `static/styles.css` | Estilo do SP Imoveis CRM, sem alteracao |
| `static/crmoveis.css` | Acrescimos do CRMoveis |
| `dados_modelo.json` | O que o catalogo do banco nao sabe: area, entidade do DER, justificativas de PK, FK e CHECK (gerado da documentacao do modelo logico) |
| `consultas.json` | As consultas gerenciais e de auditoria (as mesmas de `sql/consultas` e `sql/auditoria`) |
| `INICIAR_PROTOTIPO.bat` / `.ps1`, `iniciar_prototipo.sh` | Inicializacao |
| `INSTALAR_INICIAR_COM_WINDOWS.bat`, `REMOVER_INICIAR_COM_WINDOWS.bat` (+ `.ps1`) | Inicio automatico com o Windows, sem janela, e o atalho da Area de Trabalho |
| `.env.example` | Modelo da configuracao (`DATABASE_URL`, porta e token do N8N) |
