# Notification Notch-Safe Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Impedir que notificações compactas sejam desenhadas atrás do notch físico, mantendo o conteúdo dentro da silhueta e a animação atual.

**Architecture:** O componente compacto terá duas áreas laterais com a mesma largura e uma área central derivada da largura real do notch. Um helper local concentrará a geometria para que o conteúdo e a extensão inferior da janela usem exatamente a mesma largura.

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

- [ ] **Step 2: Compilar o projeto**

Run:

```bash
xcodebuild -quiet -project boringNotch.xcodeproj -scheme boringNotch -destination 'platform=macOS' build
```

Expected: exit code 0.

### Task 3: Instalar e validar no hardware

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

- [ ] **Step 3: Conferir monitor sem notch e OTP**

Mover o app para um monitor sem notch e disparar uma notificação comum e uma com código.

Expected: a composição continua centralizada, a cópia do código permanece clicável e não há regressão na abertura do notch.

- [ ] **Step 4: Commit e push**

Run:

```bash
git add boringNotch/components/Notch/NotificationLiveActivity.swift boringNotch/ContentView.swift
git commit -m "fix: keep notifications clear of physical notch"
git push
```

Expected: commit criado em `main` e enviado para `origin/main` sem incluir `.superpowers/`.

