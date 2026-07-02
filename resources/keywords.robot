*** Settings ***
Documentation    Keywords de abertura e login do Retaguarda VB6.
Library          Process
Resource         variables.robot

*** Keywords ***
Abrir Retaguarda com usuario "${usuario}" e senha "${senha}"
    [Documentation]    Abre o Retaguarda, autentica, aguarda 3 segundos apos o acesso e fecha o sistema.
    ${resultado}=    Run Process
    ...    powershell
    ...    -NoProfile
    ...    -ExecutionPolicy    Bypass
    ...    -File    ${LOGIN_SCRIPT}
    ...    -ShortcutPath    ${RETAGUARDA_SHORTCUT}
    ...    -User    ${usuario}
    ...    -Password    ${senha}
    ...    -WaitAfterSeconds    ${LOGIN_WAIT_SECONDS}
    ...    -LoginReadyDelaySeconds    ${LOGIN_READY_DELAY_SECONDS}
    ...    -PasswordSettleDelaySeconds    ${LOGIN_PASSWORD_DELAY_SECONDS}
    ...    -TypingDelayMilliseconds    ${LOGIN_TYPING_DELAY_MS}
    Log    ${resultado.stdout}
    Run Keyword If    ${resultado.rc} != 0    Fail    Falha ao abrir/logar no Retaguarda: ${resultado.stderr}

Validar processo do Retaguarda encerrado
    [Documentation]    Confirma que o GestaoConfig foi fechado ao final do fluxo.
    ${comando}=    Set Variable    if (Get-Process -Name '${RETAGUARDA_PROCESS_NAME}', 'atualiza' -ErrorAction SilentlyContinue) { exit 1 } else { exit 0 }
    ${resultado}=    Run Process    powershell    -NoProfile    -Command    ${comando}
    Should Be Equal As Integers    ${resultado.rc}    0    Retaguarda ainda esta em execucao.
