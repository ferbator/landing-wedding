param(
  [string]$FormUrl = "https://docs.google.com/forms/d/e/1FAIpQLScxKr9EeNtMa5mvRB8cxsfhf820f4ZICyqej3zJQuICkIUlug/viewform?usp=publish-editor",
  [string]$IndexPath = ".\index.html",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Decode-Text([string]$Value) {
  $decoded = [System.Net.WebUtility]::HtmlDecode($Value)
  return [System.Text.RegularExpressions.Regex]::Unescape($decoded)
}

function Escape-Html([string]$Value) {
  return [System.Net.WebUtility]::HtmlEncode($Value)
}

$html = (Invoke-WebRequest -Uri $FormUrl -UseBasicParsing).Content

$formActionMatch = [regex]::Match($html, '<form action="([^"]+/formResponse)"')
if (-not $formActionMatch.Success) {
  throw "Не удалось найти formResponse URL в Google Forms."
}

$fbzxMatch = [regex]::Match($html, 'name="fbzx" value="([^"]+)"')
if (-not $fbzxMatch.Success) {
  throw "Не удалось найти fbzx в Google Forms."
}

$titleMatch = [regex]::Match($html, '<meta itemprop="name" content="([^"]+)"')
$formTitle = if ($titleMatch.Success) { Decode-Text $titleMatch.Groups[1].Value } else { "Свадебный опрос" }

$dataMatch = [regex]::Match($html, 'var FB_PUBLIC_LOAD_DATA_ = (?<data>.*?);</script>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
if (-not $dataMatch.Success) {
  throw "Не удалось найти FB_PUBLIC_LOAD_DATA_ в Google Forms."
}

$data = $dataMatch.Groups["data"].Value
$questionPattern = '\[(?<questionId>\d+),"(?<title>(?:\\.|[^"\\])*)",null,(?<type>\d+),\[\[(?<entry>\d+),(?<payload>.*?)\]\]'
$questionMatches = [regex]::Matches($data, $questionPattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

if ($questionMatches.Count -eq 0) {
  throw "Не удалось найти вопросы в Google Forms."
}

$questionHtml = New-Object System.Collections.Generic.List[string]
$syncedQuestions = New-Object System.Collections.Generic.List[string]

foreach ($match in $questionMatches) {
  $questionTitle = Escape-Html (Decode-Text $match.Groups["title"].Value)
  $plainQuestionTitle = Decode-Text $match.Groups["title"].Value
  $entryNumber = $match.Groups["entry"].Value
  $entryName = "entry.$entryNumber"
  $entryId = $entryName.Replace(".", "-")
  $questionType = [int]$match.Groups["type"].Value
  $payload = $match.Groups["payload"].Value
  $questionSliceLength = [Math]::Min(3000, $data.Length - $match.Index)
  $questionSlice = $data.Substring($match.Index, $questionSliceLength)
  $isRequired = $false

  if ($plainQuestionTitle -eq $formTitle) {
    continue
  }

  if ($questionType -eq 0) {
    $isRequired = [regex]::IsMatch($payload, '^\s*null\s*,\s*1\b')
    $fieldClass = if ($isRequired) { "form-card field field--required" } else { "form-card field" }
    $requiredAttr = if ($isRequired) { ' required aria-required="true"' } else { "" }
    $autocomplete = if ($plainQuestionTitle -match '(?i)имя|фамилия|фио|name') { "name" } else { "off" }
    $questionHtml.Add(@"
          <label class="$fieldClass">
            <span>$questionTitle</span>
            <input name="$entryName" type="text" autocomplete="$autocomplete" placeholder="Мой ответ…" aria-describedby="$entryId-error"$requiredAttr>
            <small id="$entryId-error" class="field-error" data-field-error></small>
          </label>
"@)
    $requiredLabel = if ($isRequired) { ", required" } else { "" }
    $syncedQuestions.Add("$plainQuestionTitle ($entryName, text$requiredLabel)")
    continue
  }

  if ($questionType -eq 2) {
    $requiredMatch = [regex]::Match($questionSlice, "\[\[$entryNumber,.*?\]\],(?<required>[01])", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $isRequired = $requiredMatch.Success -and $requiredMatch.Groups["required"].Value -eq "1"
    $fieldClass = if ($isRequired) { "form-card field choice-group field--required" } else { "form-card field choice-group" }
    $requiredAttr = if ($isRequired) { ' required aria-required="true"' } else { "" }
    $choiceMatches = [regex]::Matches($payload, '\["(?<choice>(?:\\.|[^"\\])*)",null,null,null,\d\]')
    $choices = New-Object System.Collections.Generic.List[string]

    foreach ($choiceMatch in $choiceMatches) {
      $choiceValue = Decode-Text $choiceMatch.Groups["choice"].Value
      $choiceText = Escape-Html $choiceValue
      $choiceValueAttr = Escape-Html $choiceValue
      $choices.Add(@"
            <label class="choice">
              <input name="$entryName" type="radio" value="$choiceValueAttr" aria-describedby="$entryId-error"$requiredAttr>
              <span>$choiceText</span>
            </label>
"@)
    }

    $questionHtml.Add(@"
          <fieldset class="$fieldClass">
            <legend>$questionTitle</legend>
$($choices -join "")
            <small id="$entryId-error" class="field-error" data-field-error></small>
          </fieldset>
"@)
    $requiredLabel = if ($isRequired) { ", required" } else { "" }
    $syncedQuestions.Add("$plainQuestionTitle ($entryName, radio$requiredLabel)")
    continue
  }

  if ($questionType -eq 4) {
    $requiredMatch = [regex]::Match($questionSlice, "\[\[$entryNumber,.*?\]\],(?<required>[01])", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $isRequired = $requiredMatch.Success -and $requiredMatch.Groups["required"].Value -eq "1"
    $fieldClass = if ($isRequired) { "form-card field choice-group field--required" } else { "form-card field choice-group" }
    $requiredGroupAttr = if ($isRequired) { " data-required-group" } else { "" }
    $choiceMatches = [regex]::Matches($payload, '\["(?<choice>(?:\\.|[^"\\])*)",null,null,null,(?<other>\d)\]')
    $choices = New-Object System.Collections.Generic.List[string]

    foreach ($choiceMatch in $choiceMatches) {
      $choiceValue = Decode-Text $choiceMatch.Groups["choice"].Value
      $isOtherChoice = $choiceMatch.Groups["other"].Value -eq "1"

      if ($isOtherChoice) {
        $choices.Add(@"
            <label class="choice choice--other">
              <input name="$entryName" type="checkbox" value="__other_option__" aria-describedby="$entryId-error">
              <span>Другое</span>
            </label>
            <input class="other-choice-input" name="$entryName.other_option_response" type="text" autocomplete="off" placeholder="Ваш вариант…">
"@)
        continue
      }

      if ([string]::IsNullOrWhiteSpace($choiceValue)) {
        continue
      }

      $choiceText = Escape-Html $choiceValue
      $choiceValueAttr = Escape-Html $choiceValue
      $choices.Add(@"
            <label class="choice">
              <input name="$entryName" type="checkbox" value="$choiceValueAttr" aria-describedby="$entryId-error">
              <span>$choiceText</span>
            </label>
"@)
    }

    $questionHtml.Add(@"
          <fieldset class="$fieldClass" aria-describedby="$entryId-error"$requiredGroupAttr>
            <legend>$questionTitle</legend>
            <input type="hidden" name="$($entryName)_sentinel" value="">
$($choices -join "")
            <small id="$entryId-error" class="field-error" data-field-error></small>
          </fieldset>
"@)
    $requiredLabel = if ($isRequired) { ", required" } else { "" }
    $syncedQuestions.Add("$plainQuestionTitle ($entryName, checkbox$requiredLabel)")
    continue
  }

  Write-Warning "Тип вопроса $questionType пока не поддержан скриптом: $questionTitle"
}

$formAction = Escape-Html $formActionMatch.Groups[1].Value
$fbzx = Escape-Html $fbzxMatch.Groups[1].Value
$titleHtml = Escape-Html $formTitle

$generatedForm = @"
        <!-- google-form:start -->
        <form
          class="wedding-form"
          action="$formAction"
          method="POST"
          target="google-form-target"
          data-rsvp-form>
          <div class="form-card form-card--intro">
            <span>RSVP</span>
            <strong>$titleHtml</strong>
            <p>Ответ сохранится в нашей Google Forms, но вам не придётся покидать сайт.</p>
          </div>

$($questionHtml -join "`n")
          <input type="hidden" name="fvv" value="1">
          <input type="hidden" name="pageHistory" value="0">
          <input type="hidden" name="fbzx" value="$fbzx">

          <div class="form-actions">
            <button class="button button--primary" type="submit">Отправить</button>
            <button class="button button--ghost" type="reset">Очистить</button>
          </div>
          <p class="form-status" data-form-status role="status" aria-live="polite"></p>
          <iframe class="submission-frame" name="google-form-target" title="Отправка ответа"></iframe>
        </form>
        <!-- google-form:end -->
"@

$index = Get-Content -LiteralPath $IndexPath -Raw
$updated = [regex]::Replace(
  $index,
  '(?s)        <!-- google-form:start -->.*?        <!-- google-form:end -->',
  [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $generatedForm }
)

if ($updated -eq $index) {
  throw "Не удалось найти google-form маркеры в index.html."
}

if ($DryRun) {
  Write-Host "Dry run: Google Forms прочитана: $($syncedQuestions.Count) вопрос(а), заголовок '$formTitle'."
  foreach ($question in $syncedQuestions) {
    Write-Host "- $question"
  }
  return
}

Set-Content -LiteralPath $IndexPath -Value $updated -Encoding UTF8
Write-Host "Google Forms синхронизирована: $($syncedQuestions.Count) вопрос(а), заголовок '$formTitle'."
