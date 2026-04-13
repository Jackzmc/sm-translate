import express from 'express'
import { franc } from 'franc-min'
import { v2 } from '@google-cloud/translate'
import { LANG_MAP } from './mapping.js';

const app = express();
app.use(express.json());

if (!process.env.GOOGLE_TRANSLATE_API_KEY) throw new Error("Missing GOOGLE_TRANSLATE_API_KEY")

const translator = new v2.Translate({
  key: process.env.GOOGLE_TRANSLATE_API_KEY
});

function badRequest(res: express.Response, message: string) {
  return res.status(400).json({
    error: "INVALID_PARAM",
    message
  })
}

interface TranslateTranslationResult {
  lang: string,
  text: string,
  timeElapsedMs?: number
}

export interface TranslateResponse {
  source: string,
  translations: TranslateTranslationResult[]
}

app.post('/translate', async (req, res) => {
  console.log(req.query)
  const { text, targets } = req.query
  if (!text || typeof text != "string") return badRequest(res, "text is not defined or not a string")
  if (!targets || typeof targets != "string") return badRequest(res, "targets is not defined or not a comma separated list")

  const targetSet = new Set(targets.split(","))

  const requestStart = performance.now()
  // Fast local detection (~5ms)
  const detected = franc(text);
  let sourceLang = LANG_MAP[detected]
  if(!sourceLang) {
    console.warn(`Unknown language code "${detected}", falling back to 'en'`)
    sourceLang = "en"
  }

  targetSet.delete(sourceLang)

  /*
    if targets = [ en ] and source = [ en ]  SKIP
    if targets = [ en ] and source = [ es ]  TRANSLATE to [ en ]
    if targets = [ en, es ] and source = [ en ] TRANSLATE to [ es ]
  */

  const translations: TranslateTranslationResult[] = [] 
  
  for(const target of targetSet) {
    const start = performance.now()
    // Only translate the 2% that needs it
    const [translation] = await translator.translate(text, target);

    const timeElapsed = performance.now() - start

    translations.push({
      lang: target,
      text: translation,
      timeElapsedMs: timeElapsed
    })
  }

  res.json({
    source: sourceLang,
    translations
  } as TranslateResponse);
  console.log(`[${sourceLang}->${[...targetSet.values()]}] ${text}`)
});

const port = parseInt(process.env.WEB_PORT ?? "5000")
if (Number.isNaN(port)) throw new Error("WEB_PORT is ivnalid")
const host = process.env.WEB_HOST ?? "127.0.0.1"

console.info(`Listening on http://${host}:${port}`)
app.listen(port, host);

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
