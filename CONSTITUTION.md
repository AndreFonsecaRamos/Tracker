# CONSTITUIÇÃO DO PROJETO REMO

> **Versão:** 1.0.0  
> **Status:** Ratificada  
> **Linguagem & Ecossistema:** Dart / Flutter  
> **Documento Central de Governança Técnica & Princípios Imutáveis**

---

## Preâmbulo

A presente Constituição estabelece as cláusulas pétreas, a filosofia de engenharia e os padrões de qualidade que regem o desenvolvimento da aplicação **Remo**. Todas as decisões arquiteturais, alterações em algoritmos sensoriais, designs de interface e futuras refatorações devem estar estritamente subordinadas aos artigos aqui declarados.

---

## Artigo I — Missão Central & Experiência do Atleta (Performance em Água)

1. **Foco Primário:** A aplicação existe fundamentalmente como um **computador de bordo de alta precisão para remadores em ambiente aquático** (single scull, dois sem, double scull, quatro, oito e demais embarcações a remos).
2. **Prioridade Absoluta das Métricas:** Durante a sessão de treino, o sistema deve priorizar com latência mínima e máxima confiabilidade:
   - **Voga Instantânea e Média (SPM - Strokes Per Minute)**;
   - **Parcial / Pace por 500 metros** (tempo estimado para 500m);
   - **Distância Total Percorrida (metros)**;
   - **Tempo Decorrido e Tempo em Movimento**.
3. **Ergonomia em Condições Hostis de Água:**
   - **Visibilidade Solar Extrema:** Interfaces de treino devem apresentar altíssimo contraste, fundos escuros/claros limpos e tipografia de escala grande, legíveis a um metro de distância com o telemóvel montado no fincapés ou no canvas do barco.
   - **Prevenção de Suspensão:** O ecrã nunca pode apagar-se durante uma sessão ativa de treino (`Wakelock` ativo e garantido).
   - **Interação Mínima:** A aplicação deve operar autonomamente com o mínimo ou zero toques após o início da sessão, tolerando gotas de água no ecrã.

---

## Artigo II — Princípios de Arquitetura e Engenharia (Evolução Flexível)

1. **Desacoplamento Sensorial:** O processamento numérico de aceleração, filtragem de gravidade e fusão cinemática de GPS devem permanecer isolados da camada de apresentação (widgets Flutter). A lógica de cálculo deve ser independente de contexto de UI.
2. **Evolução Flexível do Estado:** O projeto adota presentemente `Provider` (`ChangeNotifier`). É explicitamente permitida a refatoração ou transição futura para soluções alternativas de gestão de estado (ex.: `Riverpod`, `Bloc`), desde que:
   - Não introduza quedas de frame na renderização (manutenção de 60fps constantes na UI);
   - Assegure reatividade imediata perante eventos de sensores de alta frequência.
3. **Operação 100% Offline:** A captura de dados, cálculo de métricas e registo de treinos na água não dependem de conectividade de rede móvel ou internet. Toda a inteligência de treino é estritamente local.
4. **Conservação de Energia e Recursos:**
   - Subscrições de sensores (`sensors_plus`, `geolocator`) e timers devem ser cancelados e descartados rigorosamente no encerramento das rotas/telas.
   - A CPU não deve ser sobrecarregada com loops síncronos pesados na thread principal da UI.

---

## Artigo III — Invariantes dos Algoritmos e Sensores

### 1. Acelerómetro & Deteção de Voga (`ImprovedMovementAnalyzer`)
- **Imunidade a Ruído Aquático:** O algoritmo deve rejeitar vibrações de alta frequência, ondulação da água, ressonância do casco e movimentos de retorno do carrinho (*recovery*).
- **Histerese Física Obrigatória:** A deteção de uma remada requer uma transição comprovada entre a fase de ataque/propulsão (*driveThreshold*) e a fase de recuperação (*thresholdRecovery*).
- **Limites Biomecânicos:** É vedada a validação de remadas com frequência sobre-humana. O intervalo mínimo entre remadas (`_minStrokeInterval`) deve respeitar um piso biomecânico seguro (mínimo de 1250ms, correspondente a um limite fisiológico máximo de ~48 SPM).
- **Estabilização por Média Aparada (*Trimmed Mean*):** A cadência exibida deve utilizar uma janela de amostras com descarte de valores discrepantes (*outliers* de topo e fundo) para evitar saltos visuais erráticos.

### 2. GPS & Cálculo do Parcial por 500m (`GPSController`)
- **Reatividade em Sprints e Séries Fortes:** A janela deslizante de amostras temporais de GPS deve manter-se curta (máximo de 3 a 4 segundos), garantindo que velocidades nulas ou lentas sejam descartadas instantaneamente assim que o atleta inicia uma série forte ou arranque de partida.
- **Filtragem por Double EMA:** A suavização do parcial deve utilizar Médias Móveis Exponenciais ajustadas de forma a evitar oscilações numéricas sem comprometer a prontidão de resposta da velocidade real.
- **Filtro de Precisão Horizontal:** Pontos de GPS com incerteza excessiva (> 15 metros) devem ser descartados do cálculo de distância acumulada e ritmo.

---

## Artigo IV — Governança de Validação e Testes (Iteração Empírica em Água)

1. **Soberania do Teste em Água:** A prova final e irrefutável de qualquer alteração nos algoritmos de voga e ritmo é o comportamento prático dentro de um barco a remar em água real.
2. **Ciclo Ágil de Desenvolvimento:** Reconhece-se a natureza empírica e iterativa do desenvolvimento de algoritmos de remo. Ajustes de calibração podem ser efetuados com rapidez para validação direta pelo atleta/treinador em água.
3. **Cláusula de Não-Regressão Histórica:** Nenhuma alteração de código pode reintroduzir defeitos já solucionados e registados no projeto, especificamente:
   - *Dupla contagem de voga por oscilação de popa/proa;*
   - *Atraso excessivo (lag) no tempo do parcial em arrancadas ou mudanças de ritmo.*

---

## Artigo V — Padrões de Código e Manutenibilidade

1. **Comentários de Justificação Física:** Todas as constantes de filtros (alphas de suavização, thresholds de aceleração, tamanhos de janela de GPS e limites de intervalo) devem ser acompanhadas de comentários explicando a fundamentação física ou biomecânica do seu valor.
2. **Código Tipado e Limpo:** É proibido contornar a segurança de tipos do Dart com `dynamic` injustificado ou desativar alertas do compilador/linter sem fundamentação técnica documentada.
3. **Resiliência a Falhas:** Falhas transitórias de sensores, perdas de sinal GPS (ex.: debaixo de pontes) ou pausas inesperadas do sistema operacional devem ser tratadas de forma resiliente, preservando os dados já acumulados pelo utilizador sem encerrar a aplicação inesperadamente.

---

## Artigo VI — Emendas Constitucionais

Quaisquer emendas ou adições a esta Constituição exigem:
1. Alinhamento com a premissa de máxima utilidade prática para o remador em água;
2. Justificação técnica clara quanto ao impacto no consumo de bateria, latência e legibilidade;
3. Registo explícito da motivação e da data de revisão no histórico deste documento.
