# SM Translate

Sourcemod plugin that automatically translates messages in chat to all users' target language. Translations are done with Google Cloud Translate v2. A system checks if translation is necessary before even calling the API for a reduction in token usage.

## Setup

By default the `sm_translate_api_path` cvar points to `http://localhost:5000/translate`. You will need to run the translate server `git.jackz.me/jackz/sm-translate:main`

Translation server requires a [Cloud Translation](https://cloud.google.com/translate) [API Key](https://console.cloud.google.com/apis/credentials). Recommend to limit key by IP address.

## Commands

`sm_t <lang> <msg>` (or /t, !t) - translates message to target language

## License

[MIT License]('./LICENSE.md'). 