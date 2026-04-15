# SM Translate

Sourcemod plugin that automatically translates messages in chat to all users' target language. Translations are done with Google Cloud Translate v2. A system checks if translation is necessary before even calling the API for a reduction in token usage.

> [!NOTE]
> * The server uses [franc](https://www.npmjs.com/package/franc) for detecting languages. By default to reduce false positives, it will not translate any text under 10 characters long. 
> * Translations are not perfect, nor is language detection. Some messages may show the wrong language or bad translations.

## Setup

By default the `sm_translate_api_path` cvar points to `http://localhost:5000/translate`. You will need to run the translate server `git.jackz.me/jackz/sm-translate:main`

Translation server requires a [Cloud Translation](https://cloud.google.com/translate) [API Key](https://console.cloud.google.com/apis/credentials). Recommend to limit the key by IP address.


### docker-compose.yaml
```yaml
services:
  translate:
    image: git.jackz.me/jackz/translate-server:main
    restart: always
    environment:
      GOOGLE_TRANSLATE_API_KEY: ${GOOGLE_TRANSLATE_API_KEY}
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