# Notification Notch-Safe Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Impedir que notificações sejam desenhadas atrás do notch físico e reduzir o painel usado por notificações que abrem o notch automaticamente.

**Architecture:** O componente compacto terá duas áreas laterais com a mesma largura e uma área central derivada da largura real do notch. Um helper local concentrará a geometria para que o conteúdo e a extensão inferior da janela usem exatamente a mesma largura. O estado que registra se o notch já estava aberto distinguirá aberturas manuais de automáticas, aplicando largura e altura reduzidas somente às automáticas.

**Tech Stack:** Swift 6, SwiftUI, AppKit, Xcode, script local `scripts/install-local.sh`.

---

Por orientação do projeto, esta alteração não adicionará testes automatizados. A validação será feita por compilação e inspeção manual no monitor com notch físico.

### Task 1: Centralizar a geometria compacta

**Files:**
- Modify: `boringNotch/components/Notch/NotificationLiveActivity.swift:1-75`

- [ ] **Step 1: Adicionar o helper de geometria**

Adicionar antes de `NotificationCompactLiveActivity`:

```swift
enum NotificationCompactLayout {
    static let spacing: CGFloat = 8
    static let preferredWingWidth: CGFloat = 205

    static func centerGapWidth(for notchWidth: CGFloat) -> CGFloat {
        max(0, notchWidth - cornerRadiusInsets.closed.top)
    }

    static func wingWidth(for notchWidth: CGFloat) -> CGFloat {
        let availableContentWidth = windowSize.width
            - (2 * cornerRadiusInsets.closed.bottom)
            - centerGapWidth(for: notchWidth)
            - (2 * spacing)
        return min(preferredWingWidth, max(0, availableContentWidth / 2))
    }

    static func silhouetteWidth(for notchWidth: CGFloat) -> CGFloat {
        let contentWidth = (2 * wingWidth(for: notchWidth))
            + centerGapWidth(for: notchWidth)
            + (2 * spacing)
        return min(windowSize.width, contentWidth + (2 * cornerRadiusInsets.closed.bottom))
    }
}
```

- [ ] **Step 2: Dividir o conteúdo em duas áreas simétricas**

Substituir o `HStack` assimétrico por uma composição com:

```swift
HStack(spacing: NotificationCompactLayout.spacing) {
    leadingWing.frame(width: wingWidth, alignment: .leading)

    Rectangle()
        .fill(.black)
        .frame(width: centerGapWidth)

    trailingWing.frame(width: wingWidth, alignment: .trailing)
}
```

A área esquerda deve mostrar ícone, remetente ou título e nome do app. A área direita deve preservar OTP/cópia ou resumo, símbolo de categoria e contador da fila. Todos os textos devem usar `lineLimit(1)` e truncar apenas dentro da própria área.

- [ ] **Step 3: Verificar formatação e diff**

Run:

```bash
git diff --check
git diff -- boringNotch/components/Notch/NotificationLiveActivity.swift
```

Expected: nenhuma mensagem do `git diff --check`; o diff contém somente o helper e a reorganização do layout compacto.

### Task 2: Sincronizar a largura inferior da janela

**Files:**
- Modify: `boringNotch/ContentView.swift:159-170`

- [ ] **Step 1: Usar a largura calculada para notificações**

Substituir o acréscimo variável por tipo de notificação:

```swift
} else if notificationActivityActive {
    chinWidth = NotificationCompactLayout.silhouetteWidth(
        for: vm.closedNotchSize.width
    )
```

Isso mantém a área interativa inferior alinhada com a silhueta compacta para notificações comuns e OTP.

### Task 3: Reduzir o painel aberto automaticamente

**Files:**
- Modify: `boringNotch/ContentView.swift:140-155`
- Modify: `boringNotch/ContentView.swift:470-480`

- [ ] **Step 1: Identificar o painel automático reduzido**

Adicionar ao `ContentView`:

```swift
private let automaticNotificationContentWidth: CGFloat = 400

private var usesAutomaticNotificationPanel: Bool {
    vm.notchState == .open && notificationPresentationWasOpen == false
}
```

O estado `false` significa que a notificação encontrou o notch fechado e foi responsável por abri-lo. `nil` representa uma abertura manual sem apresentação automática ativa, e `true` representa um notch que já estava aberto.

- [ ] **Step 2: Usar altura intrínseca somente no painel automático**

Atualizar a altura aberta:

```swift
private var openLayoutHeight: CGFloat? {
    guard vm.notchState == .open else { return nil }
    return usesCompactPlayer || usesAutomaticNotificationPanel
        ? nil
        : vm.notchSize.height
}
```

- [ ] **Step 3: Limitar a largura do conteúdo automático**

Aplicar ao `NotificationExpandedView`:

```swift
NotificationExpandedView(notification: notification)
    .frame(
        width: usesAutomaticNotificationPanel
            ? automaticNotificationContentWidth
            : nil
    )
```

Os 400 pt de conteúdo, somados aos paddings abertos existentes, produzem uma silhueta visual próxima de 460 pt. Quando o valor for `nil`, o layout manual continuará ocupando os 640 pt atuais.

- [ ] **Step 4: Verificar o diff**

Run:

```bash
git diff --check
git diff -- boringNotch/ContentView.swift
```

Expected: a regra reduzida depende apenas do estado de abertura automática e não altera `openNotchSize` ou `BoringViewModel.open()`.

### Task 4: Instalar e validar no hardware

**Files:**
- No source changes.

- [ ] **Step 1: Instalar exclusivamente pelo processo local**

Run:

```bash
./scripts/install-local.sh
```

Expected: build assinada com a configuração local, aplicativo substituído e iniciado.

- [ ] **Step 2: Disparar uma notificação longa**

Usar o mesmo evento sintético de notificação já utilizado na depuração, mantendo a notificação visível tempo suficiente para inspeção.

Expected: ícone e remetente totalmente à esquerda do notch físico; resumo e ação totalmente à direita; nenhum conteúdo sob a câmera.

- [ ] **Step 3: Conferir permissões e chamadas abertas automaticamente**

Disparar uma permissão e uma chamada com abertura automática.

Expected: painel visual próximo de 460 pt, altura ajustada ao conteúdo e todos os controles legíveis.

- [ ] **Step 4: Conferir abertura manual, monitor sem notch e OTP**

Mover o app para um monitor sem notch e disparar uma notificação comum e uma com código.

Expected: a composição continua centralizada, a cópia do código permanece clicável e a abertura manual mantém o painel completo de 640 × 190 pt.

- [ ] **Step 5: Commit e push**

Run:

```bash
git add boringNotch/components/Notch/NotificationLiveActivity.swift boringNotch/ContentView.swift
git commit -m "fix: keep notifications clear of physical notch"
git push
```

Expected: commit criado em `main` e enviado para `origin/main` sem incluir `.superpowers/`.
