<p align="center"><img src="docs/icon.png" width="128" alt="Ícone do Backeddy"></p>

<h1 align="center">Backeddy for Mac</h1>

<p align="center">
  <b>Um painel amigável para forçar, acompanhar e confirmar backups do Time Machine no macOS — e liberar espaço com segurança.</b><br>
  <a href="README.md">English</a> · <a href="README.es.md">Español</a>
</p>

<p align="center"><img src="docs/screenshot.png" width="520" alt="Janela principal do Backeddy"></p>

---

## O que ele faz

- **Fazer backup agora** — inicia um backup do Time Machine e mantém o Mac acordado *só enquanto ele roda* (na tomada ou na bateria). A tela continua podendo apagar, e há um botão **Apagar a tela**.
- **Progresso de verdade** — a mesma porcentagem do menu do Time Machine, mais enviados, analisados, velocidade, tempo restante, Wi-Fi ou cabo, e fases sem porcentagem (como “Limpando backups antigos”) mostradas com clareza.
- **Resultado confirmado** — compara a lista de backups do destino antes e depois: ✅ só quando existe mesmo um backup novo; ❌ com o último backup bom e os erros do Time Machine, se não.
- **Ao terminar o backup** — deixe o Mac dormir normalmente ou ponha para dormir 10 s depois do fim (dá para cancelar).
- **Snapshots locais** — veja quantos existem e apague para recuperar o espaço na hora.
- **Modo turbo** — tira temporariamente o limite de velocidade que o macOS impõe ao Time Machine; volta ao normal sozinho no fim do backup.
- **Limpeza** — mídia do WhatsApp para Mac (por idade) e caches grandes (navegadores, Gradle, Xcode, Homebrew, npm, pip, modelos de IA…).
- **Configurar o Time Machine no Backeddy Server** — acha o servidor na rede, confere a senha e configura tudo (destino, backup automático, primeiro backup) sem abrir os Ajustes do Sistema.
- **Aba Servidor** — situação do Backeddy Server da casa; quando ele bipa por um alerta, avisa no Mac e na barra de menus, e dá para parar o bipe dali (Amanhã, 3 ou 7 dias).
- **Criar o pendrive do Backeddy Server** — baixa a versão mais recente, confere e grava no pendrive, que transforma um PC velho em servidor de backup.
- **Ícone na barra de menus**, **aviso de backup atrasado**, **histórico** e **ajuda** embutida.
- Em **português, inglês e espanhol**.

Toda ação que apaga arquivos mostra um aviso e pede que você digite uma palavra de confirmação.

## Download

Baixe o `.dmg` assinado e notarizado mais recente em **[Releases](https://github.com/backeddy/mac/releases)**, abra e arraste o **Backeddy** para Aplicativos.

Requer **macOS 14 Sonoma ou mais recente**.

Na primeira abertura, ative o **Acesso Total ao Disco** para o Backeddy (Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco), para ele ler a lista de backups e a pasta do WhatsApp.

## Compilar a partir do código

Você precisa do Xcode ou das Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/backeddy/mac.git
cd mac
./build.sh
```

O app é compilado, instalado em `~/Applications/Backeddy.app` e aberto.

## Por que não está na Mac App Store?

Apps da App Store rodam em sandbox, que bloqueia o que o Backeddy precisa: rodar o `tmutil`, Acesso Total ao Disco, ações de administrador (apagar snapshots, modo turbo) e limpar pastas de outros apps. Por isso ele é distribuído aqui, assinado e notarizado pela Apple.

## Segurança

O Backeddy usa só ferramentas da própria Apple (`tmutil`, `pmset`, `sysctl`). Ele nunca vê nem guarda sua senha — o macOS pede diretamente. Apagar snapshots locais, mídia do WhatsApp ou caches não tem volta: mantenha seus backups em dia. Fornecido como está, sem garantias (veja a [LICENSE](LICENSE)).

## Apoie

O Backeddy é gratuito. Se ele te ajudou, uma doação de agradecimento ajuda a manter o projeto ❤️

- 🇧🇷 **PIX:** `pix@xwa.com.br` (ou use **Apoiar o projeto** dentro do app para ver o QR code)
- 🌎 **[GitHub Sponsors](https://github.com/sponsors/lordironballs)**
- ⭐ Dar uma estrela no repositório e indicar o app também ajuda muito!

## Licença

[MIT](LICENSE) © 2026 [Eddy Antonini](https://eddyantonini.com.br)
