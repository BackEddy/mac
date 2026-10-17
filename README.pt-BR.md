<p align="center"><img src="docs/icon.png" width="128" alt="Ícone do Backeddy"></p>

<h1 align="center">Backeddy for Mac</h1>

<p align="center">
  <b>Backups do Time Machine sem dor de cabeça — e um servidor de backup para a casa toda, sem precisar entender de servidor.</b><br>
  <a href="README.md">English</a> · <a href="README.es.md">Español</a>
</p>

<p align="center"><img src="docs/screenshot.png" width="520" alt="Janela principal do Backeddy"></p>

<p align="center"><a href="https://github.com/BackEddy/mac/releases/latest"><b>⬇️ Baixar o Backeddy for Mac</b></a> · macOS 14 Sonoma ou mais recente · grátis</p>

---

## Em poucas palavras

O Mac já vem com um ótimo sistema de backup, o **Time Machine**. O problema é que ele trabalha escondido: você nunca sabe direito se o backup está rodando, se terminou ou se falhou. O **Backeddy** mostra tudo isso de um jeito claro, avisa quando algo dá errado e ainda te ajuda a montar um **servidor de backup** em casa — para todos os Macs (e PCs) fazerem backup sozinhos, sem HD pendurado no cabo.

## Primeiro, alguns nomes

- **Backup** — uma cópia dos seus arquivos guardada em outro lugar. Se o Mac quebrar, for roubado ou você apagar algo sem querer, os arquivos voltam do backup.
- **Time Machine** — o backup que vem no Mac (Ajustes do Sistema › Geral › Time Machine). Ele copia o Mac inteiro e depois, a cada hora, só o que mudou. Dá para “voltar no tempo” e recuperar um arquivo como ele estava ontem ou mês passado.
- **Destino de backup** — onde o Time Machine guarda as cópias: um HD externo ligado no Mac ou um servidor na rede de casa.
- **Servidor de backup** — um computador que fica ligado em casa e recebe os backups pela rede (Wi-Fi ou cabo). Você não precisa lembrar de ligar HD nenhum: o Mac faz backup sozinho sempre que está em casa.
- **Backeddy Server** — o nosso servidor de backup, gratuito. Transforma um PC velho (ou um PC com Windows que já fica ligado) num destino de Time Machine para os Macs e num destino de backup para os PCs.
- **Máquina virtual** — um “computador dentro do computador”. Um programa do Windows finge ser um PC inteiro, com disco e tudo, e o Backeddy Server roda ali dentro, sem mexer no Windows nem nos seus arquivos.
- **Pendrive de instalação** — um pendrive preparado para ligar o PC direto nele e instalar o Backeddy Server. O próprio Backeddy for Mac grava esse pendrive.

## Qual é o seu caso?

| Você tem… | O que fazer |
| --- | --- |
| Um HD externo | Ligue no Mac e escolha ele no Time Machine. O Backeddy acompanha e confirma cada backup. |
| Um PC ou notebook parado | Monte um **Backeddy Server** com um pendrive (jeito 1, abaixo). É o melhor caminho. |
| Um PC com Windows que fica ligado o tempo todo | Monte o **Backeddy Server numa máquina virtual** (jeito 2, abaixo). O Windows continua como está. |

## Montar um Backeddy Server

No Backeddy for Mac: **Arquivo › Montar o Backeddy Server…** (ou o ícone de servidor no topo da janela). Ele pergunta onde o servidor vai rodar.

### Jeito 1 — num computador só para os backups

O PC é apagado e vira o servidor. Funciona em PCs e notebooks de uns 2012 para cá (64 bits).

1. No Backeddy for Mac, escolha **Num computador só para os backups**, coloque um pendrive de 4 GB ou mais e clique em **Continuar**. O app baixa a versão mais recente, confere e grava (tudo no pendrive é apagado).
2. Coloque o pendrive no PC, ligue e escolha o pendrive no menu de partida — geralmente **F12**, F11, F8 ou Esc logo que o PC liga.
3. Siga a tela: escolha como usar os discos, o nome e a senha do servidor. Leva uns 5 minutos. No fim, tire o pendrive e o PC reinicia já como servidor.

Dicas: **cabo de rede** é bem mais rápido que Wi-Fi (sem cabo, o instalador oferece o Wi-Fi). Com **dois HDs**, o servidor guarda cada arquivo nos dois: se um morrer, nada se perde. Um **notebook** velho é ótimo: gasta pouca energia e a bateria funciona como nobreak.

### Jeito 2 — numa máquina virtual, num PC com Windows

O Windows e os arquivos continuam intactos; o servidor roda numa máquina virtual. O PC precisa ficar ligado.

1. No PC com Windows, baixe **[Instalar-Backeddy.exe](https://github.com/BackEddy/server/releases/latest/download/Instalar-Backeddy.exe)** e abra. Se o Windows avisar “O Windows protegeu o computador”, clique em **Mais informações › Executar assim mesmo**.
2. Escolha o disco e o tamanho dos backups. O instalador prepara tudo sozinho (Hyper-V, ou VirtualBox no Windows Home).
3. A instalação abre numa janela, igual à do pendrive. No fim, clique em **Ejetar pendrive** e pronto.

### Quanto espaço?

Conte **o dobro do que os Macs e PCs ocupam**: uma cópia completa e espaço para o histórico. Dois Macs com 250 GB usados cada → 1 TB. O Backeddy for Mac mostra quanto o seu Mac ocupa quando você monta o servidor.

### Depois de montar

No Mac, abra a aba **Destino de backup › Configurar com o Backeddy Server…**: o app acha o servidor na rede, pede a senha e configura o Time Machine para você — sem abrir os Ajustes do Sistema. A aba **Servidor** mostra se está tudo bem; se o servidor tiver um problema (um disco falhando, por exemplo), ele **bipa** até alguém ver, e você para o bipe pelo próprio Mac.

## O que o app faz

- **Fazer backup agora** — inicia um backup e mantém o Mac acordado *só enquanto ele roda*. A tela pode apagar (há um botão **Apagar a tela**).
- **Progresso de verdade** — porcentagem, enviados, velocidade, tempo restante, Wi-Fi ou cabo, e fases sem porcentagem (como “Limpando backups antigos”) explicadas.
- **Resultado confirmado** — ✅ só quando existe mesmo um backup novo no destino; ❌ com o último backup bom e o erro, se não.
- **Ao terminar** — deixe o Mac dormir normalmente ou ponha para dormir logo depois do backup.
- **Snapshots locais** — cópias que o Time Machine guarda no próprio Mac e que seguram espaço; veja quantas existem e apague para liberar na hora.
- **Modo turbo** — tira o limite de velocidade que o macOS impõe ao backup; volta ao normal sozinho.
- **Limpeza** — mídia antiga do WhatsApp e caches grandes (navegadores, Xcode, Homebrew, npm, modelos de IA…).
- **Montar o Backeddy Server**, **configurar o Time Machine** nele e acompanhar tudo na aba **Servidor** (veja acima).
- **Ícone na barra de menus**, **aviso de backup atrasado**, **histórico** e **ajuda**, em **português, inglês e espanhol**.

Toda ação que apaga alguma coisa mostra um aviso e pede que você digite uma palavra de confirmação.

## Instalar

1. Baixe o `.dmg` mais recente em **[Releases](https://github.com/BackEddy/mac/releases/latest)** (assinado e notarizado pela Apple).
2. Abra e arraste o **Backeddy** para Aplicativos.
3. Na primeira abertura, ative o **Acesso Total ao Disco** para o Backeddy (Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco). Sem isso, o macOS não deixa ler a lista de backups.

## Perguntas rápidas

- **Meus arquivos vão para a internet?** Não. Tudo fica na sua casa: no HD ou no seu servidor. O app só acessa a internet para ver se há versão nova e para baixar o Backeddy Server.
- **Preciso entender de Linux ou de servidor?** Não. O Backeddy Server é instalado por telas, com mouse, e depois se cuida sozinho (inclusive atualizações de segurança).
- **E se o disco do servidor quebrar?** Com dois discos, nada se perde. Com um só, os arquivos continuam nos Macs e o servidor recomeça os backups. Em qualquer caso, o servidor avisa (bipa e aparece no app).
- **Funciona com o Windows?** O Backeddy Server já recebe backups de PCs; o app **Backeddy for Windows** está chegando.

## Compilar a partir do código

Você precisa do Xcode ou das Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/BackEddy/mac.git
cd mac
./build.sh
```

## Por que não está na Mac App Store?

Apps da App Store rodam em sandbox, que bloqueia o que o Backeddy precisa: rodar o `tmutil`, Acesso Total ao Disco, ações de administrador e gravar pendrives. Por isso ele é distribuído aqui, assinado e notarizado pela Apple.

## Segurança

O Backeddy usa ferramentas da própria Apple (`tmutil`, `pmset`, `diskutil`, `authopen`). A senha de administrador é pedida pelo macOS; a senha do seu servidor fica nas Chaves do macOS. Apagar snapshots, mídia ou caches não tem volta: mantenha seus backups em dia. Fornecido como está, sem garantias (veja a [LICENSE](LICENSE)).

## Apoie

O Backeddy é gratuito e de código aberto. Se ele salvou seus arquivos, uma doação de agradecimento ajuda a manter o projeto ❤️

- 🇧🇷 **PIX:** `pix@xwa.com.br` (ou **Apoiar o projeto**, dentro do app, para ver o QR code)
- 🌎 **[GitHub Sponsors](https://github.com/sponsors/lordironballs)**
- ⭐ Uma estrela no repositório e indicar o app também ajudam muito!

## Licença

[MIT](LICENSE) © 2026 [Eddy Antonini](https://eddyantonini.com.br) · Faz parte da família [Backeddy](https://github.com/BackEddy) — o [Backeddy Server](https://github.com/BackEddy/server) também é aberto.
