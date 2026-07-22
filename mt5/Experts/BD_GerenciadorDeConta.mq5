//+------------------------------------------------------------------+
//|                                      BD_GerenciadorDeConta.mq5   |
//|  Beyond Dreams - Gerenciador de Conta com travas reais para MT5  |
//|                                                                  |
//|  EA guardiao: roda em UM grafico qualquer e vigia a CONTA        |
//|  inteira (todas as posicoes, de todos os simbolos, manuais ou    |
//|  de outros EAs). Quando uma trava dispara, ele FECHA tudo,       |
//|  CANCELA ordens pendentes e mantem a conta zerada ate a trava    |
//|  expirar - qualquer posicao aberta durante a trava e fechada     |
//|  em ate 1 segundo. Estado persistido em GlobalVariables + disco  |
//|  (pasta Common), entao remover e recolocar o EA, trocar de       |
//|  grafico ou reiniciar o terminal NAO reseta a trava.             |
//|                                                                  |
//|  Travas implementadas:                                           |
//|    1. Perda diaria maxima (% e/ou $)      -> trava ate 00:00     |
//|    2. Perda semanal maxima (% e/ou $)     -> trava ate segunda   |
//|    3. Drawdown maximo da conta (do topo)  -> trava ate liberar   |
//|    4. Meta diaria de ganho (protege o dia)-> trava ate 00:00     |
//|    5. Sequencia de perdas (anti-tilt)     -> pausa em minutos    |
//|    6. Janela de operacao (hora broker)    -> fora dela, flatten  |
//|    7. Trava manual (kill switch)          -> enquanto ativada    |
//|                                                                  |
//|  Integracao com seus outros EAs: MQL5/Include/BD_TravaDeConta.mqh|
//+------------------------------------------------------------------+
#property copyright "Beyond Dreams Audiovisual"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//+------------------------------------------------------------------+
//| ENUMS                                                             |
//+------------------------------------------------------------------+
enum ENUM_MODO_ENFORCEMENT
{
   MODO_SOMENTE_ALERTA = 0,     // Alerta apenas (nao fecha nada)
   MODO_PROTEGER       = 1,     // Fecha tudo e mantem conta zerada
   MODO_DESLIGAR_TERMINAL = 2   // Fecha tudo e FECHA O TERMINAL MT5
};

// Motivos (mesmos codigos do BD_TravaDeConta.mqh)
#define MOTIVO_NENHUM        0
#define MOTIVO_PERDA_DIARIA  1
#define MOTIVO_PERDA_SEMANAL 2
#define MOTIVO_DD_MAX        3
#define MOTIVO_META_DIARIA   4
#define MOTIVO_SEQ_PERDAS    5
#define MOTIVO_FORA_JANELA   6
#define MOTIVO_MANUAL        7

//+------------------------------------------------------------------+
//| INPUTS                                                            |
//+------------------------------------------------------------------+
input string sep_seg = "=== SEGURANCA ===";
input bool   InpAllowLiveTrading   = false;   // Permitir conta REAL (paranoico por padrao)
input ENUM_MODO_ENFORCEMENT InpModo = MODO_PROTEGER; // Modo de enforcement
input bool   InpTravaManual        = false;   // Kill switch manual (true = trava tudo agora)

input string sep_dia = "=== TRAVA 1: PERDA DIARIA ===";
input double InpPerdaDiariaPct     = 5.0;     // Perda diaria max em % da ancora (0 = off)
input double InpPerdaDiariaUsd     = 0.0;     // Perda diaria max em $ (0 = off)

input string sep_sem = "=== TRAVA 2: PERDA SEMANAL ===";
input double InpPerdaSemanalPct    = 10.0;    // Perda semanal max em % (0 = off)
input double InpPerdaSemanalUsd    = 0.0;     // Perda semanal max em $ (0 = off)

input string sep_dd = "=== TRAVA 3: DRAWDOWN MAXIMO ===";
input double InpDrawdownMaxPct     = 20.0;    // DD max do topo historico em % (0 = off)

input string sep_meta = "=== TRAVA 4: META DIARIA (opcional) ===";
input double InpMetaDiariaPct      = 0.0;     // Ganho diario que protege o dia em % (0 = off)
input double InpMetaDiariaUsd      = 0.0;     // Ganho diario que protege o dia em $ (0 = off)

input string sep_tilt = "=== TRAVA 5: ANTI-TILT ===";
input int    InpMaxPerdasSeguidas  = 3;       // Perdas seguidas p/ pausar (0 = off)
input int    InpPausaTiltMin       = 60;      // Duracao da pausa anti-tilt (minutos)

input string sep_jan = "=== TRAVA 6: JANELA DE OPERACAO ===";
input bool   InpUsarJanela         = false;   // Ativar janela de operacao
input int    InpJanelaHoraInicio   = 9;       // Hora inicio (hora do broker, 0-23)
input int    InpJanelaHoraFim      = 18;      // Hora fim (hora do broker, 0-23)
input bool   InpFecharForaJanela   = true;    // Fechar posicoes ao sair da janela

input string sep_tec = "=== TECNICOS ===";
input long   InpMagicNumber        = 88900001; // 889 = familia gerenciamento, 00001 = guardiao v1
input int    InpSlippage           = 50;       // Deviation p/ fechamentos (pontos)
input bool   InpVerboseLog         = true;     // Log detalhado
input bool   InpAlertaPopup        = true;     // Alert() popup ao travar

//+------------------------------------------------------------------+
//| GLOBALS                                                           |
//+------------------------------------------------------------------+
long     g_login = 0;              // login da conta (chave de persistencia)
string   g_prefixo = "";           // prefixo das GlobalVariables
string   g_arquivo = "";           // arquivo de estado na pasta Common

// Ancoras (persistidas)
double   g_ancoraDia = 0;          // equity no inicio do dia (server)
int      g_diaAncora = -1;         // dia do ano da ancora diaria
double   g_ancoraSemana = 0;       // equity no inicio da semana
int      g_semanaAncora = -1;      // "ano*100+semana" da ancora semanal
double   g_hwm = 0;                // topo historico de equity (high-water mark)
int      g_seqPerdas = 0;          // perdas seguidas (conta toda)

// Trava (persistida)
bool     g_travada = false;
int      g_motivo = MOTIVO_NENHUM;
datetime g_travaAte = 0;           // 0 = sem expiracao (precisa liberar manual)

// Runtime
int      g_anoAncoraDia = -1;      // ano da ancora diaria (evita bug na virada de ano)
datetime g_ultAlerta = 0;

//+------------------------------------------------------------------+
//| PERSISTENCIA - GlobalVariables + arquivo em Common                |
//+------------------------------------------------------------------+
void GV(string nome, double valor) { GlobalVariableSet(g_prefixo + nome, valor); }
double GVGet(string nome, double padrao)
{
   if(!GlobalVariableCheck(g_prefixo + nome)) return padrao;
   return GlobalVariableGet(g_prefixo + nome);
}

void SalvarEstado()
{
   // 1) GlobalVariables (sobrevivem restart do terminal por ~4 semanas)
   GV("HWM",          g_hwm);
   GV("ANCORA_DIA",   g_ancoraDia);
   GV("DIA_ANCORA",   g_diaAncora);
   GV("ANO_ANCORA",   g_anoAncoraDia);
   GV("ANCORA_SEM",   g_ancoraSemana);
   GV("SEM_ANCORA",   g_semanaAncora);
   GV("SEQ_PERDAS",   g_seqPerdas);
   GV("LOCK",         g_travada ? 1 : 0);
   GV("MOTIVO",       g_motivo);
   GV("ATE",          (double)(long)g_travaAte);

   // 2) Arquivo binario na pasta Common (sobrevive a tudo, inclusive
   //    limpeza de GlobalVariables e reinstalacao do terminal)
   int h = FileOpen(g_arquivo, FILE_COMMON | FILE_BIN | FILE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileWriteDouble(h, g_hwm);
   FileWriteDouble(h, g_ancoraDia);
   FileWriteLong(h, g_diaAncora);
   FileWriteLong(h, g_anoAncoraDia);
   FileWriteDouble(h, g_ancoraSemana);
   FileWriteLong(h, g_semanaAncora);
   FileWriteLong(h, g_seqPerdas);
   FileWriteLong(h, g_travada ? 1 : 0);
   FileWriteLong(h, g_motivo);
   FileWriteLong(h, (long)g_travaAte);
   FileClose(h);
}

void CarregarEstado()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   if(GlobalVariableCheck(g_prefixo + "HWM"))
   {
      // Fonte primaria: GlobalVariables
      g_hwm          = GVGet("HWM", eq);
      g_ancoraDia    = GVGet("ANCORA_DIA", eq);
      g_diaAncora    = (int)GVGet("DIA_ANCORA", -1);
      g_anoAncoraDia = (int)GVGet("ANO_ANCORA", -1);
      g_ancoraSemana = GVGet("ANCORA_SEM", eq);
      g_semanaAncora = (int)GVGet("SEM_ANCORA", -1);
      g_seqPerdas    = (int)GVGet("SEQ_PERDAS", 0);
      g_travada      = (GVGet("LOCK", 0) >= 1.0);
      g_motivo       = (int)GVGet("MOTIVO", MOTIVO_NENHUM);
      g_travaAte     = (datetime)(long)GVGet("ATE", 0);
      if(InpVerboseLog) Print("[ESTADO] restaurado das GlobalVariables");
      return;
   }

   // Fallback: arquivo em Common (GVs limpas ou terminal novo)
   if(FileIsExist(g_arquivo, FILE_COMMON))
   {
      int h = FileOpen(g_arquivo, FILE_COMMON | FILE_BIN | FILE_READ);
      if(h != INVALID_HANDLE)
      {
         g_hwm          = FileReadDouble(h);
         g_ancoraDia    = FileReadDouble(h);
         g_diaAncora    = (int)FileReadLong(h);
         g_anoAncoraDia = (int)FileReadLong(h);
         g_ancoraSemana = FileReadDouble(h);
         g_semanaAncora = (int)FileReadLong(h);
         g_seqPerdas    = (int)FileReadLong(h);
         g_travada      = (FileReadLong(h) == 1);
         g_motivo       = (int)FileReadLong(h);
         g_travaAte     = (datetime)FileReadLong(h);
         FileClose(h);
         Print("[ESTADO] restaurado do arquivo Common (GlobalVariables ausentes)");
         return;
      }
   }

   // Primeira execucao nesta conta
   g_hwm = eq; g_ancoraDia = eq; g_ancoraSemana = eq;
   g_diaAncora = -1; g_anoAncoraDia = -1; g_semanaAncora = -1;
   g_seqPerdas = 0; g_travada = false; g_motivo = MOTIVO_NENHUM; g_travaAte = 0;
   Print("[ESTADO] primeira execucao nesta conta - ancoras criadas");
}

//+------------------------------------------------------------------+
//| TEMPO (sempre hora do SERVIDOR/broker)                            |
//+------------------------------------------------------------------+
datetime ProximaMeiaNoite()
{
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt) + 86400;
}

datetime ProximaSegunda()
{
   MqlDateTime dt; TimeCurrent(dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   int diasAteSegunda = (8 - dt.day_of_week) % 7;       // dom=0 -> 1 dia
   if(diasAteSegunda == 0) diasAteSegunda = 7;          // ja e segunda -> proxima
   return StructToTime(dt) + diasAteSegunda * 86400;
}

int SemanaChave()
{
   // Chave "ano*100 + numero de segundas ja viradas no ano" - so precisa
   // mudar de valor quando vira a semana, nao precisa ser ISO 8601
   MqlDateTime dt; TimeCurrent(dt);
   int diaSemana = (dt.day_of_week == 0) ? 7 : dt.day_of_week;   // seg=1..dom=7
   int semana = (dt.day_of_year - diaSemana + 10) / 7;
   return dt.year * 100 + semana;
}

//+------------------------------------------------------------------+
//| ANCORAS - viradas de dia/semana e high-water mark                 |
//+------------------------------------------------------------------+
void AtualizaAncoras()
{
   MqlDateTime dt; TimeCurrent(dt);
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   bool mudou = false;

   if(dt.day_of_year != g_diaAncora || dt.year != g_anoAncoraDia)
   {
      g_diaAncora = dt.day_of_year;
      g_anoAncoraDia = dt.year;
      g_ancoraDia = eq;
      g_seqPerdas = 0;                                   // tilt zera no novo dia
      mudou = true;
      if(InpVerboseLog)
         PrintFormat("[DIA NOVO] ancora diaria = %.2f (equity)", g_ancoraDia);
   }

   int sem = SemanaChave();
   if(sem != g_semanaAncora)
   {
      g_semanaAncora = sem;
      g_ancoraSemana = eq;
      mudou = true;
      if(InpVerboseLog)
         PrintFormat("[SEMANA NOVA] ancora semanal = %.2f (equity)", g_ancoraSemana);
   }

   if(eq > g_hwm) { g_hwm = eq; mudou = true; }

   if(mudou) SalvarEstado();
}

//+------------------------------------------------------------------+
//| MOTOR DA TRAVA                                                    |
//+------------------------------------------------------------------+
string MotivoTexto(int m)
{
   switch(m)
   {
      case MOTIVO_PERDA_DIARIA:  return "PERDA DIARIA MAXIMA";
      case MOTIVO_PERDA_SEMANAL: return "PERDA SEMANAL MAXIMA";
      case MOTIVO_DD_MAX:        return "DRAWDOWN MAXIMO DA CONTA";
      case MOTIVO_META_DIARIA:   return "META DIARIA ATINGIDA (dia protegido)";
      case MOTIVO_SEQ_PERDAS:    return "SEQUENCIA DE PERDAS (anti-tilt)";
      case MOTIVO_FORA_JANELA:   return "FORA DA JANELA DE OPERACAO";
      case MOTIVO_MANUAL:        return "TRAVA MANUAL (kill switch)";
   }
   return "SEM TRAVA";
}

void AtivarTrava(int motivo, datetime ate, string detalhe)
{
   if(g_travada && g_motivo == motivo) return;           // ja ativa, nao repete
   g_travada = true;
   g_motivo = motivo;
   g_travaAte = ate;
   SalvarEstado();

   string msg = StringFormat("TRAVA ATIVADA: %s | %s | valida ate %s",
                             MotivoTexto(motivo), detalhe,
                             ate == 0 ? "LIBERACAO MANUAL"
                                      : TimeToString(ate, TIME_DATE | TIME_MINUTES));
   Print("=======================================================");
   Print(msg);
   Print("=======================================================");
   if(InpAlertaPopup) Alert(msg);

   if(InpModo != MODO_SOMENTE_ALERTA)
      FecharTudo("trava: " + MotivoTexto(motivo));

   if(InpModo == MODO_DESLIGAR_TERMINAL)
   {
      // Nuclear: derruba o terminal inteiro. Nada mais abre ate o
      // operador religar o MT5 - e ao religar, a trava recarrega
      // do disco e continua valendo.
      Print("[MODO NUCLEAR] fechando o terminal MT5 em 5s...");
      Sleep(5000);
      TerminalClose(0);
   }
}

void LiberarTrava(string origem)
{
   if(!g_travada) return;
   PrintFormat("[TRAVA LIBERADA] motivo anterior: %s | origem: %s",
               MotivoTexto(g_motivo), origem);
   g_travada = false;
   g_motivo = MOTIVO_NENHUM;
   g_travaAte = 0;
   SalvarEstado();
}

// Expiracao automatica (fim do dia, fim da pausa tilt, etc.)
void ChecaExpiracao()
{
   if(!g_travada) return;
   if(g_travaAte > 0 && TimeCurrent() >= g_travaAte)
      LiberarTrava("expiracao automatica");
}

// Comandos manuais via janela F3 do terminal (GlobalVariables):
//   BDGC_<login>_CMD_TRAVAR = 1   -> trava manual imediata
//   BDGC_<login>_CMD_LIBERAR = 1  -> libera trava de DD max / manual
void ChecaComandos()
{
   string cmdTravar = g_prefixo + "CMD_TRAVAR";
   if(GlobalVariableCheck(cmdTravar) && GlobalVariableGet(cmdTravar) >= 1.0)
   {
      GlobalVariableDel(cmdTravar);
      AtivarTrava(MOTIVO_MANUAL, 0, "comando manual via GlobalVariable");
   }
   string cmdLiberar = g_prefixo + "CMD_LIBERAR";
   if(GlobalVariableCheck(cmdLiberar) && GlobalVariableGet(cmdLiberar) >= 1.0)
   {
      GlobalVariableDel(cmdLiberar);
      // So libera se a condicao nao estiver mais vigente - o proximo
      // ciclo de checagem retrava na hora se o limite ainda estiver rompido
      LiberarTrava("comando manual via GlobalVariable");
   }
}

//+------------------------------------------------------------------+
//| CHECAGEM DOS LIMITES (roda a cada tick e a cada 1s)               |
//+------------------------------------------------------------------+
void ChecaLimites()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);

   // Trava manual por input tem prioridade e nao expira sozinha
   if(InpTravaManual)
   {
      AtivarTrava(MOTIVO_MANUAL, 0, "InpTravaManual = true");
      return;
   }
   if(g_travada && g_motivo == MOTIVO_MANUAL && g_travaAte == 0 && !InpTravaManual)
      LiberarTrava("InpTravaManual voltou para false");

   if(g_travada) return;                                 // ja travada, nada a checar

   // --- 1. Perda diaria (equity atual vs ancora do dia) ---
   double perdaDiaUsd = g_ancoraDia - eq;
   double perdaDiaPct = (g_ancoraDia > 0) ? perdaDiaUsd / g_ancoraDia * 100.0 : 0;
   if(InpPerdaDiariaPct > 0 && perdaDiaPct >= InpPerdaDiariaPct)
   {
      AtivarTrava(MOTIVO_PERDA_DIARIA, ProximaMeiaNoite(),
                  StringFormat("-%.2f%% no dia (limite %.2f%%)", perdaDiaPct, InpPerdaDiariaPct));
      return;
   }
   if(InpPerdaDiariaUsd > 0 && perdaDiaUsd >= InpPerdaDiariaUsd)
   {
      AtivarTrava(MOTIVO_PERDA_DIARIA, ProximaMeiaNoite(),
                  StringFormat("-%.2f no dia (limite %.2f)", perdaDiaUsd, InpPerdaDiariaUsd));
      return;
   }

   // --- 2. Perda semanal ---
   double perdaSemUsd = g_ancoraSemana - eq;
   double perdaSemPct = (g_ancoraSemana > 0) ? perdaSemUsd / g_ancoraSemana * 100.0 : 0;
   if(InpPerdaSemanalPct > 0 && perdaSemPct >= InpPerdaSemanalPct)
   {
      AtivarTrava(MOTIVO_PERDA_SEMANAL, ProximaSegunda(),
                  StringFormat("-%.2f%% na semana (limite %.2f%%)", perdaSemPct, InpPerdaSemanalPct));
      return;
   }
   if(InpPerdaSemanalUsd > 0 && perdaSemUsd >= InpPerdaSemanalUsd)
   {
      AtivarTrava(MOTIVO_PERDA_SEMANAL, ProximaSegunda(),
                  StringFormat("-%.2f na semana (limite %.2f)", perdaSemUsd, InpPerdaSemanalUsd));
      return;
   }

   // --- 3. Drawdown maximo do topo historico ---
   double ddPct = (g_hwm > 0) ? (g_hwm - eq) / g_hwm * 100.0 : 0;
   if(InpDrawdownMaxPct > 0 && ddPct >= InpDrawdownMaxPct)
   {
      // Sem expiracao: rever a estrategia antes de liberar (CMD_LIBERAR)
      AtivarTrava(MOTIVO_DD_MAX, 0,
                  StringFormat("DD %.2f%% do topo %.2f (limite %.2f%%)", ddPct, g_hwm, InpDrawdownMaxPct));
      return;
   }

   // --- 4. Meta diaria de ganho (protege o lucro do dia) ---
   double ganhoDiaUsd = eq - g_ancoraDia;
   double ganhoDiaPct = (g_ancoraDia > 0) ? ganhoDiaUsd / g_ancoraDia * 100.0 : 0;
   if(InpMetaDiariaPct > 0 && ganhoDiaPct >= InpMetaDiariaPct)
   {
      AtivarTrava(MOTIVO_META_DIARIA, ProximaMeiaNoite(),
                  StringFormat("+%.2f%% no dia (meta %.2f%%)", ganhoDiaPct, InpMetaDiariaPct));
      return;
   }
   if(InpMetaDiariaUsd > 0 && ganhoDiaUsd >= InpMetaDiariaUsd)
   {
      AtivarTrava(MOTIVO_META_DIARIA, ProximaMeiaNoite(),
                  StringFormat("+%.2f no dia (meta %.2f)", ganhoDiaUsd, InpMetaDiariaUsd));
      return;
   }

   // --- 5. Sequencia de perdas (anti-tilt) ---
   if(InpMaxPerdasSeguidas > 0 && g_seqPerdas >= InpMaxPerdasSeguidas)
   {
      g_seqPerdas = 0;                                   // consome a sequencia
      AtivarTrava(MOTIVO_SEQ_PERDAS, TimeCurrent() + InpPausaTiltMin * 60,
                  StringFormat("%d perdas seguidas (pausa %d min)", InpMaxPerdasSeguidas, InpPausaTiltMin));
      return;
   }

   // --- 6. Janela de operacao ---
   if(InpUsarJanela && InpFecharForaJanela && !DentroDaJanela())
   {
      // Trava curta: expira sozinha ao reentrar na janela (checado abaixo)
      if(ContaPosicoes() > 0 || ContaOrdens() > 0)
         AtivarTrava(MOTIVO_FORA_JANELA, ProximoInicioJanela(),
                     StringFormat("fora da janela %02d:00-%02d:00 (broker)",
                                  InpJanelaHoraInicio, InpJanelaHoraFim));
   }
}

bool DentroDaJanela()
{
   if(!InpUsarJanela) return true;
   MqlDateTime dt; TimeCurrent(dt);
   if(InpJanelaHoraInicio <= InpJanelaHoraFim)
      return (dt.hour >= InpJanelaHoraInicio && dt.hour < InpJanelaHoraFim);
   // Janela cruzando a meia-noite (ex: 22 -> 6)
   return (dt.hour >= InpJanelaHoraInicio || dt.hour < InpJanelaHoraFim);
}

datetime ProximoInicioJanela()
{
   MqlDateTime dt; TimeCurrent(dt);
   dt.min = 0; dt.sec = 0;
   dt.hour = InpJanelaHoraInicio;
   datetime alvo = StructToTime(dt);
   if(alvo <= TimeCurrent()) alvo += 86400;
   return alvo;
}

//+------------------------------------------------------------------+
//| ENFORCEMENT - fecha tudo e mantem fechado                         |
//+------------------------------------------------------------------+
int ContaPosicoes() { return PositionsTotal(); }
int ContaOrdens()   { return OrdersTotal(); }

void FecharTudo(string razao)
{
   // Cancela pendentes primeiro (para nada virar posicao no meio do flatten)
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong tk = OrderGetTicket(i);
      if(tk == 0) continue;
      if(trade.OrderDelete(tk))
         PrintFormat("[ENFORCE] ordem pendente #%I64u cancelada (%s)", tk, razao);
      else
         PrintFormat("[ENFORCE ERR] ordem #%I64u: %d %s", tk,
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
   }

   // Fecha TODAS as posicoes da conta - qualquer simbolo, qualquer magic,
   // inclusive trades manuais. E isso que torna a trava real.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(trade.PositionClose(tk))
         PrintFormat("[ENFORCE] posicao #%I64u fechada (%s)", tk, razao);
      else
         PrintFormat("[ENFORCE ERR] posicao #%I64u: %d %s", tk,
                     trade.ResultRetcode(), trade.ResultRetcodeDescription());
      // Falhas (off quotes, mercado fechado) nao param o loop: o timer
      // de 1s tenta de novo ate a conta ficar zerada
   }
}

void MantemTravado()
{
   if(!g_travada || InpModo == MODO_SOMENTE_ALERTA) return;
   if(ContaPosicoes() > 0 || ContaOrdens() > 0)
   {
      FecharTudo("conta travada: " + MotivoTexto(g_motivo));
      if(InpModo == MODO_DESLIGAR_TERMINAL)
      {
         // Atividade durante a trava em modo nuclear: derruba o terminal
         // de novo. Ao religar, a trava recarrega do disco e continua.
         Print("[MODO NUCLEAR] atividade durante a trava - fechando o terminal em 5s...");
         Sleep(5000);
         TerminalClose(0);
      }
   }
}

//+------------------------------------------------------------------+
//| ANTI-TILT - conta perdas seguidas de TODA a conta                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetInteger(trans.deal, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double resultado = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                    + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                    + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   if(resultado < -0.005)
   {
      g_seqPerdas++;
      if(InpVerboseLog)
         PrintFormat("[TILT] perda %.2f | sequencia = %d de %d",
                     resultado, g_seqPerdas, InpMaxPerdasSeguidas);
   }
   else if(resultado > 0.005)
   {
      if(g_seqPerdas > 0 && InpVerboseLog)
         PrintFormat("[TILT] ganho %.2f | sequencia zerada", resultado);
      g_seqPerdas = 0;
   }
   SalvarEstado();
}

//+------------------------------------------------------------------+
//| PAINEL NO GRAFICO                                                 |
//+------------------------------------------------------------------+
void AtualizaPainel()
{
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double perdaDiaPct = (g_ancoraDia > 0) ? (g_ancoraDia - eq) / g_ancoraDia * 100.0 : 0;
   double perdaSemPct = (g_ancoraSemana > 0) ? (g_ancoraSemana - eq) / g_ancoraSemana * 100.0 : 0;
   double ddPct = (g_hwm > 0) ? (g_hwm - eq) / g_hwm * 100.0 : 0;

   string trava = g_travada
      ? StringFormat(">>> TRAVADA: %s%s <<<", MotivoTexto(g_motivo),
                     g_travaAte == 0 ? " (liberacao manual)"
                                     : " ate " + TimeToString(g_travaAte, TIME_DATE | TIME_MINUTES))
      : "livre";

   string aviso = "";
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      aviso = "\n  !!! AUTOTRADING DESLIGADO - o guardiao NAO consegue fechar posicoes !!!";

   string fmt = "\nBD GERENCIADOR DE CONTA v1.00 - conta %I64d (%s)%s\n";
   fmt += "-------------------------------------------------------\n";
   fmt += "  Equity: %.2f | Topo (HWM): %.2f | DD atual: %.2f%% (max %.2f%%)\n";
   fmt += "  Dia:    ancora %.2f | resultado %+.2f%% (trava em -%.2f%%)\n";
   fmt += "  Semana: ancora %.2f | resultado %+.2f%% (trava em -%.2f%%)\n";
   fmt += "  Perdas seguidas: %d (pausa em %d)\n";
   fmt += "  Modo: %s\n";
   fmt += "  Trava: %s\n";

   Comment(StringFormat(fmt,
      g_login,
      AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL ? "REAL" : "DEMO",
      aviso,
      eq, g_hwm, ddPct, InpDrawdownMaxPct,
      g_ancoraDia, -perdaDiaPct, InpPerdaDiariaPct,
      g_ancoraSemana, -perdaSemPct, InpPerdaSemanalPct,
      g_seqPerdas, InpMaxPerdasSeguidas,
      InpModo == MODO_SOMENTE_ALERTA ? "SOMENTE ALERTA (nao fecha nada!)"
         : InpModo == MODO_PROTEGER ? "PROTEGER (fecha e mantem zerado)"
         : "DESLIGAR TERMINAL (nuclear)",
      trava));
}

//+------------------------------------------------------------------+
//| CICLO PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void Ciclo()
{
   AtualizaAncoras();
   ChecaComandos();
   ChecaExpiracao();
   ChecaLimites();
   MantemTravado();
   GV("LOCK",   g_travada ? 1 : 0);        // republica p/ EAs integrados
   GV("MOTIVO", g_motivo);
   GV("ATE",    (double)(long)g_travaAte);
   GV("HEARTBEAT", (double)(long)TimeCurrent());
   AtualizaPainel();

   // Alerta persistente de AutoTrading desligado (a cada 5 min)
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && TimeCurrent() - g_ultAlerta > 300)
   {
      g_ultAlerta = TimeCurrent();
      string msg = "BD Gerenciador: AUTOTRADING DESLIGADO - travas sem poder de fecho. Ligue o botao Algo Trading.";
      Print(msg);
      if(InpAlertaPopup) Alert(msg);
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_login = AccountInfoInteger(ACCOUNT_LOGIN);
   g_prefixo = StringFormat("BDGC_%I64d_", g_login);
   g_arquivo = StringFormat("BDGC_%I64d.dat", g_login);

   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL && !InpAllowLiveTrading)
   {
      Print("ERRO: conta REAL detectada e InpAllowLiveTrading=false. Abortando.");
      Print("Para usar em conta real, mude InpAllowLiveTrading para true.");
      return INIT_FAILED;
   }
   if(InpPerdaDiariaPct <= 0 && InpPerdaDiariaUsd <= 0 &&
      InpPerdaSemanalPct <= 0 && InpPerdaSemanalUsd <= 0 &&
      InpDrawdownMaxPct <= 0 && InpMaxPerdasSeguidas <= 0 &&
      InpMetaDiariaPct <= 0 && InpMetaDiariaUsd <= 0 &&
      !InpUsarJanela && !InpTravaManual)
   {
      Print("ERRO: todas as travas desativadas. Configure ao menos uma.");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpUsarJanela &&
      (InpJanelaHoraInicio < 0 || InpJanelaHoraInicio > 23 ||
       InpJanelaHoraFim < 0 || InpJanelaHoraFim > 23))
   {
      Print("ERRO: horas da janela devem estar entre 0 e 23.");
      return INIT_PARAMETERS_INCORRECT;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetAsyncMode(false);

   CarregarEstado();
   EventSetTimer(1);          // enforcement mesmo sem tick (mercado parado)

   Print("=======================================================");
   PrintFormat("  BD GERENCIADOR DE CONTA v1.00 | conta %I64d", g_login);
   Print("=======================================================");
   PrintFormat("Modo: %d | Dia: %.1f%%/%.0f | Semana: %.1f%%/%.0f | DD max: %.1f%%",
               (int)InpModo, InpPerdaDiariaPct, InpPerdaDiariaUsd,
               InpPerdaSemanalPct, InpPerdaSemanalUsd, InpDrawdownMaxPct);
   PrintFormat("Meta dia: %.1f%%/%.0f | Anti-tilt: %d perdas -> %d min | Janela: %s",
               InpMetaDiariaPct, InpMetaDiariaUsd,
               InpMaxPerdasSeguidas, InpPausaTiltMin,
               InpUsarJanela ? StringFormat("%02d-%02dh", InpJanelaHoraInicio, InpJanelaHoraFim) : "off");
   if(g_travada)
      PrintFormat("ATENCAO: trava %s RESTAURADA do estado persistido", MotivoTexto(g_motivo));

   Ciclo();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
   SalvarEstado();
   PrintFormat("BD Gerenciador desligado (motivo %d). Estado salvo - a trava persiste.", reason);
}

void OnTick()  { Ciclo(); }     // reage a cada tick (equity muda com o preco)
void OnTimer() { Ciclo(); }     // garante enforcement a cada 1s mesmo sem tick
//+------------------------------------------------------------------+
