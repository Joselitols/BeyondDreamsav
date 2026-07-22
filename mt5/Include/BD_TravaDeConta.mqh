//+------------------------------------------------------------------+
//|                                            BD_TravaDeConta.mqh   |
//|  Protocolo de trava compartilhada do BD Gerenciador de Conta.    |
//|  Inclua este arquivo em qualquer EA seu para que ele respeite    |
//|  as travas aplicadas pelo BD_GerenciadorDeConta.mq5.             |
//|                                                                  |
//|  Uso minimo dentro do seu EA:                                    |
//|     #include <BD_TravaDeConta.mqh>                               |
//|     ...                                                          |
//|     void OnTick()                                                |
//|     {                                                            |
//|        if(BD_ContaTravada()) return;   // nao abre nada          |
//|        ...                                                       |
//|     }                                                            |
//+------------------------------------------------------------------+
#property strict

// Codigos de motivo publicados pelo gerenciador na GlobalVariable *_MOTIVO
#define BD_TRAVA_NENHUMA        0
#define BD_TRAVA_PERDA_DIARIA   1
#define BD_TRAVA_PERDA_SEMANAL  2
#define BD_TRAVA_DRAWDOWN_MAX   3
#define BD_TRAVA_META_DIARIA    4
#define BD_TRAVA_SEQ_PERDAS     5
#define BD_TRAVA_FORA_JANELA    6
#define BD_TRAVA_MANUAL         7

// Prefixo das GlobalVariables, sempre amarrado ao login da conta para
// que duas contas no mesmo terminal nunca compartilhem trava.
string BD_PrefixoTrava()
{
   return StringFormat("BDGC_%I64d_", AccountInfoInteger(ACCOUNT_LOGIN));
}

// true = existe trava ativa agora (perda diaria, semanal, DD, meta, etc.)
bool BD_ContaTravada()
{
   string gv = BD_PrefixoTrava() + "LOCK";
   if(!GlobalVariableCheck(gv)) return false;          // gerenciador ausente = sem trava
   double v = GlobalVariableGet(gv);
   if(v < 1.0) return false;
   // Trava carrega validade (epoch em *_ATE). Expirada = liberada.
   string gvAte = BD_PrefixoTrava() + "ATE";
   if(GlobalVariableCheck(gvAte))
   {
      datetime ate = (datetime)(long)GlobalVariableGet(gvAte);
      if(ate > 0 && TimeCurrent() >= ate) return false;
   }
   return true;
}

// Motivo da trava ativa (BD_TRAVA_*), ou BD_TRAVA_NENHUMA
int BD_MotivoTrava()
{
   if(!BD_ContaTravada()) return BD_TRAVA_NENHUMA;
   string gv = BD_PrefixoTrava() + "MOTIVO";
   if(!GlobalVariableCheck(gv)) return BD_TRAVA_MANUAL;
   return (int)GlobalVariableGet(gv);
}

// Descricao humana do motivo, para logs do seu EA
string BD_MotivoTravaTexto()
{
   switch(BD_MotivoTrava())
   {
      case BD_TRAVA_NENHUMA:       return "sem trava";
      case BD_TRAVA_PERDA_DIARIA:  return "perda diaria maxima atingida";
      case BD_TRAVA_PERDA_SEMANAL: return "perda semanal maxima atingida";
      case BD_TRAVA_DRAWDOWN_MAX:  return "drawdown maximo da conta atingido";
      case BD_TRAVA_META_DIARIA:   return "meta diaria de ganho atingida (dia protegido)";
      case BD_TRAVA_SEQ_PERDAS:    return "sequencia de perdas (pausa anti-tilt)";
      case BD_TRAVA_FORA_JANELA:   return "fora da janela de operacao";
      case BD_TRAVA_MANUAL:        return "trava manual do operador";
   }
   return "motivo desconhecido";
}

// Quando a trava atual expira (0 = sem trava ou sem validade definida)
datetime BD_TravaExpiraEm()
{
   if(!BD_ContaTravada()) return 0;
   string gv = BD_PrefixoTrava() + "ATE";
   if(!GlobalVariableCheck(gv)) return 0;
   return (datetime)(long)GlobalVariableGet(gv);
}

// true = o gerenciador esta rodando e publicou heartbeat nos ultimos 30s.
// Use se quiser exigir o guardiao ligado antes de operar:
//    if(!BD_GerenciadorAtivo()) return; // sem guardiao, nao opero
bool BD_GerenciadorAtivo()
{
   string gv = BD_PrefixoTrava() + "HEARTBEAT";
   if(!GlobalVariableCheck(gv)) return false;
   datetime ultimo = (datetime)(long)GlobalVariableGet(gv);
   return (TimeCurrent() - ultimo) <= 30;
}
