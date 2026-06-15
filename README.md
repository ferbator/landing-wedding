# Wedding landing

Статический свадебный лендинг для GitHub Pages. Открывается напрямую через `index.html`, без сборки и платного хостинга.

## Как синхронизировать Google Form

Сайт использует кастомную форму в свадебном дизайне, а ответы отправляет в Google Forms.
Если вы меняете заголовки, вопросы или варианты в Google Forms, обновите HTML командой:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-google-form.ps1
```

Скрипт скачает публичную форму, найдёт `entry.*`, заголовки и варианты ответов, затем пересоберёт RSVP-блок между маркерами `google-form:start` и `google-form:end`.

Чтобы только проверить, какие поля будут найдены, без изменения `index.html`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync-google-form.ps1 -DryRun
```

## GitHub Pages

Загрузите `index.html`, `styles.css`, `script.js` и папку `assets` в репозиторий. В настройках репозитория откройте `Pages` и выберите публикацию из ветки `main`, папка `/root`.
