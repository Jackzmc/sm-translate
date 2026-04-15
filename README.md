# SM Translate

![server workflow status](https://git.jackz.me/jackz/sm-translate/badges/workflows/server.yaml/badge.svg)
![plugin workflow status](https://git.jackz.me/jackz/sm-translate/badges/workflows/plugin.yaml/badge.svg)


Sourcemod plugin that automatically translates messages in chat to all users' target language. Translations are done with Google Cloud Translate v2. A system checks if translation is necessary before even calling the API for a reduction in token usage.

> [!NOTE]
> * The server uses [franc](https://www.npmjs.com/package/franc) for detecting languages. By default to reduce false positives, it will not translate any text under 10 characters long. 
> * Translations are not perfect, nor is language detection. Some messages may show the wrong language or bad translations.

## Setup

Requires [System 2](https://forums.alliedmods.net/showthread.php?t=146019) extenstion. Some versions of System2 seem to cause crashes with outdated GLIBC libraries.

### Plugin

Download plugin from the [releases](https://git.jackz.me/jackz/sm-translate/releases) or [artifacts](https://git.jackz.me/jackz/sm-translate/actions?workflow=plugin.yaml&actor=0&status=1) pages.

Change **`sm_translate_api_path`** (default: `http://localhost:5000/translate`) as applicable. Config file is at `left4dead2/cfg/sourcemod/sm_translate.cfg`

### Server

Translation server requires an [API Key](https://console.cloud.google.com/apis/credentials) for [Google Cloud Translation](https://cloud.google.com/translate). I recommend to limit the key by IP address.

By default server listens on `http://0.0.0.0:5000`, with the API at `POST /translate`

#### docker-compose.yaml
```yaml
services:
  translate:
    image: git.jackz.me/jackz/translate-server:main
    restart: always
    environment:
      GOOGLE_TRANSLATE_API_KEY: ${GOOGLE_TRANSLATE_API_KEY}
      HOST: 0.0.0.0
    env_file: .env
    ports:
      - 5000:5000
    cpu_shares: 512
    deploy:
      resources:
        limits:
          cpus: "1"
          memory: 512M
        reservations:
          memory: 256M
```

## Commands

* `sm_t <lang code> <msg>` (or /t, !t) - translates message to target language
* `sm_lang` - Shows current language and prints list of languages to client console
* `sm_lang <lang code/OFF/DEFAULT>` - Sets client's target language for translations, or uses game's language (DEFAULT), or disables receiving translations (OFF)

## License

[MIT License]('./LICENSE.md'). 