# Remo

Aplicação móvel desenvolvida em **Flutter** para servir como um **computador de bordo de alta precisão para remadores em ambiente aquático** (single scull, double scull, dois sem, etc.).

O objetivo principal é fornecer métricas em tempo real com máxima fiabilidade e legibilidade sob luz solar direta, sem necessidade de ligação constante à internet (totalmente offline).

---

## 🚀 Principais Funcionalidades

- **Análise de Movimento e Voga (`ImprovedMovementAnalyzer`)**:
  - Processamento de alta frequência de eventos do acelerómetro (`sensors_plus`).
  - Filtragem de ruído aquático, isolamento de gravidade e deteção de remadas com histerese física.
  - Suavização de cadência (SPM - Strokes Per Minute) via EMA (*Exponential Moving Average*) para evitar oscilações erráticas e dupla contagem.

- **Rastreio GPS & Ritmo / Parcial (`GPSController`)**:
  - Utilização de `geolocator` com alta precisão (`LocationAccuracy.bestForNavigation`).
  - Janela deslizante otimizada e suavização em Dupla EMA para reatividade instantânea do parcial por 500m (`parcialPor500m`) durante arrancadas e mudanças de ritmo.

- **Monitor de Frequência Cardíaca (HRM)**:
  - Integração via Bluetooth Low Energy (`flutter_blue_plus`) com bandas cardíacas padrão (Serviço HR `0x180D`).
  - Registo de BPM por trackpoint e suporte de exportação para ficheiros **TCX** (compatível com Strava e Garmin).

- **Interface Otimizada para Água**:
  - Alto contraste e tipografia de escala grande para perfeita visibilidade sob luz solar direta no barco.
  - Prevenção de suspensão de ecrã (`Wakelock`).

---

## 🛠️ Arquitetura & Tecnologias

- **Framework**: Flutter / Dart
- **Gestão de Estado**: Provider (`ChangeNotifier`)
- **Sensores**: `sensors_plus`, `geolocator`, `flutter_blue_plus`
- **Governança**: Arquitetura guiada pela [`CONSTITUTION.md`](./CONSTITUTION.md) e diretrizes técnicas em [`GEMINI.md`](./GEMINI.md).

---

## ⚙️ Instalação e Execução

1. Certifica-te de que tens o [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado.
2. Clona o repositório:
   ```bash
   git clone https://github.com/AndreFonsecaRamos/Tracker.git
   cd Tracker
   ```
3. Instala as dependências:
   ```bash
   flutter pub get
   ```
4. Executa a aplicação num dispositivo físico (recomendado para testes de GPS e acelerómetro) ou em emulador:
   ```bash
   flutter run
   ```

---

## 📄 Licença e Governança

Consulte o ficheiro [`CONSTITUTION.md`](./CONSTITUTION.md) para detalhes sobre as invariantes arquiteturais e regras de desenvolvimento do projeto.
