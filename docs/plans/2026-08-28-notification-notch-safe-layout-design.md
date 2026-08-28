# Notification Notch-Safe Layout Design

## Problema

No monitor com notch físico, o layout compacto atual centraliza o conjunto completo da notificação. Como o conteúdo à direita é mais largo que o conteúdo à esquerda, a área reservada à câmera fica deslocada e parte do texto é desenhada atrás do hardware.

## Decisão

Usar duas áreas laterais simétricas ao redor do notch físico:

- esquerda: ícone do app, remetente ou título e nome do app;
- centro: área vazia com a largura real do notch da tela;
- direita: resumo da notificação, ação principal e indicador de fila quando necessário.

O centro do espaçador deve coincidir com o centro da janela e da tela. As duas áreas laterais terão exatamente a mesma largura, independentemente do tamanho do conteúdo.

## Geometria

A largura compacta será calculada a partir de:

1. largura real do notch da tela selecionada;
2. duas áreas laterais de mesma largura;
3. margens e espaçamentos internos existentes;
4. limite da largura disponível na janela atual.

Nenhum texto, ícone ou ação poderá ocupar a área central. Conteúdo excedente será truncado com reticências dentro de sua própria área lateral.

Em telas sem notch físico, será usada a mesma composição simétrica com o notch virtual existente. Isso mantém um único comportamento e evita layouts divergentes por tipo de monitor.

## Comportamento

- A notificação continua usando a animação nativa de abertura do notch.
- O modo compacto não força a abertura vertical.
- As configurações que determinam quais categorias abrem o notch permanecem inalteradas.
- Ao trocar o app para outro monitor, a geometria é recalculada usando a tela selecionada.
- O layout expandido continua mostrando o conteúdo completo.

## Abertura automática reduzida

Quando uma categoria abrir o notch automaticamente, a notificação usará um painel próprio, menor que o painel completo do app:

- largura visual aproximada de 460 pt;
- altura determinada pelo conteúdo da notificação;
- mesmos cantos, animação e controles do notch atual;
- conteúdo centralizado, sem reservar o espaço vazio do painel completo de 640 pt.

A redução só será aplicada quando a notificação abrir um notch que estava fechado. Se o usuário abrir o notch manualmente, ou se ele já estiver aberto quando a notificação chegar, o painel completo continuará usando 640 × 190 pt.

## Verificação manual

- Disparar notificações curtas e longas no monitor com notch físico.
- Confirmar que ambas as áreas laterais permanecem legíveis e não passam sob a câmera.
- Repetir em monitor sem notch.
- Conferir notificações com ação, OTP e indicador de fila.
- Conferir que permissões e chamadas abertas automaticamente usam o painel reduzido.
- Conferir que a abertura manual continua usando o painel completo.
