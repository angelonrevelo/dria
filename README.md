<p align="center">
  <img src="dria/Assets.xcassets/AppIcon.appiconset/icon_256.png" alt="dria app icon" width="128">
</p>

# dria

**An AI study assistant that lives in your menu bar — and answers from your own notes.**

dria sits quietly in the macOS menu bar (or the Windows system tray). Show it a
question — by capturing part of the screen, copying text, or just saying it out
loud — and it answers using the study materials you gave it as context, not
just whatever the model happens to know.

- **Your notes are the context.** Make a study mode per subject and drop in
  PDFs, Word, PowerPoint, Excel, Markdown or images. dria indexes them on your
  machine and pulls the relevant passages into every answer.
- **Three ways to ask.** Screenshot or area capture, copy-to-ask (it recognises
  multiple choice, true/false, identification and essay prompts), and live voice
  transcription of your mic or desktop audio — useful for lectures and videos.
- **Short answer first, detail on demand.** A small answer card shows the gist
  and the source note it came from; the chat window has the full explanation
  and follow-ups.
- **Study tools.** Practice questions and flip-cards generated from your own
  materials, plus chat export.
- **Any model.** Google AI (free tier), Vertex AI, Claude, OpenAI, Groq,
  Mistral, OpenRouter, or a fully local Ollama.

The macOS app is native Swift; the Windows build is a Tauri app in `desktop/`.
There is also an Excel add-in that lets a spreadsheet call dria from a cell.

## Download

| Platform | Get it | First launch |
|---|---|---|
| macOS 14+ | [latest `.dmg`](https://github.com/angelonrevelo/dria/releases/latest) | Drag to Applications, then right-click → Open |
| Windows | [`.exe` / `.msi`](https://github.com/angelonrevelo/dria/releases/tag/desktop-v1.0.0) | Run the installer |

Then open **Settings → AI Model** and paste an API key (Google AI Studio's free
key is the quickest start; Ollama needs none).

## Build from source

**macOS** — Xcode 16+:

```bash
git clone https://github.com/angelonrevelo/dria.git && cd dria
xcodebuild -project dria.xcodeproj -scheme dria -configuration Release build
```

**Windows / cross-platform** — Node.js 18+, Rust 1.77+ and the
[Tauri prerequisites](https://v2.tauri.app/start/prerequisites/):

```bash
cd dria/desktop
npm install
npx tauri dev        # development
npx tauri build      # .exe / .msi
```

## Configuration

There is no `.env`. Provider, model, API key, hotkeys, study modes and the
answer-card look are all set in the app's **Settings** and stay on your
machine. Default hotkeys: `⌘⌥1` / `Ctrl+Alt+1` capture, `⌘⌥2` / `Ctrl+Alt+2`
send, `⌘⌥3` / `Ctrl+Alt+3` toggle chat — all remappable.

## How it works

```
 capture / copy / voice ──► question
                               │
          study mode files ──► on-device index (sentence embeddings, keyword fallback)
                               │  top passages
                               ▼
                         chosen AI provider ──► short answer card + full answer in chat
```

Retrieval runs locally — on macOS it uses Apple's on-device sentence embeddings,
so no extra key or network call is needed to search your notes. Only the
question plus the selected passages go to the model you picked.

Logs and crash reports land in `~/Library/Logs/dria/` and are browsable from
**Settings → General → Recent Issues**.

## More

- [docs/internals.md](docs/internals.md) — full feature list, hotkeys, provider setup, usage walkthroughs, source tree, and the logs & diagnostics reference
- [excel-addin/README.md](excel-addin/README.md) — the Excel add-in
- [ROADMAP.md](ROADMAP.md) — what is next

## License

MIT — see [LICENSE](LICENSE).
