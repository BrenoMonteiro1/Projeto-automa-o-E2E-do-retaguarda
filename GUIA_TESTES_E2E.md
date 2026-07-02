# Guia de Testes E2E do Retaguarda

## Objetivo

Criar uma base incremental para automatizar o Retaguarda `GestaoConfig.exe` sem depender do codigo fonte da aplicacao.

## Estrutura

- `tests/`: suites Robot Framework.
- `resources/variables.robot`: caminhos e tempos tecnicos do fluxo.
- `resources/keywords.robot`: acoes reutilizaveis.
- `scripts/`: utilitarios usados pelas keywords.
- `results/`: saida de execucao, ignorada pelo Git.

## Linguagens e frameworks

- Robot Framework: define suites, cenarios, keywords e parametros dos testes.
- Biblioteca Robot `Process`: biblioteca nativa usada para chamar o script PowerShell.
- Python: runtime do Robot Framework.
- PowerShell: executa a automacao desktop que o Robot chama para abrir, preencher e fechar o Retaguarda.
- Win32/User32: APIs nativas do Windows usadas pelo PowerShell para localizar janela, campos e botoes do VB6.

O projeto PDV usa Python + Robot Framework + AppiumLibrary + Appium 2.0 + WinAppDriver. Em automacao web, o padrao comum e Python + Robot Framework + SeleniumLibrary. Para o Retaguarda, o smoke atual usa Robot Framework + biblioteca `Process` + PowerShell nativo porque a aplicacao VB6 nao expos os campos de login de forma confiavel para Appium/WinAppDriver.

## Estrategia inicial

O login usa handles nativos do Windows enquanto os elementos VB6 ainda nao estao mapeados pelo UI Automation.

Antes de preencher o login, a automacao fecha qualquer instancia aberta do `GestaoConfig`, abre o sistema novamente, aguarda a tela estabilizar, informa usuario e senha recebidos pelo teste, clica no botao de acesso, aguarda 3 segundos e fecha o sistema.

Os dados de usuario e senha ficam no proprio passo do teste, no mesmo estilo usado no projeto PDV:

```robot
Abrir Retaguarda com usuario "8043" e senha "123123"
```

## Cuidados

- Nao alterar o repositorio `nfl-qa-automacao-pdv`; ele e apenas referencia.
- Evitar dados de teste de producao.
- Manter seletores em `resources/variables.robot`.
- Manter fluxos de negocio em `tests/`.
- Preferir keywords reutilizaveis para acoes comuns.
- Atualizar sempre `README.md` e `GUIA_TESTES_E2E.md` quando houver mudanca de fluxo, parametros, tecnologias ou execucao.
