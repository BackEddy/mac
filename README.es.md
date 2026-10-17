<p align="center"><img src="docs/icon.png" width="128" alt="Icono de Backeddy"></p>

<h1 align="center">Backeddy for Mac</h1>

<p align="center">
  <b>Backups de Time Machine sin complicaciones — y un servidor de backup para toda la casa, sin saber de servidores.</b><br>
  <a href="README.md">English</a> · <a href="README.pt-BR.md">Português</a>
</p>

<p align="center"><img src="docs/screenshot.png" width="520" alt="Ventana principal de Backeddy"></p>

<p align="center"><a href="https://github.com/BackEddy/mac/releases/latest"><b>⬇️ Descargar Backeddy for Mac</b></a> · macOS 14 Sonoma o posterior · gratis</p>

---

## En pocas palabras

El Mac ya trae un gran sistema de backup, **Time Machine**. El problema es que trabaja a escondidas: nunca sabes bien si el backup está en marcha, si terminó o si falló. **Backeddy** te lo muestra todo con claridad, te avisa cuando algo sale mal y te ayuda a montar un **servidor de backup** en casa — para que todos los Mac de casa (y pronto los PC) hagan backup solos, sin un disco colgando del cable.

## Antes de empezar: los riesgos

Backeddy es nuevo y lo hizo una persona, con mucha ayuda de inteligencia artificial. Funciona en nuestras pruebas, pero todavía es una **versión de prueba**. Sin drama, con honestidad, esto es lo que tienes que saber:

- 🧹 **El PC que se convierte en servidor se borra por completo.** Usa un ordenador sin nada importante. El instalador avisa dos veces y te pide escribir BORRAR, pero revisa con calma qué PC y qué discos.
- 📦 **No dejes que Backeddy sea la única copia de tus cosas, por ahora.** Las fotos que no pueden perderse merecen otra copia (un disco guardado en un cajón, un servicio en la nube).
- 💽 **Un solo disco no protege contra un disco roto.** Con dos discos, cada archivo queda en los dos. Con uno, si muere, el historial de backups se va con él — los archivos de tu Mac siguen ahí, y el servidor vuelve a empezar.
- 🪟 **Windows se quejará del instalador** (“Windows protegió su PC”) porque todavía no tiene firma digital. Es lo esperado: haz clic en **Más información › Ejecutar de todas formas**.
- 🍎 **Por ahora, el servidor hace backup de Mac.** Ya está listo para recibir PC, pero la app **Backeddy for Windows** todavía está en camino.
- 🐢 **El primer backup tarda**: horas si el Mac tiene mucho, y más por Wi-Fi. Después, solo se copia lo que cambió.
- 🤝 **Sin garantía.** Es gratuito y de código abierto, se ofrece tal cual. Si algo sale mal, [cuéntanoslo](https://github.com/BackEddy/server/issues): así es como mejora.

## Primero, algunos nombres

- **Backup** — una copia de tus archivos guardada en otro lugar. Si el Mac se rompe, te lo roban o borras algo sin querer, los archivos vuelven del backup.
- **Time Machine** — el backup que viene en el Mac (Ajustes del Sistema › General › Time Machine). Copia el Mac entero y después, cada hora, solo lo que cambió. Puedes “volver en el tiempo” y recuperar un archivo tal como estaba ayer o el mes pasado.
- **Destino de backup** — donde Time Machine guarda las copias: un disco externo conectado al Mac o un servidor en la red de casa.
- **Servidor de backup** — un ordenador que queda encendido en casa y recibe los backups por la red (Wi-Fi o cable). No tienes que acordarte de conectar ningún disco: el Mac hace backup solo siempre que está en casa.
- **Backeddy Server** — nuestro servidor de backup, gratuito. Convierte un PC viejo (o un PC con Windows que ya queda encendido) en un destino de Time Machine para los Mac y un destino de backup para los PC.
- **Máquina virtual** — un “ordenador dentro del ordenador”. Un programa de Windows hace de PC completo, con disco y todo, y Backeddy Server funciona ahí dentro, sin tocar Windows ni tus archivos.
- **Pendrive de instalación** — un pendrive preparado para arrancar el PC desde él e instalar Backeddy Server. El propio Backeddy for Mac lo graba.

## ¿Cuál es tu caso?

| Tienes… | Qué hacer |
| --- | --- |
| Un disco externo | Conéctalo al Mac y elígelo en Time Machine. Backeddy sigue y confirma cada backup. |
| Un PC o portátil parado | Monta un **Backeddy Server** con un pendrive (forma 1, abajo). Es el mejor camino. |
| Un PC con Windows encendido todo el tiempo | Monta **Backeddy Server en una máquina virtual** (forma 2, abajo). Windows queda como está. |

## Montar un Backeddy Server

En Backeddy for Mac: **Archivo › Montar el Backeddy Server…** (o el icono de servidor arriba en la ventana). Te pregunta dónde va a funcionar el servidor.

### Forma 1 — en un ordenador solo para los backups

El PC se borra y se convierte en el servidor. Funciona en PC y portátiles de 2012 en adelante, más o menos (64 bits).

1. En Backeddy for Mac, elige **En un ordenador solo para los backups**, conecta un pendrive de 4 GB o más y haz clic en **Continuar**. La app descarga la versión más reciente, la comprueba y la graba (todo lo que hay en el pendrive se borra).
2. Conecta el pendrive al PC, enciéndelo y elige el pendrive en el menú de arranque — normalmente **F12**, F11, F8 o Esc justo al encender.
3. Sigue la pantalla: elige cómo usar los discos, el nombre y la contraseña del servidor. Tarda unos 5 minutos. Al final, saca el pendrive y el PC se reinicia ya como servidor.

Consejos: el **cable de red** es mucho más rápido que el Wi-Fi (sin cable, el instalador ofrece el Wi-Fi). Con **dos discos**, el servidor guarda cada archivo en los dos: si uno muere, no se pierde nada. Un **portátil** viejo es ideal: gasta poca energía y la batería funciona como SAI.

### Forma 2 — en una máquina virtual, en un PC con Windows

Windows y sus archivos quedan intactos; el servidor funciona en una máquina virtual. El PC tiene que quedar encendido.

1. En el PC con Windows, descarga **[Instalar-Backeddy.exe](https://github.com/BackEddy/server/releases/latest/download/Instalar-Backeddy.exe)** y ábrelo. Windows avisará “Windows protegió su PC”: haz clic en **Más información › Ejecutar de todas formas**. *(¿Por qué? El instalador todavía no tiene firma digital — estamos en ello. Es de código abierto y GitHub lo genera automáticamente a partir de ese código.)*
2. Elige el disco y el tamaño de los backups. El instalador lo prepara todo solo (Hyper-V, o VirtualBox en Windows Home).
3. La instalación se abre en una ventana, igual que la del pendrive. Al final, haz clic en **Expulsar pendrive** y listo.

### ¿Cuánto espacio?

Calcula **el doble de lo que ocupan los Mac y PC**: una copia completa y espacio para el historial. Dos Mac con 250 GB usados cada uno → 1 TB. Backeddy for Mac te muestra cuánto ocupa tu Mac cuando montas el servidor.

### Después de montarlo

En el Mac, abre **Destino de backup › Configurar con Backeddy Server…**: la app encuentra el servidor en la red, pide la contraseña y configura Time Machine por ti — sin abrir los Ajustes del Sistema. La pestaña **Servidor** muestra si todo va bien; si el servidor tiene un problema (un disco fallando, por ejemplo), **pita** hasta que alguien lo vea, y puedes detener el pitido desde el propio Mac.

## Qué hace la app

- **Hacer backup ahora** — inicia un backup y mantiene el Mac despierto *solo mientras dura*. La pantalla puede apagarse (hay un botón **Apagar la pantalla**).
- **Progreso de verdad** — porcentaje, enviados, velocidad, tiempo restante, Wi-Fi o cable, y fases sin porcentaje (como “Limpiando backups antiguos”) explicadas.
- **Resultado confirmado** — ✅ solo cuando existe de verdad un backup nuevo en el destino; ❌ con el último backup bueno y el error, si no.
- **Al terminar** — deja que el Mac duerma como siempre o ponlo a dormir justo después del backup.
- **Instantáneas locales** — copias que Time Machine guarda en el propio Mac y que retienen espacio; mira cuántas hay y bórralas para liberar espacio al momento.
- **Modo turbo** — quita el límite de velocidad que macOS impone al backup; vuelve a la normalidad solo.
- **Limpieza** — multimedia antigua de WhatsApp y cachés grandes (navegadores, Xcode, Homebrew, npm, modelos de IA…).
- **Montar el Backeddy Server**, **configurar Time Machine** en él y seguirlo todo en la pestaña **Servidor** (ver arriba).
- **Icono en la barra de menús**, **aviso de backup atrasado**, **historial** y **ayuda**, en **español, portugués e inglés**.

Backeddy Server (instalación, pantalla del servidor, alertas y panel) habla **español, portugués e inglés**: el idioma se elige en la primera pantalla de la instalación.

Toda acción que borra algo muestra un aviso y te pide que escribas una palabra de confirmación.

## Instalar

1. Descarga el `.dmg` más reciente en **[Releases](https://github.com/BackEddy/mac/releases/latest)** (firmado y notarizado por Apple).
2. Ábrelo y arrastra **Backeddy** a Aplicaciones.
3. Al abrirlo por primera vez, activa el **Acceso total al disco** para Backeddy (Ajustes del Sistema › Privacidad y seguridad › Acceso total al disco). Sin eso, macOS no deja leer la lista de backups.

## Preguntas rápidas

- **¿Mis archivos van a internet?** No. Todo queda en tu casa: en el disco o en tu servidor. La app solo usa internet para buscar versiones nuevas y descargar Backeddy Server.
- **¿Tengo que saber de Linux o de servidores?** No. Backeddy Server se instala con pantallas sencillas, con ratón, y después se cuida solo (actualizaciones de seguridad incluidas).
- **¿Y si se rompe un disco del servidor?** Con dos discos, no se pierde nada. Con uno, los archivos siguen en los Mac y el servidor vuelve a empezar los backups. En cualquier caso, el servidor avisa (pita y aparece en la app).
- **¿Funciona con Windows?** El servidor ya está listo para recibir backups de PC, pero la app **Backeddy for Windows**, que los hace, todavía está en camino. Por ahora, el servidor guarda los backups de los Mac.

## Compilar desde el código

Necesitas Xcode o las Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/BackEddy/mac.git
cd mac
./build.sh
```

## ¿Por qué no está en la Mac App Store?

Las apps de la App Store funcionan en un sandbox, que bloquea lo que Backeddy necesita: ejecutar `tmutil`, Acceso total al disco, acciones de administrador y grabar pendrives. Por eso se distribuye aquí, firmada y notarizada por Apple.

## Seguridad

Backeddy usa herramientas de la propia Apple (`tmutil`, `pmset`, `diskutil`, `authopen`). La contraseña de administrador la pide macOS; la contraseña de tu servidor queda en el Llavero de macOS. Borrar instantáneas, multimedia o cachés no tiene vuelta atrás: mantén tus backups al día. Se ofrece tal cual, sin garantías (ver [LICENSE](LICENSE)).

## Apoya

Backeddy es gratuito y de código abierto. Si salvó tus archivos, una donación de agradecimiento ayuda a mantener el proyecto ❤️

- 🇧🇷 **PIX:** `pix@xwa.com.br` (o **Apoyar el proyecto**, dentro de la app, para ver el código QR)
- 🌎 **[GitHub Sponsors](https://github.com/sponsors/lordironballs)**
- ⭐ ¡Una estrella en el repositorio y recomendar la app también ayudan mucho!

## Licencia

[MIT](LICENSE) © 2026 [Eddy Antonini](https://eddyantonini.com.br) · Parte de la familia [Backeddy](https://github.com/BackEddy) — [Backeddy Server](https://github.com/BackEddy/server) también es de código abierto.
