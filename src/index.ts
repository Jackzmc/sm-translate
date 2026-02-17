import express from 'express'
import { franc } from 'franc-min'
import { v2 } from '@google-cloud/translate'
import '@dotenvx/dotenvx/config'

const app = express();
app.use(express.json());

if (!process.env.GOOGLE_TRANSLATE_API_KEY) throw new Error("Missing GOOGLE_TRANSLATE_API_KEY")

const translator = new v2.Translate({
  key: process.env.GOOGLE_TRANSLATE_API_KEY
});

const LANG_MAP: Record<string, string> = { eng: 'en', spa: 'es' };

function badRequest(res: express.Response, message: string) {
  return res.status(400).json({
    error: "INVALID_PARAM",
    message
  })
}

export interface TranslateResponse_Skipped {
  result: "skipped",
  source: string,
  target: string
}
export interface TranslateResponse_Translated {
  result: "translated",
  source: string,
  target: string,
  text: string,
}

export type TranslateResponse = TranslateResponse_Skipped | TranslateResponse_Translated

app.post('/translate', async (req, res) => {
  console.log(req.query)
  const { text, target = 'en' } = req.query
  if (!text || typeof text != "string") return badRequest(res, "text is not defined or not a string")
  if (!target || typeof target != "string") return badRequest(res, "target is not defined or not a string ")
  const requestStart = performance.now()
  // Fast local detection (~5ms)
  const detected = franc(text);
  const sourceLang = LANG_MAP[detected] || 'en';

  // Skip if already correct language
  if (sourceLang === target) {
    return res.json({
      result: "skipped",
      source: sourceLang,
      target,
    } as TranslateResponse);
  }

  const translateStart = performance.now()
  // Only translate the 2% that needs it
  const [translation] = await translator.translate(text, target);

  res.json({
    result: "translated",
    text: translation,
    source: sourceLang,
    target,
    times: {
      request: performance.now() - requestStart,
      translate: performance.now() - translateStart
    }
  } as TranslateResponse);
});

const port = parseInt(process.env.WEB_PORT ?? "5000")
if (Number.isNaN(port)) throw new Error("WEB_PORT is ivnalid")
const host = process.env.WEB_HOST ?? "127.0.0.1"

console.info(`Listening on http://${host}:${port}`)
app.listen(port, host);
