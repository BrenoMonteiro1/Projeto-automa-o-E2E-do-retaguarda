*** Settings ***
Documentation    Suite de testes E2E para o Retaguarda VB6.
Resource         ../resources/base.robot

*** Test Cases ***
Cenario 01: Abrir Retaguarda e autenticar usuario
    [Documentation]    Executa login com usuario e senha informados no passo, aguarda 3 segundos apos o acesso e fecha o sistema.
    [Tags]             smoke    login    vb6
    Abrir Retaguarda com usuario "7240" e senha "123123"
    Validar processo do Retaguarda encerrado
