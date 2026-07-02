# Automacao E2E do Retaguarda

Projeto inicial de automacao E2E para o Retaguarda `GestaoConfig.exe`, uma aplicacao desktop VB6 sem acesso ao codigo fonte.

## Linguagens e frameworks

Este projeto usa:

- Robot Framework: linguagem de automacao dos cenarios e keywords.
- Biblioteca Robot `Process`: biblioteca nativa do Robot usada para executar o script PowerShell a partir do teste.
- Python: runtime usado pelo Robot Framework.
- PowerShell: camada auxiliar para interagir com janelas e controles VB6 por handles nativos do Windows.
- Win32/User32: APIs nativas do Windows chamadas pelo PowerShell para localizar janela, clicar e digitar nos campos.

Neste momento, o Retaguarda nao esta usando `AppiumLibrary`, `SeleniumLibrary`, Appium ou WinAppDriver no smoke de login. No PDV, os elementos aparecem com locators confiaveis para AppiumLibrary, Appium 2.0 e WinAppDriver. Em testes web, o equivalente comum e SeleniumLibrary. No Retaguarda VB6, os campos internos nao ficaram confiaveis pelo UI Automation, entao o fluxo inicial ficou em Robot Framework + biblioteca `Process` + PowerShell nativo.

## Arquitetura

```text
Robot Framework
    |
Biblioteca Process
    |
PowerShell + handles nativos do Windows
    |
Retaguarda GestaoConfig.exe
```

## Pre-requisitos

- Python no PATH.
- Robot Framework instalado.
- Atalho do sistema em `C:\Users\breno.figueiredo\Desktop\GestaoConfig.exe - Atalho.lnk`.

## Execucao

Executar o smoke inicial:

```powershell
robot -d results .\tests\tests.robot
```

Executar validacao sintatica:

```powershell
robot --dryrun -d results .\tests\tests.robot
```

## Primeiro fluxo automatizado

O smoke inicial fecha uma instancia aberta do Retaguarda, abre o atalho novamente, aguarda a tela de login estabilizar e executa. Os valores de usuario e senha sao passados como parametros no passo do teste, seguindo o estilo do projeto PDV:

```robot
Abrir Retaguarda com usuario "8043" e senha "123123"
```

1. Informa `8043`.
2. Informa `123123`.
3. Clica no botao de acesso.
4. Aguarda 3 segundos.
5. Fecha o Retaguarda.

Os relatorios sao gerados em `results`.

## Manutencao

Sempre que o fluxo, parametros, tecnologias ou forma de execucao mudarem, atualizar tambem `README.md` e `GUIA_TESTES_E2E.md`.
