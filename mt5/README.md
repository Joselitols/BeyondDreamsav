# BD Gerenciador de Conta — travas reais para MT5

Sistema de gerenciamento de conta para MetaTrader 5 com **travas que se aplicam de verdade** — não são só alertas. Quando um limite é rompido, o EA guardião **fecha todas as posições da conta** (de qualquer símbolo, de qualquer robô, inclusive trades manuais), **cancela todas as ordens pendentes** e **mantém a conta zerada** até a trava expirar: qualquer posição aberta durante o bloqueio é fechada em até 1 segundo.

O estado da trava é **persistido em disco** (pasta `Common`) e em GlobalVariables do terminal. Remover o EA do gráfico, trocar de gráfico, reiniciar o terminal ou reiniciar o computador **não reseta a trava** — ao religar, ela recarrega e continua valendo.

## Arquivos

| Arquivo | Onde instalar | O que é |
|---|---|---|
| `Experts/BD_GerenciadorDeConta.mq5` | `MQL5/Experts/` | O EA guardião. Roda em **um único gráfico** (qualquer símbolo/timeframe) e vigia a conta inteira. |
| `Include/BD_TravaDeConta.mqh` | `MQL5/Include/` | Protocolo de integração para os seus outros EAs respeitarem a trava (opcional, recomendado). |

## As 7 travas

| # | Trava | Dispara quando | Libera quando |
|---|---|---|---|
| 1 | **Perda diária máxima** | Equity cai X% ou $X abaixo da âncora do dia | 00:00 do servidor (dia seguinte) |
| 2 | **Perda semanal máxima** | Equity cai X% ou $X abaixo da âncora da semana | Segunda-feira 00:00 do servidor |
| 3 | **Drawdown máximo** | Equity cai X% abaixo do topo histórico (high-water mark) | **Só liberação manual** — reveja a estratégia antes |
| 4 | **Meta diária de ganho** | Equity sobe X% ou $X acima da âncora do dia (protege o lucro do dia) | 00:00 do servidor |
| 5 | **Anti-tilt** | N trades perdedores seguidos (conta toda) | Após X minutos de pausa |
| 6 | **Janela de operação** | Existe posição/ordem fora do horário permitido | No próximo início de janela |
| 7 | **Trava manual** | `InpTravaManual = true` ou comando via F3 | Você desativar |

Todas as travas usam **equity** (não balance), então perda flutuante conta — no estilo das mesas proprietárias (FTMO etc.).

## Modos de enforcement (`InpModo`)

- **`MODO_SOMENTE_ALERTA`** — só avisa (Print + Alert). Não fecha nada. Use para calibrar limites sem risco.
- **`MODO_PROTEGER`** (padrão) — fecha tudo ao travar e re-fecha qualquer coisa que apareça enquanto travado. É a trava real para o dia a dia.
- **`MODO_DESLIGAR_TERMINAL`** — modo nuclear: fecha tudo e depois **fecha o terminal MT5 inteiro** (`TerminalClose`). Nada mais abre até você religar o MT5 — e ao religar, a trava recarrega do disco e continua valendo (se você reabrir posição, ela é fechada e o terminal cai de novo). Para quem sabe que vai tentar burlar a própria regra.

## Instalação

1. No MT5: `Arquivo → Abrir Pasta de Dados → MQL5`.
2. Copie `BD_GerenciadorDeConta.mq5` para `Experts/` e `BD_TravaDeConta.mqh` para `Include/`.
3. Abra o `.mq5` no MetaEditor e compile (F7). Deve compilar sem erros e sem warnings.
4. Abra **um** gráfico qualquer (ex.: EURUSD M15) e arraste o EA para ele.
5. Marque **"Permitir Algo Trading"** nas opções do EA e deixe o botão **Algo Trading** da barra superior **ligado** — sem ele o guardião enxerga mas não consegue fechar nada (o painel avisa em vermelho se estiver desligado).
6. Configure os limites e clique OK. O painel no canto do gráfico mostra o estado ao vivo.

> Por padrão `InpAllowLiveTrading = false`: em conta **real** o EA se recusa a iniciar até você conscientemente mudar para `true`. Valide primeiro em demo.

## Parâmetros principais

| Parâmetro | Padrão | Significado |
|---|---|---|
| `InpModo` | `MODO_PROTEGER` | Modo de enforcement (acima) |
| `InpPerdaDiariaPct` / `InpPerdaDiariaUsd` | `5.0` / `0` | Perda diária máx. em % / em moeda (0 = desativado) |
| `InpPerdaSemanalPct` / `InpPerdaSemanalUsd` | `10.0` / `0` | Perda semanal máx. |
| `InpDrawdownMaxPct` | `20.0` | DD máx. do topo histórico de equity |
| `InpMetaDiariaPct` / `InpMetaDiariaUsd` | `0` / `0` | Meta de ganho que "fecha o caixa" do dia (0 = desativado) |
| `InpMaxPerdasSeguidas` / `InpPausaTiltMin` | `3` / `60` | Perdas seguidas para pausar / duração da pausa |
| `InpUsarJanela`, `InpJanelaHoraInicio/Fim` | `false`, `9`–`18` | Janela de operação em **hora do broker** (suporta virar meia-noite, ex.: 22→6) |
| `InpFecharForaJanela` | `true` | Zera a conta fora da janela |
| `InpTravaManual` | `false` | Kill switch: trava tudo enquanto `true` |
| `InpMagicNumber` | `88900001` | Família 889 = gerenciamento (não abre trades, só fecha) |

Sugestão de calibração (conservador → agressivo): perda diária 3–5%, semanal 6–10%, DD máx. 15–20%. Acima de 15% de perda diária não é gerenciamento, é torcida.

## Comandos manuais sem mexer no EA (janela F3)

Pressione **F3** no MT5 (GlobalVariables) e crie a variável (substitua `LOGIN` pelo número da sua conta):

- `BDGC_LOGIN_CMD_TRAVAR` = `1` → trava manual imediata (fecha tudo).
- `BDGC_LOGIN_CMD_LIBERAR` = `1` → libera a trava atual (ex.: a de drawdown máximo). Se o limite ainda estiver rompido, o guardião **retrava no ciclo seguinte** — liberar não é burlar.

## Integração com os seus outros EAs (recomendado)

A trava já funciona sozinha (o guardião fecha o que os outros EAs abrirem durante o bloqueio), mas o ideal é que os seus robôs **nem tentem abrir**. Para isso:

```mql5
#include <BD_TravaDeConta.mqh>

void OnTick()
{
   if(BD_ContaTravada())
   {
      // opcional: PrintFormat("pausado: %s", BD_MotivoTravaTexto());
      return;                      // nao abre nada enquanto travado
   }
   // ... logica normal do seu EA
}
```

Funções disponíveis: `BD_ContaTravada()`, `BD_MotivoTrava()`, `BD_MotivoTravaTexto()`, `BD_TravaExpiraEm()` e `BD_GerenciadorAtivo()` (heartbeat — use se quiser que o seu EA se recuse a operar sem o guardião ligado).

## O que esta trava NÃO consegue fazer (honestidade acima de marketing)

O MT5 **não oferece** a um EA como desligar o botão de comprar/vender da plataforma nem o botão Algo Trading. Portanto:

- Um trade manual aberto durante a trava **abre** — e é **fechado em até 1 segundo** pelo guardião. O custo é o spread dessa entrada. É dissuasão real, não parede física.
- Se você **desligar o Algo Trading** ou **remover o EA**, o enforcement para (a trava continua salva e volta a valer quando religar). O `MODO_DESLIGAR_TERMINAL` reduz essa brecha; a única trava 100% à prova do próprio operador é **na corretora**: conta com limite de perda (mesas proprietárias) ou redução de alavancagem a pedido.
- O EA precisa do terminal **aberto e conectado**. Para operação séria, rode em VPS.

## Validação antes de conta real

1. **Demo, 10 dias úteis** com os seus EAs reais rodando junto.
2. Force cada trava ao menos uma vez (abra trade manual grande em demo e veja o flatten; confira o log `[ENFORCE]`).
3. Reinicie o terminal com trava ativa e confirme que ela **volta travada**.
4. Confira a virada do dia do **servidor** (00:00 do broker, não o seu fuso).
5. Só então `InpAllowLiveTrading = true` em conta real — começando com limites apertados.
